import Foundation
import CoreGraphics
import FormCoachCore

/// Generates realistic synthetic PoseFrame time-series for Overhead Shoulder Press testing
public struct SyntheticPressGenerator {
    
    public static func generatePressSet(
        repCount: Int = 10,
        fps: Double = 30.0,
        rackElbowAngle: Double = 80.0,
        lockoutElbowAngles: [Double] = [], // Defaults to 168°
        asymmetryAngles: [Double] = [], // Defaults to 0° (balanced)
        repDuration: Double = 2.5,
        pauseDuration: Double = 0.8
    ) -> PoseTimeSeries {
        var frames: [PoseFrame] = []
        var currentTime: TimeInterval = 0.0
        let dt = 1.0 / fps
        
        let lockouts = lockoutElbowAngles.isEmpty ? Array(repeating: 168.0, count: repCount) : lockoutElbowAngles
        let asyms = asymmetryAngles.isEmpty ? Array(repeating: 0.0, count: repCount) : asymmetryAngles
        
        // Initial rest period (1.0s)
        let initialFrames = Int(1.0 * fps)
        for _ in 0..<initialFrames {
            frames.append(createPressFrame(timestamp: currentTime, leftAngle: rackElbowAngle, rightAngle: rackElbowAngle))
            currentTime += dt
        }
        
        // Generate each rep
        for repIdx in 0..<repCount {
            let targetLockout = repIdx < lockouts.count ? lockouts[repIdx] : 168.0
            let targetAsym = repIdx < asyms.count ? asyms[repIdx] : 0.0
            let repFramesCount = Int(repDuration * fps)
            
            for f in 0..<repFramesCount {
                let progress = Double(f) / Double(repFramesCount) // 0.0 to 1.0
                let angleOffset = (targetLockout - rackElbowAngle) * sin(progress * .pi)
                let currentLeft = rackElbowAngle + angleOffset
                let currentRight = rackElbowAngle + ((targetLockout - targetAsym - rackElbowAngle) * sin(progress * .pi))
                
                frames.append(createPressFrame(
                    timestamp: currentTime,
                    leftAngle: currentLeft,
                    rightAngle: currentRight
                ))
                currentTime += dt
            }
            
            // Rest pause between reps
            let pauseFramesCount = Int(pauseDuration * fps)
            for _ in 0..<pauseFramesCount {
                frames.append(createPressFrame(timestamp: currentTime, leftAngle: rackElbowAngle, rightAngle: rackElbowAngle))
                currentTime += dt
            }
        }
        
        return PoseTimeSeries(frames: frames, fps: fps)
    }
    
    /// Generates a single shoulder press PoseFrame in Front view
    public static func createPressFrame(
        timestamp: TimeInterval,
        leftAngle: Double,
        rightAngle: Double
    ) -> PoseFrame {
        let leftShoulder = CGPoint(x: 0.42, y: 0.35)
        let rightShoulder = CGPoint(x: 0.58, y: 0.35)
        let upperArmLength: CGFloat = 0.14
        let forearmLength: CGFloat = 0.14
        
        // Left arm geometry
        let leftElbow = CGPoint(x: leftShoulder.x - upperArmLength, y: leftShoulder.y)
        let leftRad = CGFloat(leftAngle * (.pi / 180.0))
        let leftWristX = leftElbow.x + (forearmLength * cos(leftRad))
        let leftWristY = leftElbow.y - (forearmLength * sin(leftRad))
        let leftWrist = CGPoint(x: leftWristX, y: leftWristY)
        
        // Right arm geometry
        let rightElbow = CGPoint(x: rightShoulder.x + upperArmLength, y: rightShoulder.y)
        let rightRad = CGFloat(rightAngle * (.pi / 180.0))
        let rightWristX = rightElbow.x - (forearmLength * cos(rightRad))
        let rightWristY = rightElbow.y - (forearmLength * sin(rightRad))
        let rightWrist = CGPoint(x: rightWristX, y: rightWristY)
        
        let nose = CGPoint(x: 0.50, y: 0.22)
        let leftHip = CGPoint(x: 0.44, y: 0.60)
        let rightHip = CGPoint(x: 0.56, y: 0.60)
        
        let joints: [Joint: JointObservation] = [
            .nose: JointObservation(point2D: nose, confidence: 0.96),
            .leftShoulder: JointObservation(point2D: leftShoulder, confidence: 0.96),
            .rightShoulder: JointObservation(point2D: rightShoulder, confidence: 0.96),
            .leftElbow: JointObservation(point2D: leftElbow, confidence: 0.96),
            .rightElbow: JointObservation(point2D: rightElbow, confidence: 0.96),
            .leftWrist: JointObservation(point2D: leftWrist, confidence: 0.96),
            .rightWrist: JointObservation(point2D: rightWrist, confidence: 0.96),
            .leftHip: JointObservation(point2D: leftHip, confidence: 0.96),
            .rightHip: JointObservation(point2D: rightHip, confidence: 0.96),
            .leftKnee: JointObservation(point2D: CGPoint(x: 0.44, y: 0.80), confidence: 0.96),
            .rightKnee: JointObservation(point2D: CGPoint(x: 0.56, y: 0.80), confidence: 0.96),
            .leftAnkle: JointObservation(point2D: CGPoint(x: 0.44, y: 0.96), confidence: 0.96),
            .rightAnkle: JointObservation(point2D: CGPoint(x: 0.56, y: 0.96), confidence: 0.96)
        ]
        
        return PoseFrame(
            timestamp: timestamp,
            joints: joints,
            confidence: 0.96,
            isInterpolated: false
        )
    }
}
