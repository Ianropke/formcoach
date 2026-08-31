import { PoseFrame, JointName, ExerciseType } from './models';
import { AngleCalculator } from './angleCalculator';

/**
 * Computes 3D metric angle when worldJoints is available from MediaPipe,
 * falling back gracefully to 2D projection angle when only 2D coordinates exist.
 */
export function getJointAngle(
  f: PoseFrame,
  jointA: JointName,
  vertexB: JointName,
  jointC: JointName
): number | null {
  if (f.worldJoints) {
    const pA = f.worldJoints[jointA];
    const pB = f.worldJoints[vertexB];
    const pC = f.worldJoints[jointC];
    if (pA && pB && pC && pA.score > 0.4 && pB.score > 0.4 && pC.score > 0.4) {
      return AngleCalculator.angle3D(pA, pB, pC);
    }
  }
  const pA = f.joints[jointA];
  const pB = f.joints[vertexB];
  const pC = f.joints[jointC];
  if (pA && pB && pC && pA.score > 0.4 && pB.score > 0.4 && pC.score > 0.4) {
    const aspect = f.aspectRatio ?? 1;
    const pixel = (p: typeof pA) => ({ ...p, x: p.x * aspect });
    return AngleCalculator.angle2D(pixel(pA), pixel(pB), pixel(pC));
  }
  return null;
}

/**
 * Automatically evaluates both Left and Right limb kinematics and selects the dominant limb
 * with higher visibility confidence to handle equipment or partial occlusion seamlessly.
 */
export function getDominantLimbAngle(
  f: PoseFrame,
  leftJoints: [JointName, JointName, JointName],
  rightJoints: [JointName, JointName, JointName]
): number | null {
  const joints = f.worldJoints || f.joints;
  const [lA, lB, lC] = leftJoints;
  const [rA, rB, rC] = rightJoints;

  const scoreLeft = ((joints[lA]?.score ?? 0) + (joints[lB]?.score ?? 0) + (joints[lC]?.score ?? 0)) / 3;
  const scoreRight = ((joints[rA]?.score ?? 0) + (joints[rB]?.score ?? 0) + (joints[rC]?.score ?? 0)) / 3;

  if (scoreLeft >= scoreRight && scoreLeft > 0.4) {
    const angle = getJointAngle(f, lA, lB, lC);
    if (angle !== null) return angle;
  }
  if (scoreRight > 0.4) {
    const angle = getJointAngle(f, rA, rB, rC);
    if (angle !== null) return angle;
  }
  return getJointAngle(f, lA, lB, lC);
}

export function getActiveAngle(frame: PoseFrame, exercise: ExerciseType): number | null {
  return exercise === 'squat' || exercise === 'legPress'
    ? getDominantLimbAngle(frame, ['left_hip', 'left_knee', 'left_ankle'], ['right_hip', 'right_knee', 'right_ankle'])
    : getDominantLimbAngle(frame, ['left_shoulder', 'left_elbow', 'left_wrist'], ['right_shoulder', 'right_elbow', 'right_wrist']);
}
