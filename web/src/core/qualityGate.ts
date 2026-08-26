import { PoseFrame, ExerciseType } from './models';

export interface CameraQualityResult {
  isReady: boolean;
  fullBody: boolean;
  clearView: boolean;
  optimalScale: boolean;
  guidanceMessage: string;
}

export class CameraQualityGate {
  public static evaluateQuality(frame: PoseFrame | null, exercise: ExerciseType): CameraQualityResult {
    if (!frame || frame.confidence < 0.3) {
      return {
        isReady: false,
        fullBody: false,
        clearView: false,
        optimalScale: false,
        guidanceMessage: 'Step in front of the camera to begin setup'
      };
    }

    const joints = frame.joints;

    // 1. Joint Visibility Gate based on exercise type
    let hasRequiredJoints = false;
    let missingJointName = '';

    if (exercise === 'squat' || exercise === 'legPress') {
      const hasHip = (joints.left_hip?.score ?? 0) > 0.60 || (joints.right_hip?.score ?? 0) > 0.60;
      const hasKnee = (joints.left_knee?.score ?? 0) > 0.60 || (joints.right_knee?.score ?? 0) > 0.60;
      const hasAnkle = (joints.left_ankle?.score ?? 0) > 0.55 || (joints.right_ankle?.score ?? 0) > 0.55;
      hasRequiredJoints = hasHip && hasKnee && hasAnkle;
      if (!hasAnkle) missingJointName = 'feet and ankles';
      else if (!hasKnee) missingJointName = 'knees';
      else if (!hasHip) missingJointName = 'hips';
    } else {
      // Upper body exercises (Bicep Curls, Triceps Pushdown, Shoulder Press)
      const hasShoulder = (joints.left_shoulder?.score ?? 0) > 0.60 || (joints.right_shoulder?.score ?? 0) > 0.60;
      const hasElbow = (joints.left_elbow?.score ?? 0) > 0.60 || (joints.right_elbow?.score ?? 0) > 0.60;
      const hasWrist = (joints.left_wrist?.score ?? 0) > 0.55 || (joints.right_wrist?.score ?? 0) > 0.55;
      hasRequiredJoints = hasShoulder && hasElbow && hasWrist;
      if (!hasWrist) missingJointName = 'hands and wrists';
      else if (!hasElbow) missingJointName = 'elbows';
      else if (!hasShoulder) missingJointName = 'shoulders';
    }

    // 2. Clear View Gate (Confidence)
    const clearView = frame.confidence >= 0.65;

    // 3. Optimal Scale Gate (Body height span in frame)
    let minY = 1.0;
    let maxY = 0.0;
    let count = 0;

    for (const key in joints) {
      const pt = joints[key as keyof typeof joints];
      if (pt && pt.score > 0.5) {
        minY = Math.min(minY, pt.y);
        maxY = Math.max(maxY, pt.y);
        count++;
      }
    }

    const bodyHeightSpan = count >= 4 ? maxY - minY : 0.0;
    const isOptimalScale = bodyHeightSpan >= 0.28 && bodyHeightSpan <= 0.90;

    // Determine Actionable Guidance Message
    let message = 'Ready to record!';
    if (!hasRequiredJoints) {
      message = `Step back so your ${missingJointName} are visible`;
    } else if (bodyHeightSpan < 0.28) {
      message = 'Step closer to the camera';
    } else if (bodyHeightSpan > 0.90) {
      message = 'Step back slightly for full clearance';
    } else if (!clearView) {
      message = 'Ensure good lighting on your workout area';
    }

    const isReady = hasRequiredJoints && clearView && isOptimalScale;

    return {
      isReady,
      fullBody: hasRequiredJoints,
      clearView,
      optimalScale: isOptimalScale,
      guidanceMessage: message
    };
  }
}
