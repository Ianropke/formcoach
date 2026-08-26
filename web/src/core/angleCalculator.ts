import { Point2D } from './models';

export class AngleCalculator {
  /**
   * Computes the angle (in degrees [0 ... 180]) between vector BA and vector BC at vertex B.
   */
  public static angle2D(pointA: Point2D, vertexB: Point2D, pointC: Point2D): number {
    const vBAx = pointA.x - vertexB.x;
    const vBAy = pointA.y - vertexB.y;
    
    const vBCx = pointC.x - vertexB.x;
    const vBCy = pointC.y - vertexB.y;
    
    const dotProduct = (vBAx * vBCx) + (vBAy * vBCy);
    const magBA = Math.sqrt((vBAx * vBAx) + (vBAy * vBAy));
    const magBC = Math.sqrt((vBCx * vBCx) + (vBCy * vBCy));
    
    if (magBA === 0 || magBC === 0) {
      return 0.0;
    }
    
    const cosTheta = Math.max(-1.0, Math.min(1.0, dotProduct / (magBA * magBC)));
    const radians = Math.acos(cosTheta);
    return radians * (180.0 / Math.PI);
  }

  /**
   * Angle between vector (top -> bottom) and vertical downwards (0, 1).
   */
  public static angleRelativeToVertical(top: Point2D, bottom: Point2D): number {
    const vX = top.x - bottom.x;
    const vY = top.y - bottom.y; // In screen coords, top has smaller Y, so vY is negative
    
    // We want angle against vertical down (0, 1) or vertical up (0, -1)
    const mag = Math.sqrt((vX * vX) + (vY * vY));
    if (mag === 0) return 0.0;
    
    // Upward vertical vector is (0, -1)
    const dot = (vX * 0) + (vY * -1);
    const cosTheta = Math.max(-1.0, Math.min(1.0, dot / mag));
    return Math.acos(cosTheta) * (180.0 / Math.PI);
  }
}
