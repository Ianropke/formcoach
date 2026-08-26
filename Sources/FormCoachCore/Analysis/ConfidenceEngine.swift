import Foundation

/// Evaluates overall set tracking reliability and framing compliance
public struct ConfidenceEngine: Sendable {
    
    public static func evaluateSetConfidence(
        timeSeries: PoseTimeSeries,
        requiredJoints: Set<Joint>
    ) -> PoseConfidence {
        guard !timeSeries.isEmpty else {
            return PoseConfidence(
                overallScore: 0.0,
                level: .insufficient,
                visibleJointRatio: 0.0,
                meanJointConfidence: 0.0,
                message: "No video frames recorded"
            )
        }
        
        var totalVisibility = 0.0
        var totalMeanConfidence = 0.0
        var missingJointCounters: [Joint: Int] = [:]
        
        for frame in timeSeries.frames {
            let conf = PoseConfidence.evaluate(joints: frame.joints, required: requiredJoints)
            totalVisibility += conf.visibleJointRatio
            totalMeanConfidence += conf.meanJointConfidence
            
            for joint in requiredJoints {
                if !(frame.joints[joint]?.isTracked ?? false) {
                    missingJointCounters[joint, default: 0] += 1
                }
            }
        }
        
        let frameCount = Double(timeSeries.count)
        let avgVisibility = totalVisibility / frameCount
        let avgJointConfidence = totalMeanConfidence / frameCount
        let overall = (avgVisibility * 0.6) + (avgJointConfidence * 0.4)
        
        let level: TrackingConfidenceLevel
        let message: String?
        
        if avgVisibility >= 0.88 && avgJointConfidence >= 0.65 {
            level = .good
            message = nil
        } else if avgVisibility >= 0.65 && avgJointConfidence >= 0.45 {
            level = .limited
            let prominentMissing = missingJointCounters
                .filter { Double($0.value) / frameCount > 0.3 }
                .map { $0.key.rawValue }
            message = prominentMissing.isEmpty ? "Partial tracking quality" : "Intermittent tracking on: \(prominentMissing.joined(separator: ", "))"
        } else {
            level = .insufficient
            let prominentMissing = missingJointCounters
                .filter { Double($0.value) / frameCount > 0.4 }
                .map { $0.key.rawValue }
            message = "Insufficient tracking on required joints: \(prominentMissing.joined(separator: ", "))"
        }
        
        return PoseConfidence(
            overallScore: overall,
            level: level,
            visibleJointRatio: avgVisibility,
            meanJointConfidence: avgJointConfidence,
            message: message
        )
    }
}
