import { PoseFrame } from '../core/models';

export class SyntheticSquatGenerator {
  public static generateSquatSet(
    repCount = 10,
    fps = 30.0,
    standingKneeAngle = 175.0,
    targetDepth = 85.0,
    repDuration = 3.0,
    pauseDuration = 1.0
  ): PoseFrame[] {
    const frames: PoseFrame[] = [];
    let currentTime = 0.0;
    const dt = 1.0 / fps;

    // Initial standing (1.0s)
    for (let i = 0; i < fps; i++) {
      frames.push(this.createSquatFrame(currentTime, standingKneeAngle));
      currentTime += dt;
    }

    // Reps
    for (let rep = 0; rep < repCount; rep++) {
      const repFramesCount = Math.floor(repDuration * fps);
      for (let f = 0; f < repFramesCount; f++) {
        const progress = f / repFramesCount;
        const angleOffset = (standingKneeAngle - targetDepth) * Math.sin(progress * Math.PI);
        const currentAngle = standingKneeAngle - angleOffset;
        frames.push(this.createSquatFrame(currentTime, currentAngle));
        currentTime += dt;
      }

      // Pause between reps
      const pauseFrames = Math.floor(pauseDuration * fps);
      for (let p = 0; p < pauseFrames; p++) {
        frames.push(this.createSquatFrame(currentTime, standingKneeAngle));
        currentTime += dt;
      }
    }

    return frames;
  }

  public static createSquatFrame(timestamp: number, kneeAngle: number): PoseFrame {
    const clampedAngle = Math.min(Math.max(kneeAngle, 50.0), 180.0);
    const phi = ((180.0 - clampedAngle) / 2.0) * (Math.PI / 180.0);

    const hip = { x: 0.50, y: 0.48, score: 0.96 };
    const limbLength = 0.22;

    const kneeX = hip.x - (limbLength * Math.sin(phi));
    const kneeY = hip.y + (limbLength * Math.cos(phi));
    const knee = { x: kneeX, y: kneeY, score: 0.96 };

    const ankleX = hip.x;
    const ankleY = knee.y + (limbLength * Math.cos(phi));
    const ankle = { x: ankleX, y: ankleY, score: 0.96 };

    return {
      timestamp,
      joints: {
        nose: { x: 0.50, y: 0.14, score: 0.96 },
        left_shoulder: { x: 0.50, y: 0.26, score: 0.96 },
        left_hip: hip,
        left_knee: knee,
        left_ankle: ankle
      },
      confidence: 0.96
    };
  }
}

export class SyntheticCurlGenerator {
  public static generateCurlSet(
    repCount = 10,
    fps = 30.0,
    lockoutElbowAngle = 165.0,
    peakElbowAngle = 55.0,
    shoulderDrift = 0.0,
    repDuration = 2.4,
    pauseDuration = 0.8
  ): PoseFrame[] {
    const frames: PoseFrame[] = [];
    let currentTime = 0.0;
    const dt = 1.0 / fps;

    // Initial rest (1.0s)
    for (let i = 0; i < fps; i++) {
      frames.push(this.createCurlFrame(currentTime, lockoutElbowAngle, 0.0));
      currentTime += dt;
    }

    for (let rep = 0; rep < repCount; rep++) {
      const repFramesCount = Math.floor(repDuration * fps);
      for (let f = 0; f < repFramesCount; f++) {
        const progress = f / repFramesCount;
        const angleOffset = (lockoutElbowAngle - peakElbowAngle) * Math.sin(progress * Math.PI);
        const currentAngle = lockoutElbowAngle - angleOffset;
        const currentDrift = shoulderDrift * Math.sin(progress * Math.PI);
        frames.push(this.createCurlFrame(currentTime, currentAngle, currentDrift));
        currentTime += dt;
      }

      const pauseFrames = Math.floor(pauseDuration * fps);
      for (let p = 0; p < pauseFrames; p++) {
        frames.push(this.createCurlFrame(currentTime, lockoutElbowAngle, 0.0));
        currentTime += dt;
      }
    }

    return frames;
  }

