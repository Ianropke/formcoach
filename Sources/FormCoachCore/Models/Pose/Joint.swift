import Foundation

/// Standardized anatomical joints tracked by FormCoach
public enum Joint: String, Codable, CaseIterable, Sendable {
    case nose
    case leftEye
    case rightEye
    case leftEar
    case rightEar
    case leftShoulder
    case rightShoulder
    case leftElbow
    case rightElbow
    case leftWrist
    case rightWrist
    case leftHip
    case rightHip
    case leftKnee
    case rightKnee
    case leftAnkle
    case rightAnkle
    case neck
    case root

    public var isUpperBody: Bool {
        switch self {
        case .leftShoulder, .rightShoulder, .leftElbow, .rightElbow, .leftWrist, .rightWrist, .neck:
            return true
        default:
            return false
        }
    }

    public var isLowerBody: Bool {
        switch self {
        case .leftHip, .rightHip, .leftKnee, .rightKnee, .leftAnkle, .rightAnkle, .root:
            return true
        default:
            return false
        }
    }
}

/// Standard skeletal connection pairs for rendering overlays
public struct JointConnection: Sendable, Hashable {
    public let from: Joint
    public let to: Joint
    
    public init(_ from: Joint, _ to: Joint) {
        self.from = from
        self.to = to
    }
    
    public static let standardSkeleton: [JointConnection] = [
        // Torso / Head
        JointConnection(.nose, .neck),
        JointConnection(.neck, .leftShoulder),
        JointConnection(.neck, .rightShoulder),
        JointConnection(.leftShoulder, .rightShoulder),
        JointConnection(.leftShoulder, .leftHip),
        JointConnection(.rightShoulder, .rightHip),
        JointConnection(.leftHip, .rightHip),
        
        // Left Arm
        JointConnection(.leftShoulder, .leftElbow),
        JointConnection(.leftElbow, .leftWrist),
        
        // Right Arm
        JointConnection(.rightShoulder, .rightElbow),
        JointConnection(.rightElbow, .rightWrist),
        
        // Left Leg
        JointConnection(.leftHip, .leftKnee),
        JointConnection(.leftKnee, .leftAnkle),
        
        // Right Leg
        JointConnection(.rightHip, .rightKnee),
        JointConnection(.rightKnee, .rightAnkle)
    ]
}
