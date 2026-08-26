import Foundation
import CoreGraphics

/// Mathematical vector geometry engine for deterministic joint angle and kinematic calculations
public struct AngleCalculator: Sendable {
    
    /// Calculates the 2D angle (in degrees [0° ... 180°]) formed by three points A -> B -> C with vertex at B.
    public static func angle2D(
        pointA: CGPoint,
        vertexB: CGPoint,
        pointC: CGPoint
    ) -> Double {
        let v1x = Double(pointA.x - vertexB.x)
        let v1y = Double(pointA.y - vertexB.y)
        
        let v2x = Double(pointC.x - vertexB.x)
        let v2y = Double(pointC.y - vertexB.y)
        
        let dotProduct = (v1x * v2x) + (v1y * v2y)
        let mag1 = sqrt((v1x * v1x) + (v1y * v1y))
        let mag2 = sqrt((v2x * v2x) + (v2y * v2y))
        
        guard mag1 > 1e-6, mag2 > 1e-6 else {
            return 0.0
        }
        
        let cosine = min(max(dotProduct / (mag1 * mag2), -1.0), 1.0)
        let angleRad = acos(cosine)
        return angleRad * (180.0 / .pi)
    }
    
    /// Calculates the 3D angle (in degrees [0° ... 180°]) formed by three 3D points with vertex at B.
    public static func angle3D(
        a: (x: Double, y: Double, z: Double),
        b: (x: Double, y: Double, z: Double),
        c: (x: Double, y: Double, z: Double)
    ) -> Double {
        let v1x = a.x - b.x
        let v1y = a.y - b.y
        let v1z = a.z - b.z
        
        let v2x = c.x - b.x
        let v2y = c.y - b.y
        let v2z = c.z - b.z
        
        let dotProduct = (v1x * v2x) + (v1y * v2y) + (v1z * v2z)
        let mag1 = sqrt((v1x * v1x) + (v1y * v1y) + (v1z * v1z))
        let mag2 = sqrt((v2x * v2x) + (v2y * v2y) + (v2z * v2z))
        
        guard mag1 > 1e-6, mag2 > 1e-6 else {
            return 0.0
        }
        
        let cosine = min(max(dotProduct / (mag1 * mag2), -1.0), 1.0)
        let angleRad = acos(cosine)
        return angleRad * (180.0 / .pi)
    }
    
    /// Calculates the inclination angle (in degrees) of a segment (e.g. Shoulder to Hip) relative to the vertical downward vector (0, 1)
    public static func angleRelativeToVertical(
        top: CGPoint,
        bottom: CGPoint
    ) -> Double {
        let dx = Double(top.x - bottom.x)
        let dy = Double(top.y - bottom.y) // Top is higher (smaller y) in top-left coords, so dy < 0
        
        // Vector from bottom to top
        let vTopX = dx
        let vTopY = dy
        
        // Vertical upward vector is (0, -1)
        let dot = (vTopX * 0.0) + (vTopY * -1.0)
        let mag = sqrt((vTopX * vTopX) + (vTopY * vTopY))
        
        guard mag > 1e-6 else { return 0.0 }
        
        let cosine = min(max(dot / mag, -1.0), 1.0)
        return acos(cosine) * (180.0 / .pi)
    }
    
    /// Euclidean distance between two points in normalized space
    public static func distance2D(_ a: CGPoint, _ b: CGPoint) -> Double {
        let dx = Double(a.x - b.x)
        let dy = Double(a.y - b.y)
        return sqrt((dx * dx) + (dy * dy))
    }
}
