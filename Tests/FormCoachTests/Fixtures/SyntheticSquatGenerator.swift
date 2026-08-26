import Foundation
import CoreGraphics
import FormCoachCore

/// Generates realistic synthetic PoseFrame time-series for deterministic testing
public struct SyntheticSquatGenerator {
    
    /// Generates a synthetic squat set with configurable rep count, depths, and tempos
    public static func generateSquatSet(
        repCount: Int = 10,
        fps: Double = 30.0,
        standingKneeAngle: Double = 175.0,
        bottomKneeAngles: [Double] = [], // If empty, defaults to 85° for all reps
        repDuration: Double = 3.0,
        standingPauseDuration: Double = 1.0,
        dropFramesIndices: Set<Int> = []
    ) -> PoseTimeSeries {
        var frames: [PoseFrame] = []
        var currentTime: TimeInterval = 0.0
        let dt = 1.0 / fps
        
        let depths = bottomKneeAngles.isEmpty ? Array(repeating: 85.0, count: repCount) : bottomKneeAngles
        
        // Initial standing period (1.5s)
        let initialFrames = Int(1.5 * fps)
        for _ in 0..<initialFrames {
            frames.append(createSquatFrame(timestamp: currentTime, kneeAngle: standingKneeAngle))
            currentTime += dt
        }
        
        // Generate each rep
        for repIdx in 0..<repCount {
            let targetDepth = repIdx < depths.count ? depths[repIdx] : 85.0
            let repFramesCount = Int(repDuration * fps)
            
            for f in 0..<repFramesCount {
                // Sinusoidal movement profile between standing and targetDepth
                let progress = Double(f) / Double(repFramesCount) // 0.0 to 1.0
                let angleOffset = (standingKneeAngle - targetDepth) * sin(progress * .pi)
                let currentAngle = standingKneeAngle - angleOffset
                
                let isOccluded = dropFramesIndices.contains(frames.count)
                let frame = createSquatFrame(
                    timestamp: currentTime,
                    kneeAngle: currentAngle,
                    isOccluded: isOccluded
                )
                frames.append(frame)
                currentTime += dt
            }
            
            // Standing pause between reps
            let pauseFramesCount = Int(standingPauseDuration * fps)
            for _ in 0..<pauseFramesCount {
                frames.append(createSquatFrame(timestamp: currentTime, kneeAngle: standingKneeAngle))
                currentTime += dt
            }
        }
        
        return PoseTimeSeries(frames: frames, fps: fps)
    }
    
    /// Generates a single squat PoseFrame where the Hip-Knee-Ankle 2D angle EXACTLY equals kneeAngle
    public static func createSquatFrame(
        timestamp: TimeInterval,
        kneeAngle: Double,
        isOccluded: Bool = false
    ) -> PoseFrame {
        if isOccluded {
            return PoseFrame(
                timestamp: timestamp,
                joints: [:],
                confidence: 0.0,
                isInterpolated: false
            )
        }
        
        let clampedAngle = min(max(kneeAngle, 50.0), 180.0)
        let phi = ((180.0 - clampedAngle) / 2.0) * (.pi / 180.0)
        
        let hip = CGPoint(x: 0.50, y: 0.48)
        let limbLength: CGFloat = 0.22
        
        let kneeX = hip.x - (limbLength * CGFloat(sin(phi)))
        let kneeY = hip.y + (limbLength * CGFloat(cos(phi)))
        let knee = CGPoint(x: kneeX, y: kneeY)
        
        let ankleX = hip.x
        let ankleY = knee.y + (limbLength * CGFloat(cos(phi)))
        let ankle = CGPoint(x: ankleX, y: ankleY)
        
        let shoulder = CGPoint(x: 0.50, y: 0.26)
        let nose = CGPoint(x: 0.50, y: 0.14)
        
        let joints: [Joint: JointObservation] = [
            .nose: JointObservation(point2D: nose, confidence: 0.96),
            .leftShoulder: JointObservation(point2D: shoulder, confidence: 0.96),
            .rightShoulder: JointObservation(point2D: shoulder, confidence: 0.96),
            .leftHip: JointObservation(point2D: hip, confidence: 0.96),
            .rightHip: JointObservation(point2D: hip, confidence: 0.96),
            .leftKnee: JointObservation(point2D: knee, confidence: 0.96),
            .rightKnee: JointObservation(point2D: knee, confidence: 0.96),
            .leftAnkle: JointObservation(point2D: ankle, confidence: 0.96),
            .rightAnkle: JointObservation(point2D: ankle, confidence: 0.96)
        ]
        
        return PoseFrame(
            timestamp: timestamp,
            joints: joints,
            confidence: 0.96,
            isInterpolated: false
        )
    }
}
