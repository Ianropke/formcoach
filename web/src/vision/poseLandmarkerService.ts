import { FilesetResolver, PoseLandmarker, NormalizedLandmark } from '@mediapipe/tasks-vision';
import { PoseFrame, JointName, Point2D } from '../core/models';

export class PoseLandmarkerService {
  private static instance: PoseLandmarkerService | null = null;
  private landmarker: PoseLandmarker | null = null;
  private isInitializing = false;

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
      // 1. Resolve WASM assets (try local first, fallback to CDN if needed)
      let vision;
      try {
        vision = await FilesetResolver.forVisionTasks('/wasm');
      } catch {
        vision = await FilesetResolver.forVisionTasks(
          'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@latest/wasm'
        );
      }

      // 2. Initialize PoseLandmarker in VIDEO running mode
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

      console.log('MediaPipe PoseLandmarker initialized successfully with GPU acceleration! 🚀');
    } catch (err) {
      console.error('Failed to initialize PoseLandmarker:', err);
      throw err;
    } finally {
      this.isInitializing = false;
    }
  }

  public detectForVideo(videoElement: HTMLVideoElement, timestampMs: number): PoseFrame | null {
    if (!this.landmarker) return null;
    if (videoElement.readyState < 2) return null;

    try {
      const result = this.landmarker.detectForVideo(videoElement, timestampMs);
      if (!result || !result.landmarks || result.landmarks.length === 0) {
        return null;
      }

      const rawLandmarks = result.landmarks[0];
      return this.mapLandmarksToPoseFrame(rawLandmarks, timestampMs / 1000);
    } catch (err) {
      console.warn('MediaPipe frame detection error:', err);
      return null;
    }
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
