import { PoseFrame, JointName, Point2D, Point3D } from './models';

export class PoseSmoother {
  private alpha: number;

  constructor(alpha = 0.35) {
    this.alpha = alpha;
  }

  /**
   * Applies Exponential Moving Average (EMA) and interpolates short frame dropouts (<= 3 frames)
   */
  public smooth(frames: PoseFrame[]): PoseFrame[] {
    if (frames.length === 0) return [];
    
    // 1. Interpolate missing frames
    const interpolated = this.interpolateDropouts(frames);
    
    // 2. Exponential Moving Average smoothing
    const smoothed: PoseFrame[] = [];
    let previousJoints: Partial<Record<JointName, Point2D>> = {};

    for (let i = 0; i < interpolated.length; i++) {
      const current = interpolated[i];
      const newWorldJoints: Partial<Record<JointName, Point3D>> = {};
      const previousWorld = smoothed[i - 1]?.worldJoints;
      for (const key of Object.keys(current.worldJoints ?? {}) as JointName[]) {
        const point = current.worldJoints![key]!;
        const previous = previousWorld?.[key];
        newWorldJoints[key] = previous && previous.score > 0.4 && point.score > 0.4 ? {
          x: this.alpha * point.x + (1 - this.alpha) * previous.x,
          y: this.alpha * point.y + (1 - this.alpha) * previous.y,
          z: this.alpha * (point.z ?? 0) + (1 - this.alpha) * (previous.z ?? 0),
          score: point.score
        } : { ...point };
      }
      const newJoints: Partial<Record<JointName, Point2D>> = {};

      for (const jointKey in current.joints) {
        const key = jointKey as JointName;
        const currPt = current.joints[key];
        const prevPt = previousJoints[key];

        if (currPt) {
          if (prevPt) {
            newJoints[key] = {
              x: this.alpha * currPt.x + (1 - this.alpha) * prevPt.x,
              y: this.alpha * currPt.y + (1 - this.alpha) * prevPt.y,
              score: currPt.score
            };
          } else {
            newJoints[key] = { ...currPt };
          }
        }
      }

      previousJoints = newJoints;
      smoothed.push({
        timestamp: current.timestamp,
        aspectRatio: current.aspectRatio,
        worldJoints: current.worldJoints ? newWorldJoints : undefined,
        joints: newJoints,
        confidence: current.confidence
      });
    }

    return smoothed;
  }

  private interpolateDropouts(frames: PoseFrame[]): PoseFrame[] {
    if (frames.length < 3) return frames;
    const result: PoseFrame[] = frames.map(f => ({ ...f, joints: { ...f.joints } }));

    const jointKeys: JointName[] = [
      'left_shoulder', 'right_shoulder',
      'left_elbow', 'right_elbow',
      'left_wrist', 'right_wrist',
      'left_hip', 'right_hip',
      'left_knee', 'right_knee',
      'left_ankle', 'right_ankle'
    ];

    for (const key of jointKeys) {
      let gapStart = -1;

      for (let i = 0; i < result.length; i++) {
        const hasJoint = result[i].joints[key] !== undefined;

        if (!hasJoint && gapStart === -1) {
          gapStart = i;
        } else if (hasJoint && gapStart !== -1) {
          const gapLen = i - gapStart;
          if (gapLen <= 3 && gapStart > 0) {
            const beforePt = result[gapStart - 1].joints[key]!;
            const afterPt = result[i].joints[key]!;

            for (let g = 0; g < gapLen; g++) {
              const t = (g + 1) / (gapLen + 1);
              result[gapStart + g].joints[key] = {
                x: beforePt.x + (afterPt.x - beforePt.x) * t,
                y: beforePt.y + (afterPt.y - beforePt.y) * t,
                score: (beforePt.score + afterPt.score) / 2
              };
            }
          }
          gapStart = -1;
        }
      }
    }

    return result;
  }
}