  public static createCurlFrame(timestamp: number, elbowAngle: number, shoulderDrift = 0.0): PoseFrame {
    const shoulder = { x: 0.50, y: 0.28, score: 0.96 };
    const upperArmLength = 0.18;
    const forearmLength = 0.18;

    const driftRad = shoulderDrift * (Math.PI / 180.0);
    const thetaRad = elbowAngle * (Math.PI / 180.0);

    const elbowX = shoulder.x - (upperArmLength * Math.sin(driftRad));
    const elbowY = shoulder.y + (upperArmLength * Math.cos(driftRad));
    const elbow = { x: elbowX, y: elbowY, score: 0.96 };

    const wristX = elbowX - (forearmLength * Math.sin(driftRad + thetaRad));
    const wristY = elbowY - (forearmLength * Math.cos(thetaRad - driftRad));
    const wrist = { x: wristX, y: wristY, score: 0.96 };

    return {
      timestamp,
      joints: {
        left_shoulder: shoulder,
        left_elbow: elbow,
        left_wrist: wrist,
        left_hip: { x: 0.50, y: 0.52, score: 0.96 }
      },
      confidence: 0.96
    };
  }
}

export class SyntheticPressGenerator {
  public static generatePressSet(
    repCount = 5,
    fps = 30.0,
    rackedAngle = 80.0,
    lockoutAngleLeft = 160.0,
    lockoutAngleRight = 160.0
  ): PoseFrame[] {
    const frames: PoseFrame[] = [];
    let currentTime = 0.0;
    const dt = 1.0 / fps;
    const repDuration = 2.5;

    for (let rep = 0; rep < repCount; rep++) {
      const repFramesCount = Math.floor(repDuration * fps);
      for (let f = 0; f < repFramesCount; f++) {
        const progress = f / repFramesCount;
        const leftAngle = rackedAngle + (lockoutAngleLeft - rackedAngle) * Math.sin(progress * Math.PI);
        const rightAngle = rackedAngle + (lockoutAngleRight - rackedAngle) * Math.sin(progress * Math.PI);

        frames.push(this.createPressFrame(currentTime, leftAngle, rightAngle));
        currentTime += dt;
      }
    }

    return frames;
  }

  public static createPressFrame(timestamp: number, leftAngle: number, rightAngle: number): PoseFrame {
    const sL = { x: 0.40, y: 0.35, score: 0.96 };
    const sR = { x: 0.60, y: 0.35, score: 0.96 };
    const upperArmLen = 0.15;
    const forearmLen = 0.15;

    // Left elbow below shoulder
    const eL = { x: 0.38, y: 0.50, score: 0.96 };
    const eR = { x: 0.62, y: 0.50, score: 0.96 };

    // Angle theta at elbow between (s - e) and (w - e)
    const thetaLRad = (leftAngle * Math.PI) / 180.0;
    const thetaRRad = (rightAngle * Math.PI) / 180.0;

    // Upward angle of upper arm is ~atan2(sL.y - eL.y, sL.x - eL.x)
    const baseAngleL = Math.atan2(sL.y - eL.y, sL.x - eL.x);
    const baseAngleR = Math.atan2(sR.y - eR.y, sR.x - eR.x);

    const wL = {
      x: eL.x + forearmLen * Math.cos(baseAngleL + thetaLRad),
      y: eL.y + forearmLen * Math.sin(baseAngleL + thetaLRad),
      score: 0.96
    };

    const wR = {
      x: eR.x + forearmLen * Math.cos(baseAngleR - thetaRRad),
      y: eR.y + forearmLen * Math.sin(baseAngleR - thetaRRad),
      score: 0.96
    };

    return {
      timestamp,
      joints: {
        left_shoulder: sL,
        right_shoulder: sR,
        left_elbow: eL,
        right_elbow: eR,
        left_wrist: wL,
        right_wrist: wR
      },
      confidence: 0.96
    };
  }
}
