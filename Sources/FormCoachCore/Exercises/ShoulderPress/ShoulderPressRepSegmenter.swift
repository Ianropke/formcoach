import Foundation
import CoreGraphics

/// Deterministic 5-state hysteresis state machine for Overhead Shoulder Press repetition segmentation
public struct ShoulderPressRepSegmenter: RepSegmenterProtocol, Sendable {
    
    public enum State: Sendable {
        case rackPosition
        case pressing(startTime: TimeInterval, maxAngle: Double, maxTime: TimeInterval)
        case overheadLockout(startTime: TimeInterval, inflectionTime: TimeInterval, maxAngle: Double)
        case lowering(startTime: TimeInterval, inflectionTime: TimeInterval, maxAngle: Double)
    }
    
    public init() {}
    
    public func segment(
        timeSeries: PoseTimeSeries,
        view: CameraViewType
    ) -> [Repetition] {
        guard timeSeries.count >= 10 else { return [] }
        
        var reps: [Repetition] = []
        var state: State = .rackPosition
        var repIndexCounter = 1
        
        let frames = timeSeries.frames
        
        for i in 0..<frames.count {
            let frame = frames[i]
            let timestamp = frame.timestamp
            
            guard let elbowAngle = extractElbowAngle(from: frame) else {
                continue
            }
            
            switch state {
            case .rackPosition:
                // Trigger concentric press if elbow angle expands above 95°
                if elbowAngle > 95.0 {
                    state = .pressing(startTime: timestamp, maxAngle: elbowAngle, maxTime: timestamp)
                }
                
            case .pressing(let startTime, let maxAngle, let maxTime):
                let currentMax = max(maxAngle, elbowAngle)
                let currentMaxTime = (elbowAngle >= maxAngle) ? timestamp : maxTime
                
                let nextAngle = (i + 1 < frames.count) ? extractElbowAngle(from: frames[i + 1]) : nil
                
                // If angle starts falling by > 2.0° from local maximum, overhead lockout inflection occurred
                if let next = nextAngle, next < currentMax - 2.0 {
                    state = .overheadLockout(startTime: startTime, inflectionTime: currentMaxTime, maxAngle: currentMax)
                } else if elbowAngle < currentMax - 3.0 {
                    state = .overheadLockout(startTime: startTime, inflectionTime: currentMaxTime, maxAngle: currentMax)
                } else if elbowAngle < 85.0 && (timestamp - startTime) < 0.4 {
                    // False twitch / noise, reset to rack
                    state = .rackPosition
                } else {
                    state = .pressing(startTime: startTime, maxAngle: currentMax, maxTime: currentMaxTime)
                }
                
            case .overheadLockout(let startTime, let inflectionTime, let maxAngle):
                let currentMax = max(maxAngle, elbowAngle)
                let currentMaxTime = (elbowAngle > maxAngle) ? timestamp : inflectionTime
                
                // Transition to lowering when angle drops below lockout (<= max - 8°)
                if elbowAngle < (currentMax - 8.0) {
                    state = .lowering(startTime: startTime, inflectionTime: currentMaxTime, maxAngle: currentMax)
                } else {
                    state = .overheadLockout(startTime: startTime, inflectionTime: currentMaxTime, maxAngle: currentMax)
                }
                
            case .lowering(let startTime, let inflectionTime, let maxAngle):
                // Lower back to collarbone / rack position (<= 95°)
                if elbowAngle <= 95.0 {
                    let totalDuration = timestamp - startTime
                    let romDelta = maxAngle - 80.0
                    
                    // Invariants: duration >= 0.8s and romDelta >= 40°
                    if totalDuration >= 0.8 && romDelta >= 40.0 {
                        let concentric = inflectionTime - startTime
                        let eccentric = timestamp - inflectionTime
                        let pause = max(0.0, totalDuration - (concentric + eccentric))
                        
                        let peakFrame = timeSeries.frame(at: inflectionTime) ?? frame
                        let asymmetry = extractBilateralAsymmetry(from: peakFrame)
                        let repConfidence = frame.confidence
                        
                        let rep = Repetition(
                            index: repIndexCounter,
                            startTime: startTime,
                            inflectionTime: inflectionTime,
                            endTime: timestamp,
                            eccentricDuration: max(eccentric, 0.2),
                            pauseDuration: pause,
                            concentricDuration: max(concentric, 0.2),
                            primaryROM: maxAngle, // Overhead lockout angle
                            secondaryROM: asymmetry, // Bilateral arm angle delta
                            torsoAngleMean: extractTorsoIncline(from: peakFrame),
                            confidence: repConfidence,
                            isComplete: true
                        )
                        
                        reps.append(rep)
                        repIndexCounter += 1
                    }
                    
                    state = .rackPosition
                }
            }
        }
        
        return reps
    }
    
