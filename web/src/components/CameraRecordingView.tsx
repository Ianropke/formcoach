import React, { useRef, useEffect, useState } from 'react';
import { ExerciseType, CameraViewType, EXERCISES, PoseFrame, RecordedSet } from '../core/models';
import { getAnalyzerForExercise } from '../core/analyzers/exerciseAnalyzers';
import { PoseSmoother } from '../core/poseSmoother';
import { AngleCalculator } from '../core/angleCalculator';
import { CameraQualityGate, CameraQualityResult } from '../core/qualityGate';
import { PoseLandmarkerService } from '../vision/poseLandmarkerService';
import { AudioCoachService } from '../core/audio/audioCoachService';
import { Square, ArrowLeft, CheckCircle2, AlertCircle, RefreshCw, XCircle, SwitchCamera, Activity, Volume2, VolumeX } from 'lucide-react';
import { CameraTelemetry } from '../core/models';

interface Props {
  exercise: ExerciseType;
  view: CameraViewType;
  onBack: () => void;
  onFinishSet: (set: RecordedSet) => void;
}

export const CameraRecordingView: React.FC<Props> = ({
  exercise,
  view,
  onBack,
  onFinishSet
}) => {
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);

  const [facingMode, setFacingMode] = useState<'user' | 'environment'>('environment');
  const [zoomLevel, setZoomLevel] = useState<0.5 | 1 | 2>(1);
  const [showTelemetry, setShowTelemetry] = useState(false);
  const [isMuted, setIsMuted] = useState(false);
  const [telemetry, setTelemetry] = useState<CameraTelemetry>({
    cameraFPS: 30,
    inferenceFPS: 0,
    medianLatencyMs: 0,
    p95LatencyMs: 0,
    droppedFrames: 0
  });
  const [phase, setPhase] = useState<'setup' | 'countdown' | 'recording' | 'analyzing' | 'insufficient'>('setup');
  const [countdown, setCountdown] = useState(3);
  const [elapsedTime, setElapsedTime] = useState(0);
  const [liveAngle, setLiveAngle] = useState<number | null>(null);
  const [hasCameraAccess, setHasCameraAccess] = useState<boolean | null>(null);
  const [isModelLoaded, setIsModelLoaded] = useState(false);
  const [qualityGate, setQualityGate] = useState<CameraQualityResult>({
    isReady: false,
    fullBody: false,
    clearView: false,
    optimalScale: false,
    guidanceMessage: 'Indlæser kamera og synsmotor…'
  });

  const recordedFramesRef = useRef<PoseFrame[]>([]);
  const animationFrameId = useRef<number | null>(null);
  const startTimeRef = useRef<number>(0);
  const poseSmootherRef = useRef(new PoseSmoother(0.35));
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const videoChunksRef = useRef<Blob[]>([]);
  const depthMilestoneTriggeredRef = useRef<boolean>(false);
  const liveRepCountRef = useRef<number>(0);
  const wakeLockRef = useRef<any>(null);
  const lastInferenceMsRef = useRef<number>(0);
  const lastPoseRef = useRef<PoseFrame | null>(null);

  // Screen WakeLock API Guard (Prevents iOS screen sleep during workouts)
  const requestWakeLock = async () => {
    if (typeof navigator !== 'undefined' && 'wakeLock' in navigator) {
      try {
        wakeLockRef.current = await (navigator as any).wakeLock.request('screen');
      } catch (e) {
        console.warn('WakeLock request bypassed:', e);
      }
    }
  };

  const releaseWakeLock = () => {
    if (wakeLockRef.current) {
      try {
        wakeLockRef.current.release();
        wakeLockRef.current = null;
      } catch {}
    }
  };

  // Dynamic Lens / Hardware Zoom Switching
  const handleZoomChange = async (level: 0.5 | 1 | 2) => {
    setZoomLevel(level);
    if (videoRef.current && videoRef.current.srcObject) {
      const stream = videoRef.current.srcObject as MediaStream;
      const track = stream.getVideoTracks()[0];
      if (track) {
        try {
          const capabilities: any = (track as any).getCapabilities ? (track as any).getCapabilities() : {};
          if (capabilities.zoom) {
            const targetZoom = level === 0.5 ? Math.max(capabilities.zoom.min || 1, 0.5) : level === 2 ? Math.min(capabilities.zoom.max || 2, 2) : 1;
            await (track as any).applyConstraints({
              advanced: [{ zoom: targetZoom }]
            });
          }
        } catch (e) {
          console.warn('Hardware zoom adjustment bypassed:', e);
        }
      }
    }
  };

  // Telemetry polling interval
  useEffect(() => {
    const interval = setInterval(() => {
      const landmarker = PoseLandmarkerService.getInstance();
      setTelemetry(landmarker.getTelemetry());
    }, 1000);
    return () => clearInterval(interval);
  }, []);

  const exerciseDef = EXERCISES[exercise];

  // 1. Initialize Camera & MediaPipe Tasks Vision Model
  useEffect(() => {
    let stream: MediaStream | null = null;
    let isCancelled = false;

    async function init() {
      try {
        // Initialize MediaPipe PoseLandmarker
        const landmarkerService = PoseLandmarkerService.getInstance();
        await landmarkerService.initialize();
        if (!isCancelled) setIsModelLoaded(true);

        // Stop previous stream if switching camera
        if (videoRef.current && videoRef.current.srcObject) {
          const oldStream = videoRef.current.srcObject as MediaStream;
          oldStream.getTracks().forEach(t => t.stop());
        }

        // Open camera via getUserMedia with iPhone 60fps/1080p high-performance profile
        stream = await navigator.mediaDevices.getUserMedia({
          video: {
            facingMode,
            width: { ideal: 1920, min: 1280 },
            height: { ideal: 1080, min: 720 },
            frameRate: { ideal: 60, min: 30 }
          },
          audio: false
        });

        if (videoRef.current && !isCancelled) {
          videoRef.current.srcObject = stream;
          await videoRef.current.play();
          setHasCameraAccess(true);
        }
      } catch (err) {
        console.error('Camera or MediaPipe initialization error:', err);
        if (!isCancelled) setHasCameraAccess(false);
      }
    }

    init();

    return () => {
      isCancelled = true;
      releaseWakeLock();
      PoseLandmarkerService.getInstance().setAthleteAnchor(null);
      if (stream) {
        stream.getTracks().forEach(track => track.stop());
      }
      if (animationFrameId.current) {
        cancelAnimationFrame(animationFrameId.current);
      }
    };
  }, [facingMode]);

  // 2. Real-Time Vision Inference & Canvas Rendering Loop
  useEffect(() => {
    if (!hasCameraAccess || !isModelLoaded) return;

    const landmarkerService = PoseLandmarkerService.getInstance();

    const renderLoop = () => {
      const video = videoRef.current;
      const canvas = canvasRef.current;

      if (video && canvas && video.readyState >= 2) {
        const now = performance.now();

        // Adaptive FPS Thermal Saver: Throttle to ~20 FPS during setup, full speed during recording
        const isSetupPhase = phase === 'setup';
        const throttleInterval = isSetupPhase ? 50 : 0; // 50ms = 20 FPS in setup

        if (now - lastInferenceMsRef.current >= throttleInterval) {
          lastInferenceMsRef.current = now;

          canvas.width = video.videoWidth || 640;
          canvas.height = video.videoHeight || 480;

          const ctx = canvas.getContext('2d');
          if (ctx) {
            ctx.clearRect(0, 0, canvas.width, canvas.height);

            // Run genuine MediaPipe Pose Landmarker on video frame
            const rawPose = landmarkerService.detectForVideo(video, now);

            if (rawPose) {
              lastPoseRef.current = rawPose;

              // Evaluate dynamic camera quality gate
              const quality = CameraQualityGate.evaluateQuality(rawPose, exercise);
              setQualityGate(quality);

              // Compute real measured joint angle
              const angle = computeActiveAngle(rawPose, exercise);
              if (angle !== null) {
                setLiveAngle(Math.round(angle));

                // Real-Time Audio Cues (Zero-latency depth chimes & live milestone triggers)
                if (phase === 'recording') {
                  if (exercise === 'squat' || exercise === 'legPress') {
                    if (angle <= 88 && !depthMilestoneTriggeredRef.current) {
                      depthMilestoneTriggeredRef.current = true;
                      AudioCoachService.getInstance().playDepthMilestone();
                    } else if (angle >= 150 && depthMilestoneTriggeredRef.current) {
                      depthMilestoneTriggeredRef.current = false;
                      liveRepCountRef.current++;
                      AudioCoachService.getInstance().speak(liveRepCountRef.current.toString());
                    }
                  } else if (exercise === 'bicepsCurl') {
                    if (angle <= 58 && !depthMilestoneTriggeredRef.current) {
                      depthMilestoneTriggeredRef.current = true;
                      AudioCoachService.getInstance().playDepthMilestone();
                    } else if (angle >= 135 && depthMilestoneTriggeredRef.current) {
                      depthMilestoneTriggeredRef.current = false;
                      liveRepCountRef.current++;
                      AudioCoachService.getInstance().speak(liveRepCountRef.current.toString());
                    }
                  } else if (exercise === 'tricepsPushdown') {
                    if (angle >= 160 && !depthMilestoneTriggeredRef.current) {
                      depthMilestoneTriggeredRef.current = true;
                      AudioCoachService.getInstance().playDepthMilestone();
                    } else if (angle <= 95 && depthMilestoneTriggeredRef.current) {
                      depthMilestoneTriggeredRef.current = false;
                      liveRepCountRef.current++;
                      AudioCoachService.getInstance().speak(liveRepCountRef.current.toString());
                    }
                  } else if (exercise === 'shoulderPress') {
                    if (angle >= 160 && !depthMilestoneTriggeredRef.current) {
                      depthMilestoneTriggeredRef.current = true;
                      AudioCoachService.getInstance().playDepthMilestone();
                    } else if (angle <= 90 && depthMilestoneTriggeredRef.current) {
                      depthMilestoneTriggeredRef.current = false;
                      liveRepCountRef.current++;
                      AudioCoachService.getInstance().speak(liveRepCountRef.current.toString());
                    }
                  }
                }
              }

              // Draw genuine detected skeleton
              drawDetectedSkeleton(ctx, canvas.width, canvas.height, rawPose);

              // Record frame during recording phase
              if (phase === 'recording') {
                const recordedFrame: PoseFrame = {
                  timestamp: (Date.now() - startTimeRef.current) / 1000,
                  joints: rawPose.joints,
                  worldJoints: rawPose.worldJoints,
                  confidence: rawPose.confidence
                };
                recordedFramesRef.current.push(recordedFrame);

                // Buffer Overflow Safety Guard: Auto-stop after 180s (3 minutes)
                if (recordedFramesRef.current.length > 10800) {
                  handleStopRecording();
                }
              }
            } else {
              setLiveAngle(null);
              setQualityGate({
                isReady: false,
                fullBody: false,
                clearView: false,
                optimalScale: false,
                guidanceMessage: 'Ingen person i billedet. Stil dig foran kameraet.'
              });
            }
          }
        }
      }

      animationFrameId.current = requestAnimationFrame(renderLoop);
    };

    animationFrameId.current = requestAnimationFrame(renderLoop);

    return () => {
      if (animationFrameId.current) cancelAnimationFrame(animationFrameId.current);
    };
  }, [hasCameraAccess, isModelLoaded, phase, exercise]);

  // Elapsed Time Timer in Recording Phase
  useEffect(() => {
    let interval: any = null;
    if (phase === 'recording') {
      startTimeRef.current = Date.now();
      interval = setInterval(() => {
        const elapsed = (Date.now() - startTimeRef.current) / 1000;
        setElapsedTime(elapsed);
        // Safety Auto-stop after 180s
        if (elapsed >= 180) {
          handleStopRecording();
        }
      }, 100);
    }
    return () => clearInterval(interval);
  }, [phase]);

  // Start 3-second countdown with AirPods Audio & MediaRecorder Init
  const handleStartCountdown = () => {
    setPhase('countdown');
    setCountdown(3);
    recordedFramesRef.current = [];
    depthMilestoneTriggeredRef.current = false;
    liveRepCountRef.current = 0;

    // Acquire Screen WakeLock to prevent iPhone sleep during set
    requestWakeLock();

    // Lock athlete anchor coordinates to prevent multi-person background interference
    if (lastPoseRef.current) {
      const joints = lastPoseRef.current.joints;
      let minX = 1, maxX = 0, minY = 1, maxY = 0, count = 0;
      for (const k in joints) {
        const pt = joints[k as keyof typeof joints];
        if (pt && pt.score > 0.4) {
          minX = Math.min(minX, pt.x);
          maxX = Math.max(maxX, pt.x);
          minY = Math.min(minY, pt.y);
          maxY = Math.max(maxY, pt.y);
          count++;
        }
      }
      if (count >= 3) {
        PoseLandmarkerService.getInstance().setAthleteAnchor({
          centerX: (minX + maxX) / 2,
          centerY: (minY + maxY) / 2,
          scale: Math.max(0.01, maxY - minY)
        });
      }
    }

    AudioCoachService.getInstance().unlockAudio();
    AudioCoachService.getInstance().playCountdownBeep(false);

    const interval = setInterval(() => {
      setCountdown(prev => {
        if (prev <= 1) {
          clearInterval(interval);
          setPhase('recording');
          AudioCoachService.getInstance().playCountdownBeep(true);
          AudioCoachService.getInstance().speak('Start', true);

          // Start in-memory MediaRecorder video capture
          if (videoRef.current && videoRef.current.srcObject) {
            const stream = videoRef.current.srcObject as MediaStream;
            try {
              const types = ['video/webm;codecs=vp9', 'video/webm', 'video/mp4'];
              const mimeType = types.find(t => typeof MediaRecorder !== 'undefined' && MediaRecorder.isTypeSupported(t)) || '';
              videoChunksRef.current = [];
              if (typeof MediaRecorder !== 'undefined') {
                const mr = new MediaRecorder(stream, mimeType ? { mimeType } : undefined);
                mr.ondataavailable = (e) => {
                  if (e.data && e.data.size > 0) {
                    videoChunksRef.current.push(e.data);
                  }
                };
                mr.start(200);
                mediaRecorderRef.current = mr;
              }
            } catch (err) {
              console.warn('MediaRecorder recording bypassed:', err);
            }
          }
          return 0;
        }
        AudioCoachService.getInstance().playCountdownBeep(false);
        return prev - 1;
      });
    }, 1000);
  };

  // Stop Recording and Run Deterministic Biomechanics Pipeline
  const handleStopRecording = () => {
    setPhase('analyzing');
    releaseWakeLock();
    PoseLandmarkerService.getInstance().setAthleteAnchor(null);

    // Stop MediaRecorder and package temporary video Blob URL
    if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
      try {
        mediaRecorderRef.current.stop();
      } catch (e) {
        console.warn('MediaRecorder stop error:', e);
      }
    }

    setTimeout(() => {
      const rawFrames = recordedFramesRef.current;

      // 1. Check if sufficient frames were recorded
      if (rawFrames.length < 15) {
        setPhase('insufficient');
        return;
      }

      // 2. Smooth landmarks
      const smoothedFrames = poseSmootherRef.current.smooth(rawFrames);

      // 3. Run deterministic rep segmentation
      const analyzer = getAnalyzerForExercise(exercise);
      const reps = analyzer.segmentReps(smoothedFrames, view);

      // 4. Honest Status Gate: If no complete reps detected, do NOT fabricate data
      if (reps.length === 0) {
        setPhase('insufficient');
        return;
      }

      // 5. Biomechanical Kinematic Analysis
      const analysis = analyzer.analyzeSet(reps, smoothedFrames, view);

      // Create in-memory Video URL if recorded
      let videoUrl: string | undefined;
      if (videoChunksRef.current.length > 0) {
        try {
          const mime = videoChunksRef.current[0].type || 'video/webm';
          const blob = new Blob(videoChunksRef.current, { type: mime });
          videoUrl = URL.createObjectURL(blob);
        } catch (e) {
          console.warn('Video blob creation error:', e);
        }
      }

      AudioCoachService.getInstance().speak(`Sæt gennemført. ${reps.length} gentagelser målt.`);

      const recordedSet: RecordedSet = {
        id: 'set_' + Date.now(),
        exercise,
        view,
        date: new Date().toISOString(),
        reps,
        analysis,
        videoUrl
      };

      onFinishSet(recordedSet);
    }, 400);
  };

  return (
    <div className="relative w-full h-full bg-black flex flex-col justify-between overflow-hidden">
      {/* 1. Camera Video Element */}
      <video
        ref={videoRef}
        playsInline
        muted
        autoPlay
        className="absolute inset-0 w-full h-full object-cover"
      />

      {/* 2. Visual Silhouette Framing Guide (Shown during setup) */}
      {phase === 'setup' && (
        <div className="absolute inset-0 flex items-center justify-center pointer-events-none opacity-25">
          <svg viewBox="0 0 200 400" className="h-[75%] max-w-[280px] stroke-white stroke-[2] fill-none stroke-dasharray-[6,6]">
            {/* Head */}
            <circle cx="100" cy="50" r="22" />
            {/* Torso & Shoulders */}
            <line x1="70" y1="85" x2="130" y2="85" />
            <line x1="100" y1="72" x2="100" y2="210" />
            {/* Arms */}
            <line x1="70" y1="85" x2="55" y2="150" />
            <line x1="130" y1="85" x2="145" y2="150" />
            {/* Hips */}
            <line x1="75" y1="210" x2="125" y2="210" />
            {/* Legs */}
            <line x1="80" y1="210" x2="75" y2="300" />
            <line x1="75" y1="300" x2="70" y2="380" />
            <line x1="120" y1="210" x2="125" y2="300" />
            <line x1="125" y1="300" x2="130" y2="380" />
          </svg>
        </div>
      )}

      {/* 3. Genuine Skeleton Canvas Overlay */}
      <canvas
        ref={canvasRef}
        className="absolute inset-0 w-full h-full pointer-events-none"
      />

      {/* Top Header Bar */}
      <div className="relative z-10 p-4 flex items-center justify-between bg-gradient-to-b from-black/80 to-transparent">
        <button
          onClick={onBack}
          className="p-2.5 rounded-full bg-black/60 backdrop-blur-md text-white border border-white/10"
        >
          <ArrowLeft className="w-5 h-5" />
        </button>

        <div className="flex items-center gap-2 px-3 py-1.5 rounded-xl bg-black/60 backdrop-blur-md border border-white/10">
          <div className="w-2.5 h-2.5 rounded-full bg-[#00E676] animate-pulse" />
          <span className="text-xs font-bold uppercase tracking-wider text-white">
            {exerciseDef.name}
          </span>
        </div>

        <div className="flex items-center gap-2">
          {/* Ultra-Wide (0.5x) / Zoom Pill */}
          <div className="flex items-center bg-black/60 backdrop-blur-md rounded-xl p-0.5 border border-white/10 text-[11px] font-black">
            {([0.5, 1, 2] as const).map(level => (
              <button
                key={level}
                onClick={() => handleZoomChange(level)}
                className={`px-2.5 py-1 rounded-lg transition-colors ${
                  zoomLevel === level
                    ? 'bg-[#00E676] text-black shadow-xs'
                    : 'text-neutral-400 hover:text-white'
                }`}
              >
                {level}x
              </button>
            ))}
          </div>

          <button
            onClick={() => {
              const next = !isMuted;
              setIsMuted(next);
              AudioCoachService.getInstance().setMuted(next);
            }}
            title={isMuted ? 'Slå lyd til' : 'Slå lyd fra (AirPods / Højttaler)'}
            className={`p-2.5 rounded-full backdrop-blur-md border transition-colors ${
              isMuted
                ? 'bg-neutral-800 text-neutral-400 border-white/10'
                : 'bg-black/60 text-[#00E676] border-white/10 hover:bg-neutral-800'
            }`}
          >
            {isMuted ? <VolumeX className="w-5 h-5" /> : <Volume2 className="w-5 h-5" />}
          </button>

          <button
            onClick={() => setShowTelemetry(prev => !prev)}
            title="Telemetri & Ydeevne"
            className={`p-2.5 rounded-full backdrop-blur-md border transition-colors ${
              showTelemetry
                ? 'bg-[#00E676] text-black border-[#00E676]'
                : 'bg-black/60 text-white border-white/10 hover:bg-neutral-800'
            }`}
          >
            <Activity className="w-5 h-5" />
          </button>

          {phase === 'recording' ? (
            <div className="flex items-center gap-2 px-3 py-1.5 rounded-xl bg-red-950/80 border border-red-500/30 text-red-400">
              <div className="w-2.5 h-2.5 rounded-full bg-red-500 animate-ping" />
              <span className="text-xs font-black font-mono">{formatTime(elapsedTime)}</span>
            </div>
          ) : (
            <button
              onClick={() => setFacingMode(prev => prev === 'environment' ? 'user' : 'environment')}
              title="Skift Kamera (For/Bag)"
              className="p-2.5 rounded-full bg-black/60 backdrop-blur-md text-white border border-white/10 hover:bg-neutral-800 transition-colors"
            >
              <SwitchCamera className="w-5 h-5 text-[#00E676]" />
            </button>
          )}
        </div>
      </div>

      {/* Real-Time Telemetry HUD */}
      {showTelemetry && (
        <div className="relative z-10 mx-4 mb-2 p-3 rounded-2xl bg-black/85 backdrop-blur-md border border-white/15 text-white text-xs font-mono grid grid-cols-2 gap-2 shadow-2xl">
          <div>
            <span className="text-neutral-400 text-[10px] block">VISION INFERENCE</span>
            <span className="font-bold text-[#00E676]">{telemetry.inferenceFPS} FPS</span>
          </div>
          <div>
            <span className="text-neutral-400 text-[10px] block">KAMERASENSOR</span>
            <span className="font-bold text-white">{telemetry.cameraFPS} FPS</span>
          </div>
          <div>
            <span className="text-neutral-400 text-[10px] block">LATENS (MED / P95)</span>
            <span className="font-bold text-white">{telemetry.medianLatencyMs}ms / {telemetry.p95LatencyMs}ms</span>
          </div>
          <div>
            <span className="text-neutral-400 text-[10px] block">TABTE FRAMES</span>
            <span className={`font-bold ${telemetry.droppedFrames > 0 ? 'text-amber-400' : 'text-[#00E676]'}`}>{telemetry.droppedFrames}</span>
          </div>
        </div>
      )}

      {/* Center Live Angle Indicator / Rep Counter */}
      <div className="relative z-10 flex flex-col items-center">
        {phase === 'recording' && (
          <div className="flex flex-col items-center gap-1 bg-black/70 backdrop-blur-md px-6 py-3 rounded-2xl border border-white/10">
            {liveAngle !== null ? (
              <div className="text-3xl font-black text-[#00E676] font-mono">
                {liveAngle}°
              </div>
            ) : (
              <div className="text-xs font-bold text-neutral-400">Sporer kropsposition…</div>
            )}
            <div className="text-[10px] font-bold text-neutral-400 uppercase tracking-wider">
              Aktiv Ledvinkel
            </div>
          </div>
        )}

        {/* 3-Second Countdown Overlay */}
        {phase === 'countdown' && (
          <div className="flex flex-col items-center justify-center animate-bounce">
            <div className="text-8xl font-black text-[#00E676] drop-shadow-2xl">{countdown}</div>
            <div className="text-sm font-bold text-white uppercase tracking-widest mt-2">Gør dig klar</div>
          </div>
        )}

        {/* Analyzing Overlay */}
        {phase === 'analyzing' && (
          <div className="flex flex-col items-center gap-3 bg-black/80 backdrop-blur-md px-8 py-6 rounded-2xl border border-[#00E676]/30">
            <div className="w-10 h-10 border-4 border-[#00E676] border-t-transparent rounded-full animate-spin" />
            <div className="text-sm font-bold text-white">Analyserer gentagelser…</div>
          </div>
        )}

        {/* Insufficient Data / Tracking Failed Overlay */}
        {phase === 'insufficient' && (
          <div className="p-6 mx-4 bg-neutral-950/95 backdrop-blur-xl rounded-3xl border border-red-500/30 text-center max-w-sm">
            <XCircle className="w-12 h-12 text-red-500 mx-auto mb-2" />
            <div className="text-lg font-black text-white">Ingen gentagelser registreret</div>
            <p className="text-xs text-neutral-300 mt-2 mb-4 leading-relaxed">
              Kunne ikke opdele gentagelser med tilstrækkelig ledsynlighed. Placér telefonen ca. 1.5–2 meter væk i hoftehøjde.
            </p>
            <button
              onClick={() => setPhase('setup')}
              className="w-full bg-[#00E676] hover:bg-[#00E676]/90 text-black font-extrabold text-sm py-3.5 rounded-2xl flex items-center justify-center gap-2"
            >
              <RefreshCw className="w-4 h-4" />
              <span>Prøv kameraindstilling igen</span>
            </button>
          </div>
        )}
      </div>

      {/* Bottom Setup Guidance / Dynamic Quality Gate */}
      <div className="relative z-10 p-4 pb-8 bg-gradient-to-t from-black via-black/80 to-transparent">
        {phase === 'setup' && (
          <div className="space-y-3 max-w-md mx-auto">
            {/* Dynamic Guidance Checkmarks */}
            <div className="flex items-center justify-around bg-neutral-900/80 backdrop-blur-md p-3 rounded-2xl border border-white/10 text-xs font-bold">
              <div className={`flex items-center gap-1.5 ${qualityGate.fullBody ? 'text-[#00E676]' : 'text-neutral-500'}`}>
                <CheckCircle2 className="w-4 h-4" />
                <span>Fuld Krop</span>
              </div>
              <div className={`flex items-center gap-1.5 ${qualityGate.clearView ? 'text-[#00E676]' : 'text-neutral-500'}`}>
                <CheckCircle2 className="w-4 h-4" />
                <span>Klart Udsyn</span>
              </div>
              <div className={`flex items-center gap-1.5 ${qualityGate.optimalScale ? 'text-[#00E676]' : 'text-neutral-500'}`}>
                <CheckCircle2 className="w-4 h-4" />
                <span>God Afstand</span>
              </div>
            </div>

            {/* Live Camera Angle & Placement Calibration Badge */}
            <div className="flex items-center justify-center gap-2 text-[11px] font-mono font-bold text-neutral-300">
              <div className="px-2.5 py-1 bg-neutral-900/90 backdrop-blur-md rounded-xl border border-white/10 flex items-center gap-1.5 shadow-xs">
                <span className="text-[#00E676]">📐</span>
                <span>{qualityGate.detectedProfile === 'side' ? 'Sideprofil' : qualityGate.detectedProfile === 'front45' ? '45° Skrå' : 'Frontal'}</span>
              </div>
              <div className="px-2.5 py-1 bg-neutral-900/90 backdrop-blur-md rounded-xl border border-white/10 flex items-center gap-1.5 shadow-xs">
                <span className="text-[#00E676]">📱</span>
                <span>{qualityGate.isFloorPlacement ? `Gulvvinkel (+${qualityGate.pitchAngleDeg || 15}°)` : 'Vandret (0°)'}</span>
              </div>
            </div>

            {/* Guidance Text */}
            <div className="text-center text-xs font-semibold text-neutral-300">
              {qualityGate.guidanceMessage}
            </div>

            {/* Start Button enabled only when Quality Gate passes */}
            <button
              onClick={handleStartCountdown}
              disabled={!qualityGate.isReady}
              className={`w-full font-extrabold text-lg py-4 rounded-2xl shadow-xl transition-all ${
                qualityGate.isReady
                  ? 'bg-[#00E676] hover:bg-[#00E676]/90 text-black shadow-[#00E676]/30 active:scale-[0.98]'
                  : 'bg-neutral-800 text-neutral-500 cursor-not-allowed'
              }`}
            >
              Start Nedtælling (3s)
            </button>
          </div>
        )}

        {phase === 'recording' && (
          <div className="max-w-md mx-auto">
            <button
              onClick={handleStopRecording}
              className="w-full bg-red-600 hover:bg-red-700 text-white font-extrabold text-lg py-4 rounded-2xl flex items-center justify-center gap-2 shadow-xl shadow-red-600/40 active:scale-[0.98] transition-transform"
            >
              <Square className="w-5 h-5 fill-current" />
              <span>STOP OPTAGELSE</span>
            </button>
          </div>
        )}

        {hasCameraAccess === false && (
          <div className="p-4 bg-red-950/80 border border-red-500/30 rounded-2xl text-center text-xs text-red-300">
            <AlertCircle className="w-6 h-6 mx-auto mb-1 text-red-400" />
            Kameraadgang er påkrævet. Tillad venligst kamera i Safari indstillinger.
          </div>
        )}
      </div>
    </div>
  );
};

