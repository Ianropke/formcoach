import Foundation
import CoreGraphics

/// Deterministic 5-state hysteresis state machine for Squat repetition segmentation
public struct SquatRepSegmenter: RepSegmenterProtocol, Sendable {
    
    public enum State: Sendable {
        case standing
        case descending(startTime: TimeInterval, minAngle: Double, minTime: TimeInterval)
        case bottom(startTime: TimeInterval, inflectionTime: TimeInterval, minAngle: Double)
        case ascending(startTime: TimeInterval, inflectionTime: TimeInterval, minAngle: Double)
    }
    
    public init() {}
    
    public func segment(
        timeSeries: PoseTimeSeries,
        view: CameraViewType
    ) -> [Repetition] {
        guard timeSeries.count >= 10 else { return [] }
        
        var reps: [Repetition] = []
        var state: State = .standing
        var repIndexCounter = 1
        
        let frames = timeSeries.frames
        
        for i in 0..<frames.count {
            let frame = frames[i]
            let timestamp = frame.timestamp
            
            // Extract knee angle
            guard let kneeAngle = extractKneeAngle(from: frame) else {
                continue
            }
            
            switch state {
            case .standing:
                // Trigger descent if knee angle drops below 145°
                if kneeAngle < 145.0 {
                    state = .descending(startTime: timestamp, minAngle: kneeAngle, minTime: timestamp)
                }
                
            case .descending(let startTime, let minAngle, let minTime):
                let currentMin = min(minAngle, kneeAngle)
                let currentMinTime = (kneeAngle <= minAngle) ? timestamp : minTime
                
                let nextAngle = (i + 1 < frames.count) ? extractKneeAngle(from: frames[i + 1]) : nil
                
                // If angle starts rising by > 2.0° from local minimum, inflection has occurred
                if let next = nextAngle, next > currentMin + 2.0 {
                    state = .bottom(startTime: startTime, inflectionTime: currentMinTime, minAngle: currentMin)
                } else if kneeAngle > currentMin + 3.0 {
                    state = .bottom(startTime: startTime, inflectionTime: currentMinTime, minAngle: currentMin)
                } else if kneeAngle > 155.0 && (timestamp - startTime) < 0.5 {
                    // False trigger / noise, reset to standing
                    state = .standing
                } else {
                    state = .descending(startTime: startTime, minAngle: currentMin, minTime: currentMinTime)
                }
                
            case .bottom(let startTime, let inflectionTime, let minAngle):
                let currentMin = min(minAngle, kneeAngle)
                let currentMinTime = (kneeAngle < minAngle) ? timestamp : inflectionTime
                
                // Transition to ascending when angle rises significantly above bottom (>= +10°)
                if kneeAngle > (currentMin + 10.0) {
                    state = .ascending(startTime: startTime, inflectionTime: currentMinTime, minAngle: currentMin)
                } else {
                    state = .bottom(startTime: startTime, inflectionTime: currentMinTime, minAngle: currentMin)
                }
                
            case .ascending(let startTime, let inflectionTime, let minAngle):
                // Recover to standing lockout
                if kneeAngle >= 160.0 {
                    let totalDuration = timestamp - startTime
                    let romDelta = 175.0 - minAngle // Standing vs bottom delta
                    
                    // Invariants: duration >= 0.8s and romDelta >= 35°
                    if totalDuration >= 0.8 && romDelta >= 35.0 {
                        let eccentric = inflectionTime - startTime
                        let concentric = timestamp - inflectionTime
                        let pause = max(0.0, totalDuration - (eccentric + concentric))
                        
                        // Extract torso angle at bottom
                        let bottomFrame = timeSeries.frame(at: inflectionTime) ?? frame
                        let torso = extractTorsoAngle(from: bottomFrame)
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
                            secondaryROM: extractHipAngle(from: bottomFrame),
                            torsoAngleMean: torso,
                            confidence: repConfidence,
                            isComplete: true
                        )
                        
                        reps.append(rep)
                        repIndexCounter += 1
                    }
                    
                    state = .standing
                }
            }
        }
        
        return reps
    }
    
    /// Extracts knee angle from either dominant or available leg
    private func extractKneeAngle(from frame: PoseFrame) -> Double? {
        let leftHip = frame.joints[.leftHip]
        let leftKnee = frame.joints[.leftKnee]
        let leftAnkle = frame.joints[.leftAnkle]
        
        let rightHip = frame.joints[.rightHip]
        let rightKnee = frame.joints[.rightKnee]
        let rightAnkle = frame.joints[.rightAnkle]
        
        let leftValid = (leftHip?.isTracked ?? false) && (leftKnee?.isTracked ?? false) && (leftAnkle?.isTracked ?? false)
        let rightValid = (rightHip?.isTracked ?? false) && (rightKnee?.isTracked ?? false) && (rightAnkle?.isTracked ?? false)
        
        if leftValid && rightValid {
            let leftAngle = AngleCalculator.angle2D(pointA: leftHip!.point2D, vertexB: leftKnee!.point2D, pointC: leftAnkle!.point2D)
            let rightAngle = AngleCalculator.angle2D(pointA: rightHip!.point2D, vertexB: rightKnee!.point2D, pointC: rightAnkle!.point2D)
            return (leftAngle + rightAngle) / 2.0
        } else if leftValid {
            return AngleCalculator.angle2D(pointA: leftHip!.point2D, vertexB: leftKnee!.point2D, pointC: leftAnkle!.point2D)
        } else if rightValid {
            return AngleCalculator.angle2D(pointA: rightHip!.point2D, vertexB: rightKnee!.point2D, pointC: rightAnkle!.point2D)
        }
        
        return nil
    }
    
    private func extractTorsoAngle(from frame: PoseFrame) -> Double? {
        let shoulder = frame.joints[.leftShoulder]?.point2D ?? frame.joints[.rightShoulder]?.point2D
        let hip = frame.joints[.leftHip]?.point2D ?? frame.joints[.rightHip]?.point2D
        
        guard let s = shoulder, let h = hip else { return nil }
        return AngleCalculator.angleRelativeToVertical(top: s, bottom: h)
    }
    
    private func extractHipAngle(from frame: PoseFrame) -> Double? {
        let shoulder = frame.joints[.leftShoulder]?.point2D ?? frame.joints[.rightShoulder]?.point2D
        let hip = frame.joints[.leftHip]?.point2D ?? frame.joints[.rightHip]?.point2D
        let knee = frame.joints[.leftKnee]?.point2D ?? frame.joints[.rightKnee]?.point2D
        
        guard let s = shoulder, let h = hip, let k = knee else { return nil }
        return AngleCalculator.angle2D(pointA: s, vertexB: h, pointC: k)
    }
}
