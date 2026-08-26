import { FilesetResolver, PoseLandmarker, NormalizedLandmark } from '@mediapipe/tasks-vision';
import { PoseFrame, JointName, Point2D, CameraTelemetry } from '../core/models';

export class PoseLandmarkerService {
  private static instance: PoseLandmarkerService | null = null;
  private landmarker: PoseLandmarker | null = null;
  private isInitializing = false;

  // Real-Time Telemetry Tracking
  private latencies: number[] = [];
  private lastInferenceTime = 0;
  private frameCount = 0;
  private fpsWindowStart = 0;
  private currentFPS = 0;
  private droppedFrameCount = 0;

  public static getInstance(): PoseLandmarkerService {
    if (!PoseLandmarkerService.instance) {
      PoseLandmarkerService.instance = new PoseLandmarkerService();
    }
    return PoseLandmarkerService.instance;
  }

  public async initialize(): Promise<void> {
    if (this.landmarker || this.isInitializing) return;
    this.isInitializing = true;

    try {
      // 1. Resolve local WASM assets (100% on-device, zero external CDN dependency)
      const vision = await FilesetResolver.forVisionTasks('/wasm');

      // 2. Initialize PoseLandmarker in VIDEO running mode with WebGL/GPU acceleration
      this.landmarker = await PoseLandmarker.createFromOptions(vision, {
        baseOptions: {
          modelAssetPath: '/models/pose_landmarker_lite.task',
          delegate: 'GPU'
        },
        runningMode: 'VIDEO',
        numPoses: 1,
        minPoseDetectionConfidence: 0.6,
        minPosePresenceConfidence: 0.6,
        minTrackingConfidence: 0.6
      });

      console.log('MediaPipe PoseLandmarker initialized from local /wasm assets with GPU delegate! 🚀');
    } catch (err) {
      console.error('Fatal: Failed to initialize PoseLandmarker from local /wasm bundle:', err);
      throw new Error(`MediaPipe local vision assets missing in /wasm or GPU initialization failed: ${err}`);
    } finally {
      this.isInitializing = false;
    }
  }

  public detectForVideo(videoElement: HTMLVideoElement, timestampMs: number): PoseFrame | null {
    if (!this.landmarker) return null;
    if (videoElement.readyState < 2) return null;

    const t0 = performance.now();

    try {
      const result = this.landmarker.detectForVideo(videoElement, timestampMs);
      const elapsedMs = performance.now() - t0;

      // Telemetry recording
      this.recordLatency(elapsedMs);

      if (!result || !result.landmarks || result.landmarks.length === 0) {
        return null;
      }

      const rawLandmarks = result.landmarks[0];
      return this.mapLandmarksToPoseFrame(rawLandmarks, timestampMs / 1000);
    } catch (err) {
      this.droppedFrameCount++;
      console.warn('MediaPipe frame detection error:', err);
      return null;
    }
  }

  private recordLatency(ms: number): void {
    this.latencies.push(ms);
    if (this.latencies.length > 30) {
      this.latencies.shift();
    }

    const now = performance.now();
    this.frameCount++;
    if (now - this.fpsWindowStart >= 1000) {
      this.currentFPS = Math.round((this.frameCount * 1000) / (now - this.fpsWindowStart));
      this.frameCount = 0;
      this.fpsWindowStart = now;
    }
  }

  public getTelemetry(cameraFPS = 30): CameraTelemetry {
    if (this.latencies.length === 0) {
      return {
        cameraFPS,
        inferenceFPS: 0,
        medianLatencyMs: 0,
        p95LatencyMs: 0,
        droppedFrames: this.droppedFrameCount
      };
    }

    const sorted = [...this.latencies].sort((a, b) => a - b);
    const mid = Math.floor(sorted.length / 2);
    const median = sorted.length % 2 !== 0 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
    const p95Idx = Math.min(sorted.length - 1, Math.floor(sorted.length * 0.95));
    const p95 = sorted[p95Idx];

    return {
      cameraFPS,
      inferenceFPS: this.currentFPS,
      medianLatencyMs: Math.round(median * 10) / 10,
      p95LatencyMs: Math.round(p95 * 10) / 10,
      droppedFrames: this.droppedFrameCount
    };
  }

  /**
   * Maps MediaPipe's 33 NormalizedLandmarks to our strongly-typed PoseFrame domain model
   */
  private mapLandmarksToPoseFrame(landmarks: NormalizedLandmark[], timestampSec: number): PoseFrame {
    const joints: Partial<Record<JointName, Point2D>> = {};

    const jointMap: Record<number, JointName> = {
      0: 'nose',
      11: 'left_shoulder',
      12: 'right_shoulder',
      13: 'left_elbow',
      14: 'right_elbow',
      15: 'left_wrist',
      16: 'right_wrist',
      23: 'left_hip',
      24: 'right_hip',
      25: 'left_knee',
      26: 'right_knee',
      27: 'left_ankle',
      28: 'right_ankle'
    };

    let totalScore = 0;
    let jointCount = 0;

    for (const [idxStr, jointName] of Object.entries(jointMap)) {
      const idx = Number(idxStr);
      const lm = landmarks[idx];
      if (lm) {
        const score = lm.visibility !== undefined ? lm.visibility : 0.9;
        joints[jointName] = {
          x: lm.x,
          y: lm.y,
          score
        };
        totalScore += score;
        jointCount++;
      }
    }

    const overallConfidence = jointCount > 0 ? totalScore / jointCount : 0.0;

    return {
      timestamp: timestampSec,
      joints,
      confidence: overallConfidence
    };
  }
}
