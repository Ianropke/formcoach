import Foundation

/// Discrete tracking confidence level for UI and rule triggers
public enum TrackingConfidenceLevel: String, Codable, Sendable {
    case good
    case limited
    case insufficient
    
    public var displayText: String {
        switch self {
        case .good: return "Good"
        case .limited: return "Limited"
        case .insufficient: return "Insufficient"
        }
    }
}

/// Aggregated pose confidence structure
public struct PoseConfidence: Codable, Sendable, Equatable {
    public let overallScore: Double // 0.0 ... 1.0
    public let level: TrackingConfidenceLevel
    public let visibleJointRatio: Double
    public let meanJointConfidence: Double
    public let message: String?
    
    public init(
        overallScore: Double,
        level: TrackingConfidenceLevel,
        visibleJointRatio: Double,
        meanJointConfidence: Double,
        message: String? = nil
    ) {
        self.overallScore = overallScore
        self.level = level
        self.visibleJointRatio = visibleJointRatio
        self.meanJointConfidence = meanJointConfidence
        self.message = message
    }
    
    public static func evaluate(
        joints: [Joint: JointObservation],
        required: Set<Joint>
    ) -> PoseConfidence {
        guard !required.isEmpty else {
            return PoseConfidence(
                overallScore: 1.0,
                level: .good,
                visibleJointRatio: 1.0,
                meanJointConfidence: 1.0
            )
        }
        
        var trackedCount = 0
        var totalConf = 0.0
        var missingJoints: [String] = []
        
        for joint in required {
            if let obs = joints[joint], obs.isTracked {
                trackedCount += 1
                totalConf += obs.confidence
            } else {
                missingJoints.append(joint.rawValue)
            }
        }
        
        let ratio = Double(trackedCount) / Double(required.count)
        let meanConf = trackedCount > 0 ? (totalConf / Double(trackedCount)) : 0.0
        let overall = (ratio * 0.6) + (meanConf * 0.4)
        
        let level: TrackingConfidenceLevel
        let message: String?
        
        if ratio >= 0.9 && meanConf >= 0.65 {
            level = .good
            message = nil
        } else if ratio >= 0.7 && meanConf >= 0.45 {
            level = .limited
            message = missingJoints.isEmpty ? "Partial tracking quality" : "Occluded: \(missingJoints.joined(separator: ", "))"
        } else {
            level = .insufficient
            message = "Insufficient tracking: \(missingJoints.joined(separator: ", ")) missing"
        }
        
        return PoseConfidence(
            overallScore: overall,
            level: level,
            visibleJointRatio: ratio,
            meanJointConfidence: meanConf,
            message: message
        )
    }
}
