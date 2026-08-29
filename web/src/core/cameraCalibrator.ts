import { PoseFrame, CameraViewType, Point2D, Point3D } from "./models";

export interface CameraCalibrationResult {
  pitchAngleDeg: number;       // Camera tilt (0° = level, >10° = floor placement looking up)
  yawAngleDeg: number;         // Body orientation (0° = pure side profile, 90° = direct front)
  detectedProfile: CameraViewType;
  isFloorPlacement: boolean;
  confidence: number;
}

export class CameraCalibrator {
  /**
   * Evaluates camera pitch (floor tilt) and athlete yaw orientation (side / 45° / front)
   * using 3D world landmarks and screen projections.
   */
  public static calibrate(frame: PoseFrame | null): CameraCalibrationResult {
    if (!frame || frame.confidence < 0.4) {
      return {
        pitchAngleDeg: 0,
        yawAngleDeg: 0,
        detectedProfile: "side",
        isFloorPlacement: false,
        confidence: 0
      };
    }

    const joints = frame.worldJoints || frame.joints;
    const sL = joints.left_shoulder;
    const sR = joints.right_shoulder;
    const hL = joints.left_hip;
    const hR = joints.right_hip;

    if (!sL && !sR && !hL && !hR) {
      return {
        pitchAngleDeg: 0,
        yawAngleDeg: 0,
        detectedProfile: "side",
        isFloorPlacement: false,
        confidence: 0
      };
    }

    const getZ = (pt: Point2D | Point3D | undefined): number => (pt as Point3D)?.z ?? 0;

    // 1. Calculate Mid-Shoulder and Mid-Hip
    const midShoulder: Point3D = {
      x: ((sL?.x ?? sR?.x ?? 0) + (sR?.x ?? sL?.x ?? 0)) / 2,
      y: ((sL?.y ?? sR?.y ?? 0) + (sR?.y ?? sL?.y ?? 0)) / 2,
      z: (getZ(sL) + getZ(sR)) / 2,
      score: Math.min(sL?.score ?? 1, sR?.score ?? 1)
    };

    const midHip: Point3D = {
      x: ((hL?.x ?? hR?.x ?? 0) + (hR?.x ?? hL?.x ?? 0)) / 2,
      y: ((hL?.y ?? hR?.y ?? 0) + (hR?.y ?? hL?.y ?? 0)) / 2,
      z: (getZ(hL) + getZ(hR)) / 2,
      score: Math.min(hL?.score ?? 1, hR?.score ?? 1)
    };

    // 2. Pitch Angle: Vector from hip to shoulder
    const dy = midShoulder.y - midHip.y; // Typically negative in screen space
    const dz = (midShoulder.z ?? 0) - (midHip.z ?? 0);

    let pitchAngleDeg = 0;
    if (Math.abs(dy) > 0.05) {
      // In 3D metric coords, angle = atan2(dz, -dy)
      const pitchRad = Math.atan2(dz, Math.abs(dy));
      pitchAngleDeg = Math.round(pitchRad * (180 / Math.PI));
    }

    const isFloorPlacement = pitchAngleDeg >= 12;

    // 3. Yaw Orientation (Hips span along X vs Z)
    let yawAngleDeg = 0;
    if (hL && hR) {
      const dx = Math.abs(hL.x - hR.x);
      const dzHips = Math.abs(getZ(hL) - getZ(hR));
      
      // Front view has high dx, side view has high dz
      const yawRad = Math.atan2(dx, dzHips || 0.001);
      yawAngleDeg = Math.round(yawRad * (180 / Math.PI));
    }

    let detectedProfile: CameraViewType = "side";
    if (yawAngleDeg > 65) {
      detectedProfile = "front";
    } else if (yawAngleDeg >= 28) {
      detectedProfile = "front45";
    } else {
      detectedProfile = "side";
    }

    return {
      pitchAngleDeg,
      yawAngleDeg,
      detectedProfile,
      isFloorPlacement,
      confidence: frame.confidence
    };
  }
}
