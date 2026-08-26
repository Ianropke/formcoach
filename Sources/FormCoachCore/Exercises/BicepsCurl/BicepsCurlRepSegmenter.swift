import Foundation
import CoreGraphics

/// Deterministic 5-state hysteresis state machine for Biceps Curl repetition segmentation
public struct BicepsCurlRepSegmenter: RepSegmenterProtocol, Sendable {
    
    public enum State: Sendable {
        case extended
        case flexing(startTime: TimeInterval, minAngle: Double, minTime: TimeInterval)
        case peakContraction(startTime: TimeInterval, inflectionTime: TimeInterval, minAngle: Double)
        case extending(startTime: TimeInterval, inflectionTime: TimeInterval, minAngle: Double)
    }
    
    public init() {}
    
    public func segment(
        timeSeries: PoseTimeSeries,
        view: CameraViewType
    ) -> [Repetition] {
        guard timeSeries.count >= 10 else { return [] }
        
        var reps: [Repetition] = []
        var state: State = .extended
        var repIndexCounter = 1
        
        let frames = timeSeries.frames
        
        for i in 0..<frames.count {
            let frame = frames[i]
            let timestamp = frame.timestamp
            
            // Extract dominant or average elbow angle
            guard let elbowAngle = extractElbowAngle(from: frame) else {
                continue
            }
            
            switch state {
            case .extended:
                // Trigger concentric curl if elbow angle drops below 140°
                if elbowAngle < 140.0 {
                    state = .flexing(startTime: timestamp, minAngle: elbowAngle, minTime: timestamp)
                }
                
            case .flexing(let startTime, let minAngle, let minTime):
                let currentMin = min(minAngle, elbowAngle)
                let currentMinTime = (elbowAngle <= minAngle) ? timestamp : minTime
                
                let nextAngle = (i + 1 < frames.count) ? extractElbowAngle(from: frames[i + 1]) : nil
                
                // If angle starts rising by > 2.5° from local minimum, peak contraction has occurred
                if let next = nextAngle, next > currentMin + 2.5 {
                    state = .peakContraction(startTime: startTime, inflectionTime: currentMinTime, minAngle: currentMin)
                } else if elbowAngle > currentMin + 3.5 {
                    state = .peakContraction(startTime: startTime, inflectionTime: currentMinTime, minAngle: currentMin)
                } else if elbowAngle > 150.0 && (timestamp - startTime) < 0.4 {
                    // False twitch / noise, reset to extended
                    state = .extended
                } else {
                    state = .flexing(startTime: startTime, minAngle: currentMin, minTime: currentMinTime)
                }
                
            case .peakContraction(let startTime, let inflectionTime, let minAngle):
                let currentMin = min(minAngle, elbowAngle)
                let currentMinTime = (elbowAngle < minAngle) ? timestamp : inflectionTime
                
                // Transition to extending when angle rises significantly above peak (>= +10°)
                if elbowAngle > (currentMin + 10.0) {
                    state = .extending(startTime: startTime, inflectionTime: currentMinTime, minAngle: currentMin)
                } else {
                    state = .peakContraction(startTime: startTime, inflectionTime: currentMinTime, minAngle: currentMin)
                }
                
            case .extending(let startTime, let inflectionTime, let minAngle):
                // Lower back to full extension lockout (>= 145°)
                if elbowAngle >= 145.0 {
                    let totalDuration = timestamp - startTime
                    let romDelta = 165.0 - minAngle // Standing extension vs peak delta
                    
                    // Invariants: duration >= 0.8s and romDelta >= 45°
                    if totalDuration >= 0.8 && romDelta >= 45.0 {
                        let concentric = inflectionTime - startTime
                        let eccentric = timestamp - inflectionTime
                        let pause = max(0.0, totalDuration - (concentric + eccentric))
                        
                        // Extract shoulder drift (upper-arm deviation) at peak
                        let peakFrame = timeSeries.frame(at: inflectionTime) ?? frame
                        let shoulderDrift = extractShoulderDriftAngle(from: peakFrame)
                        let repConfidence = frame.confidence
                        
                        let rep = Repetition(
                            index: repIndexCounter,
                            startTime: startTime,
                            inflectionTime: inflectionTime,
                            endTime: timestamp,
                            eccentricDuration: max(eccentric, 0.2),
                            pauseDuration: pause,
                            concentricDuration: max(concentric, 0.2),
                            primaryROM: minAngle,
                            secondaryROM: shoulderDrift,
                            torsoAngleMean: extractTorsoIncline(from: peakFrame),
                            confidence: repConfidence,
                            isComplete: true
                        )
                        
                        reps.append(rep)
                        repIndexCounter += 1
                    }
                    
                    state = .extended
                }
            }
        }
        
        return reps
    }
    
    /// Extracts elbow angle (Shoulder -> Elbow -> Wrist)
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
    
    /// Measures shoulder drift / momentum cheating: angle between upper arm (Shoulder -> Elbow) and vertical torso (Hip -> Shoulder)
    private func extractShoulderDriftAngle(from frame: PoseFrame) -> Double? {
        let shoulder = frame.joints[.leftShoulder]?.point2D ?? frame.joints[.rightShoulder]?.point2D
        let elbow = frame.joints[.leftElbow]?.point2D ?? frame.joints[.rightElbow]?.point2D
        let hip = frame.joints[.leftHip]?.point2D ?? frame.joints[.rightHip]?.point2D
        
        guard let s = shoulder, let e = elbow, let h = hip else { return nil }
        
        // Angle at shoulder vertex: Hip -> Shoulder -> Elbow
        // Since hip is directly below shoulder and elbow hangs down, angle is directly the deviation from vertical
        let armAngle = AngleCalculator.angle2D(pointA: h, vertexB: s, pointC: e)
        return armAngle
    }
    
    private func extractTorsoIncline(from frame: PoseFrame) -> Double? {
        let shoulder = frame.joints[.leftShoulder]?.point2D ?? frame.joints[.rightShoulder]?.point2D
        let hip = frame.joints[.leftHip]?.point2D ?? frame.joints[.rightHip]?.point2D
        
        guard let s = shoulder, let h = hip else { return nil }
        return AngleCalculator.angleRelativeToVertical(top: s, bottom: h)
    }
}
