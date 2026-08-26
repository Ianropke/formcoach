import Foundation
import CoreGraphics

/// Observation for an individual anatomical joint
public struct JointObservation: Codable, Sendable, Equatable {
    /// Normalized 2D position in top-left standard coordinates [0.0 ... 1.0]
    public var point2D: CGPoint
    
    /// Optional 3D depth relative to root/hip centroid in meters (if available)
    public var depthZ: Double?
    
    /// Detection confidence score [0.0 ... 1.0]
    public var confidence: Double
    
    public init(
        point2D: CGPoint,
        depthZ: Double? = nil,
        confidence: Double
    ) {
        self.point2D = point2D
        self.depthZ = depthZ
        self.confidence = confidence
    }
    
    public var x: Double { Double(point2D.x) }
    public var y: Double { Double(point2D.y) }
    public var z: Double { depthZ ?? 0.0 }
    
    public var isTracked: Bool {
        confidence >= 0.35
    }
}
