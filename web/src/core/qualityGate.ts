import { PoseFrame, ExerciseType, CameraViewType } from './models';
import { CameraCalibrator } from './cameraCalibrator';

export interface CameraQualityResult {
  isReady: boolean;
  fullBody: boolean;
  clearView: boolean;
  optimalScale: boolean;
  guidanceMessage: string;
  pitchAngleDeg?: number;
  detectedProfile?: CameraViewType;
  isFloorPlacement?: boolean;
}

export class CameraQualityGate {
  public static evaluateQuality(frame: PoseFrame | null, exercise: ExerciseType): CameraQualityResult {
    if (!frame || frame.confidence < 0.3) {
      return {
        isReady: false,
        fullBody: false,
        clearView: false,
        optimalScale: false,
        guidanceMessage: 'Træd ind foran kameraet for at starte opsætning'
      };
    }

    const joints = frame.joints;
    const calibration = CameraCalibrator.calibrate(frame);

    // 1. Joint Visibility Gate based on exercise type
    let hasRequiredJoints = false;
    let missingJointName = '';

    if (exercise === 'squat' || exercise === 'legPress') {
      const hasHip = (joints.left_hip?.score ?? 0) > 0.55 || (joints.right_hip?.score ?? 0) > 0.55;
      const hasKnee = (joints.left_knee?.score ?? 0) > 0.55 || (joints.right_knee?.score ?? 0) > 0.55;
      const hasAnkle = (joints.left_ankle?.score ?? 0) > 0.50 || (joints.right_ankle?.score ?? 0) > 0.50;
      hasRequiredJoints = hasHip && hasKnee && hasAnkle;
      if (!hasAnkle) missingJointName = 'fødder og ankler';
      else if (!hasKnee) missingJointName = 'knæ';
      else if (!hasHip) missingJointName = 'hofter';
    } else {
      // Upper body exercises (Bicep Curls, Triceps Pushdown, Shoulder Press)
      const hasShoulder = (joints.left_shoulder?.score ?? 0) > 0.55 || (joints.right_shoulder?.score ?? 0) > 0.55;
      const hasElbow = (joints.left_elbow?.score ?? 0) > 0.55 || (joints.right_elbow?.score ?? 0) > 0.55;
      const hasWrist = (joints.left_wrist?.score ?? 0) > 0.50 || (joints.right_wrist?.score ?? 0) > 0.50;
      hasRequiredJoints = hasShoulder && hasElbow && hasWrist;
      if (!hasWrist) missingJointName = 'hænder og håndled';
      else if (!hasElbow) missingJointName = 'albuer';
      else if (!hasShoulder) missingJointName = 'skuldre';
    }

    // 2. Clear View Gate (Confidence)
    const clearView = frame.confidence >= 0.60;

    // 3. Adaptive Scale Gate (Body height span in frame)
    let minY = 1.0;
    let maxY = 0.0;
    let count = 0;

    for (const key in joints) {
      const pt = joints[key as keyof typeof joints];
      if (pt && pt.score > 0.45) {
        minY = Math.min(minY, pt.y);
        maxY = Math.max(maxY, pt.y);
        count++;
      }
    }

    const bodyHeightSpan = count >= 4 ? maxY - minY : 0.0;
    const isLowerBody = exercise === 'squat' || exercise === 'legPress';
    const minScale = isLowerBody ? 0.25 : 0.20;
    const isOptimalScale = bodyHeightSpan >= minScale && bodyHeightSpan <= 0.95;

    // Determine Actionable Guidance Message
    let message = 'Klar til optagelse!';
    if (!hasRequiredJoints) {
      message = `Træd lidt tilbage, så dine ${missingJointName} er synlige`;
    } else if (bodyHeightSpan < minScale) {
      message = 'Træd lidt tættere på kameraet';
    } else if (bodyHeightSpan > 0.95) {
      message = 'Træd lidt tilbage for fuld kropshøjde';
    } else if (!clearView) {
      message = 'Sørg for god belysning i dit træningsområde';
    }

    const isReady = hasRequiredJoints && clearView && isOptimalScale;

    return {
      isReady,
      fullBody: hasRequiredJoints,
      clearView,
      optimalScale: isOptimalScale,
      guidanceMessage: message,
      pitchAngleDeg: calibration.pitchAngleDeg,
      detectedProfile: calibration.detectedProfile,
      isFloorPlacement: calibration.isFloorPlacement
    };
  }
}
