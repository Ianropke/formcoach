import Foundation
import CoreGraphics
import FormCoachCore

/// Generates realistic synthetic PoseFrame time-series for Biceps Curl testing
public struct SyntheticCurlGenerator {
    
    /// Generates a synthetic biceps curl set with configurable rep count, depths, tempos, and shoulder swing
    public static func generateCurlSet(
        repCount: Int = 10,
        fps: Double = 30.0,
        lockoutElbowAngle: Double = 165.0,
        peakElbowAngles: [Double] = [], // Defaults to 55°
        shoulderDriftAngles: [Double] = [], // Defaults to 0° (strict form)
        repDuration: Double = 2.4,
        pauseDuration: Double = 0.8
    ) -> PoseTimeSeries {
        var frames: [PoseFrame] = []
        var currentTime: TimeInterval = 0.0
        let dt = 1.0 / fps
        
        let peaks = peakElbowAngles.isEmpty ? Array(repeating: 55.0, count: repCount) : peakElbowAngles
        let drifts = shoulderDriftAngles.isEmpty ? Array(repeating: 0.0, count: repCount) : shoulderDriftAngles
        
        // Initial rest period (1.0s)
        let initialFrames = Int(1.0 * fps)
        for _ in 0..<initialFrames {
            frames.append(createCurlFrame(timestamp: currentTime, elbowAngle: lockoutElbowAngle, shoulderDrift: 0.0))
            currentTime += dt
        }
        
        // Generate each rep
        for repIdx in 0..<repCount {
            let targetPeak = repIdx < peaks.count ? peaks[repIdx] : 55.0
            let targetDrift = repIdx < drifts.count ? drifts[repIdx] : 0.0
            let repFramesCount = Int(repDuration * fps)
            
            for f in 0..<repFramesCount {
                let progress = Double(f) / Double(repFramesCount) // 0.0 to 1.0
                let angleOffset = (lockoutElbowAngle - targetPeak) * sin(progress * .pi)
                let currentAngle = lockoutElbowAngle - angleOffset
                let currentDrift = targetDrift * sin(progress * .pi)
                
                frames.append(createCurlFrame(
                    timestamp: currentTime,
                    elbowAngle: currentAngle,
                    shoulderDrift: currentDrift
                ))
                currentTime += dt
            }
            
            // Rest pause between reps
            let pauseFramesCount = Int(pauseDuration * fps)
            for _ in 0..<pauseFramesCount {
                frames.append(createCurlFrame(timestamp: currentTime, elbowAngle: lockoutElbowAngle, shoulderDrift: 0.0))
                currentTime += dt
            }
        }
        
        return PoseTimeSeries(frames: frames, fps: fps)
    }
    
    /// Generates a single curl PoseFrame with exact geometric elbow angle and shoulder swing
    public static func createCurlFrame(
        timestamp: TimeInterval,
        elbowAngle: Double,
        shoulderDrift: Double = 0.0
    ) -> PoseFrame {
        let shoulder = CGPoint(x: 0.50, y: 0.28)
        let upperArmLength: CGFloat = 0.18
        let forearmLength: CGFloat = 0.18
        
        // Shoulder drift is deviation forward from vertical
        let driftRad = CGFloat(shoulderDrift * (.pi / 180.0))
        let thetaRad = CGFloat(elbowAngle * (.pi / 180.0))
        
        // Elbow position
        let elbowX = shoulder.x - (upperArmLength * sin(driftRad))
        let elbowY = shoulder.y + (upperArmLength * cos(driftRad))
        let elbow = CGPoint(x: elbowX, y: elbowY)
        
        // Forearm rotated by theta relative to upper arm
        let wristX = elbowX - (forearmLength * sin(driftRad + thetaRad))
        let wristY = elbowY - (forearmLength * cos(thetaRad - driftRad))
        let wrist = CGPoint(x: wristX, y: wristY)
        
        let hip = CGPoint(x: 0.50, y: 0.52)
        let nose = CGPoint(x: 0.50, y: 0.15)
        
        let joints: [Joint: JointObservation] = [
            .nose: JointObservation(point2D: nose, confidence: 0.96),
            .leftShoulder: JointObservation(point2D: shoulder, confidence: 0.96),
            .rightShoulder: JointObservation(point2D: shoulder, confidence: 0.96),
            .leftElbow: JointObservation(point2D: elbow, confidence: 0.96),
            .rightElbow: JointObservation(point2D: elbow, confidence: 0.96),
            .leftWrist: JointObservation(point2D: wrist, confidence: 0.96),
            .rightWrist: JointObservation(point2D: wrist, confidence: 0.96),
            .leftHip: JointObservation(point2D: hip, confidence: 0.96),
            .rightHip: JointObservation(point2D: hip, confidence: 0.96),
            .leftKnee: JointObservation(point2D: CGPoint(x: 0.50, y: 0.74), confidence: 0.96),
            .rightKnee: JointObservation(point2D: CGPoint(x: 0.50, y: 0.74), confidence: 0.96),
            .leftAnkle: JointObservation(point2D: CGPoint(x: 0.50, y: 0.94), confidence: 0.96),
            .rightAnkle: JointObservation(point2D: CGPoint(x: 0.50, y: 0.94), confidence: 0.96)
        ]
        
        return PoseFrame(
            timestamp: timestamp,
            joints: joints,
            confidence: 0.96,
            isInterpolated: false
        )
    }
}