function computeActiveAngle(frame: PoseFrame, exercise: ExerciseType): number | null {
  const joints = frame.joints;

  if (exercise === 'squat' || exercise === 'legPress') {
    const hip = joints.left_hip || joints.right_hip;
    const knee = joints.left_knee || joints.right_knee;
    const ankle = joints.left_ankle || joints.right_ankle;
    if (hip && knee && ankle) {
      return AngleCalculator.angle2D(hip, knee, ankle);
    }
  } else {
    // Upper body (curls, pushdown, press)
    const s = joints.left_shoulder || joints.right_shoulder;
    const e = joints.left_elbow || joints.right_elbow;
    const w = joints.left_wrist || joints.right_wrist;
    if (s && e && w) {
      return AngleCalculator.angle2D(s, e, w);
    }
  }
  return null;
}

function drawDetectedSkeleton(ctx: CanvasRenderingContext2D, width: number, height: number, frame: PoseFrame) {
  ctx.strokeStyle = '#00E676';
  ctx.fillStyle = '#00E676';
  ctx.lineWidth = 3.5;

  const joints = frame.joints;

  const bones: [keyof typeof joints, keyof typeof joints][] = [
    ['left_shoulder', 'right_shoulder'],
    ['left_shoulder', 'left_elbow'],
    ['left_elbow', 'left_wrist'],
    ['right_shoulder', 'right_elbow'],
    ['right_elbow', 'right_wrist'],
    ['left_shoulder', 'left_hip'],
    ['right_shoulder', 'right_hip'],
    ['left_hip', 'right_hip'],
    ['left_hip', 'left_knee'],
    ['left_knee', 'left_ankle'],
    ['right_hip', 'right_knee'],
    ['right_knee', 'right_ankle']
  ];

  // Draw Bones
  for (const [j1, j2] of bones) {
    const p1 = joints[j1];
    const p2 = joints[j2];
    if (p1 && p2 && p1.score > 0.4 && p2.score > 0.4) {
      ctx.beginPath();
      ctx.moveTo(p1.x * width, p1.y * height);
      ctx.lineTo(p2.x * width, p2.y * height);
      ctx.stroke();
    }
  }

  // Draw Joint Dots
  for (const key in joints) {
    const pt = joints[key as keyof typeof joints];
    if (pt && pt.score > 0.4) {
      ctx.beginPath();
      ctx.arc(pt.x * width, pt.y * height, 5, 0, Math.PI * 2);
      ctx.fill();
    }
  }
}

function formatTime(sec: number) {
  const m = Math.floor(sec / 60);
  const s = Math.floor(sec % 60);
  const t = Math.floor((sec % 1) * 10);
  return `${m}:${s.toString().padStart(2, '0')}.${t}`;
}