    private func extractElbowAngle(from frame: PoseFrame) -> Double? {
        let leftShoulder = frame.joints[.leftShoulder]
        let leftElbow = frame.joints[.leftElbow]
        let leftWrist = frame.joints[.leftWrist]
        
        let rightShoulder = frame.joints[.rightShoulder]
        let rightElbow = frame.joints[.rightElbow]
        let rightWrist = frame.joints[.rightWrist]
        
        let leftValid = (leftShoulder?.isTracked ?? false) && (leftElbow?.isTracked ?? false) && (leftWrist?.isTracked ?? false)
        let rightValid = (rightShoulder?.isTracked ?? false) && (rightElbow?.isTracked ?? false) && (rightWrist?.isTracked ?? false)
        
        if leftValid && rightValid {
            let leftAngle = AngleCalculator.angle2D(pointA: leftShoulder!.point2D, vertexB: leftElbow!.point2D, pointC: leftWrist!.point2D)
            let rightAngle = AngleCalculator.angle2D(pointA: rightShoulder!.point2D, vertexB: rightElbow!.point2D, pointC: rightWrist!.point2D)
            return (leftAngle + rightAngle) / 2.0
        } else if leftValid {
            return AngleCalculator.angle2D(pointA: leftShoulder!.point2D, vertexB: leftElbow!.point2D, pointC: leftWrist!.point2D)
        } else if rightValid {
            return AngleCalculator.angle2D(pointA: rightShoulder!.point2D, vertexB: rightElbow!.point2D, pointC: rightWrist!.point2D)
        }
        
        return nil
    }
    
    /// Bilateral symmetry delta between left and right arm angles at lockout (in degrees)
    private func extractBilateralAsymmetry(from frame: PoseFrame) -> Double? {
        let leftShoulder = frame.joints[.leftShoulder]
        let leftElbow = frame.joints[.leftElbow]
        let leftWrist = frame.joints[.leftWrist]
        
        let rightShoulder = frame.joints[.rightShoulder]
        let rightElbow = frame.joints[.rightElbow]
        let rightWrist = frame.joints[.rightWrist]
        
        guard let ls = leftShoulder, let le = leftElbow, let lw = leftWrist,
              let rs = rightShoulder, let re = rightElbow, let rw = rightWrist,
              ls.isTracked, le.isTracked, lw.isTracked,
              rs.isTracked, re.isTracked, rw.isTracked else {
            return nil
        }
        
        let leftAngle = AngleCalculator.angle2D(pointA: ls.point2D, vertexB: le.point2D, pointC: lw.point2D)
        let rightAngle = AngleCalculator.angle2D(pointA: rs.point2D, vertexB: re.point2D, pointC: rw.point2D)
        
        return abs(leftAngle - rightAngle)
    }
    
    private func extractTorsoIncline(from frame: PoseFrame) -> Double? {
        let shoulder = frame.joints[.leftShoulder]?.point2D ?? frame.joints[.rightShoulder]?.point2D
        let hip = frame.joints[.leftHip]?.point2D ?? frame.joints[.rightHip]?.point2D
        
        guard let s = shoulder, let h = hip else { return nil }
        return AngleCalculator.angleRelativeToVertical(top: s, bottom: h)
    }
}
