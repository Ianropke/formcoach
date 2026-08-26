import React, { useRef, useEffect, useState } from 'react';
import { ExerciseType, CameraViewType, EXERCISES, PoseFrame, RecordedSet } from '../core/models';
import { getAnalyzerForExercise } from '../core/analyzers/exerciseAnalyzers';
import { PoseSmoother } from '../core/poseSmoother';
import { AngleCalculator } from '../core/angleCalculator';
import { CameraQualityGate, CameraQualityResult } from '../core/qualityGate';
import { PoseLandmarkerService } from '../vision/poseLandmarkerService';
import { Square, ArrowLeft, CheckCircle2, AlertCircle, RefreshCw, XCircle, SwitchCamera } from 'lucide-react';

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
    guidanceMessage: 'Initializing camera & pose engine…'
  });

  const recordedFramesRef = useRef<PoseFrame[]>([]);
  const animationFrameId = useRef<number | null>(null);
  const startTimeRef = useRef<number>(0);
  const poseSmootherRef = useRef(new PoseSmoother(0.35));

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

        // Open iPhone camera via getUserMedia
        stream = await navigator.mediaDevices.getUserMedia({
          video: {
            facingMode,
            width: { ideal: 1280 },
            height: { ideal: 720 }
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
        const timestampMs = performance.now();
        canvas.width = video.videoWidth || 640;
        canvas.height = video.videoHeight || 480;

        const ctx = canvas.getContext('2d');
        if (ctx) {
          ctx.clearRect(0, 0, canvas.width, canvas.height);

          // Run genuine MediaPipe Pose Landmarker on video frame
          const rawPose = landmarkerService.detectForVideo(video, timestampMs);

          if (rawPose) {
            // Evaluate dynamic camera quality gate
            const quality = CameraQualityGate.evaluateQuality(rawPose, exercise);
            setQualityGate(quality);

            // Compute real measured joint angle
            const angle = computeActiveAngle(rawPose, exercise);
            if (angle !== null) setLiveAngle(Math.round(angle));

            // Draw genuine detected skeleton
            drawDetectedSkeleton(ctx, canvas.width, canvas.height, rawPose);

            // Record frame during recording phase
            if (phase === 'recording') {
              const recordedFrame: PoseFrame = {
                timestamp: (Date.now() - startTimeRef.current) / 1000,
                joints: rawPose.joints,
                confidence: rawPose.confidence
              };
              recordedFramesRef.current.push(recordedFrame);
            }
          } else {
            setLiveAngle(null);
            setQualityGate({
              isReady: false,
              fullBody: false,
              clearView: false,
              optimalScale: false,
              guidanceMessage: 'No person detected in frame. Step into camera view.'
            });
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
        setElapsedTime((Date.now() - startTimeRef.current) / 1000);
      }, 100);
    }
    return () => clearInterval(interval);
  }, [phase]);

  // Start 3-second countdown
  const handleStartCountdown = () => {
    setPhase('countdown');
    setCountdown(3);
    recordedFramesRef.current = [];

    const interval = setInterval(() => {
      setCountdown(prev => {
        if (prev <= 1) {
          clearInterval(interval);
          setPhase('recording');
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
  };

  // Stop Recording and Run Deterministic Biomechanics Pipeline
  const handleStopRecording = () => {
    setPhase('analyzing');

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

      const recordedSet: RecordedSet = {
        id: 'set_' + Date.now(),
        exercise,
        view,
        date: new Date().toISOString(),
        reps,
        analysis
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

      {/* 2. Genuine Skeleton Canvas Overlay */}
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

        {phase === 'recording' ? (
          <div className="flex items-center gap-2 px-3 py-1.5 rounded-xl bg-red-950/80 border border-red-500/30 text-red-400">
            <div className="w-2.5 h-2.5 rounded-full bg-red-500 animate-ping" />
            <span className="text-xs font-black font-mono">{formatTime(elapsedTime)}</span>
          </div>
        ) : (
          <button
            onClick={() => setFacingMode(prev => prev === 'environment' ? 'user' : 'environment')}
            title="Flip Camera (Front/Rear)"
            className="p-2.5 rounded-full bg-black/60 backdrop-blur-md text-white border border-white/10 hover:bg-neutral-800 transition-colors"
          >
            <SwitchCamera className="w-5 h-5 text-[#00E676]" />
          </button>
        )}
      </div>

      {/* Center Live Angle Indicator / Rep Counter */}
      <div className="relative z-10 flex flex-col items-center">
        {phase === 'recording' && (
          <div className="flex flex-col items-center gap-1 bg-black/70 backdrop-blur-md px-6 py-3 rounded-2xl border border-white/10">
            {liveAngle !== null ? (
              <div className="text-3xl font-black text-[#00E676] font-mono">
                {liveAngle}°
              </div>
            ) : (
              <div className="text-xs font-bold text-neutral-400">Tracking pose…</div>
            )}
            <div className="text-[10px] font-bold text-neutral-400 uppercase tracking-wider">
              Live Joint Angle
            </div>
          </div>
        )}

        {/* 3-Second Countdown Overlay */}
        {phase === 'countdown' && (
          <div className="flex flex-col items-center justify-center animate-bounce">
            <div className="text-8xl font-black text-[#00E676] drop-shadow-2xl">{countdown}</div>
            <div className="text-sm font-bold text-white uppercase tracking-widest mt-2">Get in Position</div>
          </div>
        )}

        {/* Analyzing Overlay */}
        {phase === 'analyzing' && (
          <div className="flex flex-col items-center gap-3 bg-black/80 backdrop-blur-md px-8 py-6 rounded-2xl border border-[#00E676]/30">
            <div className="w-10 h-10 border-4 border-[#00E676] border-t-transparent rounded-full animate-spin" />
            <div className="text-sm font-bold text-white">Segmenting Repetitions…</div>
          </div>
        )}

        {/* Insufficient Data / Tracking Failed Overlay */}
        {phase === 'insufficient' && (
          <div className="p-6 mx-4 bg-neutral-950/95 backdrop-blur-xl rounded-3xl border border-red-500/30 text-center max-w-sm">
            <XCircle className="w-12 h-12 text-red-500 mx-auto mb-2" />
            <div className="text-lg font-black text-white">No Repetitions Detected</div>
            <p className="text-xs text-neutral-300 mt-2 mb-4 leading-relaxed">
              Could not segment complete repetitions with sufficient joint confidence. Please place your phone ~1.5m away so your full body is visible.
            </p>
            <button
              onClick={() => setPhase('setup')}
              className="w-full bg-[#00E676] hover:bg-[#00E676]/90 text-black font-extrabold text-sm py-3.5 rounded-2xl flex items-center justify-center gap-2"
            >
              <RefreshCw className="w-4 h-4" />
              <span>Retry Camera Setup</span>
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
                <span>Full Body</span>
              </div>
              <div className={`flex items-center gap-1.5 ${qualityGate.clearView ? 'text-[#00E676]' : 'text-neutral-500'}`}>
                <CheckCircle2 className="w-4 h-4" />
                <span>Clear View</span>
              </div>
              <div className={`flex items-center gap-1.5 ${qualityGate.optimalScale ? 'text-[#00E676]' : 'text-neutral-500'}`}>
                <CheckCircle2 className="w-4 h-4" />
                <span>Optimal Scale</span>
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
              Start Countdown (3s)
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
              <span>STOP RECORDING</span>
            </button>
          </div>
        )}

        {hasCameraAccess === false && (
          <div className="p-4 bg-red-950/80 border border-red-500/30 rounded-2xl text-center text-xs text-red-300">
            <AlertCircle className="w-6 h-6 mx-auto mb-1 text-red-400" />
            Camera access is required. Please grant permission in Safari settings.
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
