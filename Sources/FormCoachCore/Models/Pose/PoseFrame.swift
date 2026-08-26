import Foundation
import CoreGraphics

/// Single timestamped frame of skeletal landmarks in normalized coordinates
public struct PoseFrame: Codable, Sendable, Equatable {
    /// Timestamp in seconds from session / video recording start
    public let timestamp: TimeInterval
    
    /// Map of detected joints
    public var joints: [Joint: JointObservation]
    
    /// Aggregate detection confidence
    public let confidence: Double
    
    /// True if interpolated across a micro-dropout
    public var isInterpolated: Bool
    
    public init(
        timestamp: TimeInterval,
        joints: [Joint: JointObservation],
        confidence: Double,
        isInterpolated: Bool = false
    ) {
        self.timestamp = timestamp
        self.joints = joints
        self.confidence = confidence
        self.isInterpolated = isInterpolated
    }
    
    /// Helper to get observation for a specific joint
    public func observation(for joint: Joint) -> JointObservation? {
        joints[joint]
    }
    
    /// Helper to get 2D point if confidence is above threshold
    public func point(for joint: Joint, minConfidence: Double = 0.35) -> CGPoint? {
        guard let obs = joints[joint], obs.confidence >= minConfidence else { return nil }
        return obs.point2D
    }
    
    /// Bounding box enclosing all tracked joints
    public var boundingBox: CGRect? {
        let trackedPoints = joints.values.filter { $0.isTracked }.map { $0.point2D }
        guard !trackedPoints.isEmpty else { return nil }
        
        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        
        for pt in trackedPoints {
            minX = min(minX, pt.x)
            maxX = max(maxX, pt.x)
            minY = min(minY, pt.y)
            maxY = max(maxY, pt.y)
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
