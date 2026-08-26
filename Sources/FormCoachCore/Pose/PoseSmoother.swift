import Foundation
import CoreGraphics

/// Smoother for pose landmark time-series that interpolates micro-gaps and dampens high-frequency jitter
public struct PoseSmoother: Sendable {
    public let alpha: Double // Smoothing factor [0.0 = max smooth, 1.0 = raw]
    public let maxInterpolationGap: Int // Maximum number of dropped frames to linearly interpolate
    
    public init(alpha: Double = 0.65, maxInterpolationGap: Int = 3) {
        self.alpha = min(max(alpha, 0.1), 1.0)
        self.maxInterpolationGap = maxInterpolationGap
    }
    
    /// Smoothes an entire time-series of PoseFrames
    public func smooth(frames: [PoseFrame]) -> [PoseFrame] {
        guard frames.count > 1 else { return frames }
        
        // 1. Interpolate short missing gaps per joint
        let interpolated = interpolateGaps(in: frames)
        
        // 2. Apply forward Exponential Moving Average
        var smoothedFrames: [PoseFrame] = []
        smoothedFrames.reserveCapacity(interpolated.count)
        
        var previousFrame: PoseFrame?
        
        for frame in interpolated {
            guard let prev = previousFrame else {
                smoothedFrames.append(frame)
                previousFrame = frame
                continue
            }
            
            var smoothedJoints: [Joint: JointObservation] = [:]
            
            for (joint, currentObs) in frame.joints {
                if let prevObs = prev.joints[joint], prevObs.isTracked && currentObs.isTracked {
                    let smoothX = (alpha * currentObs.x) + ((1.0 - alpha) * prevObs.x)
                    let smoothY = (alpha * currentObs.y) + ((1.0 - alpha) * prevObs.y)
                    let smoothZ: Double?
                    if let curZ = currentObs.depthZ, let pZ = prevObs.depthZ {
                        smoothZ = (alpha * curZ) + ((1.0 - alpha) * pZ)
                    } else {
                        smoothZ = currentObs.depthZ ?? prevObs.depthZ
                    }
                    
                    smoothedJoints[joint] = JointObservation(
                        point2D: CGPoint(x: smoothX, y: smoothY),
                        depthZ: smoothZ,
                        confidence: currentObs.confidence
                    )
                } else {
                    smoothedJoints[joint] = currentObs
                }
            }
            
            let smoothedFrame = PoseFrame(
                timestamp: frame.timestamp,
                joints: smoothedJoints,
                confidence: frame.confidence,
                isInterpolated: frame.isInterpolated
            )
            
            smoothedFrames.append(smoothedFrame)
            previousFrame = smoothedFrame
        }
        
        return smoothedFrames
    }
    
    /// Linearly interpolates micro-gaps where a joint temporarily dropped for <= maxInterpolationGap frames
    private func interpolateGaps(in frames: [PoseFrame]) -> [PoseFrame] {
        var result = frames
        let count = frames.count
        
        for joint in Joint.allCases {
            var gapStartIdx: Int?
            
            for i in 0..<count {
                let isTracked = frames[i].observation(for: joint)?.isTracked ?? false
                
                if !isTracked {
                    if gapStartIdx == nil {
                        gapStartIdx = i
                    }
                } else {
                    if let start = gapStartIdx {
                        let gapLength = i - start
                        if gapLength <= maxInterpolationGap && start > 0 {
                            // Interpolate between (start - 1) and i
                            if let beforeObs = result[start - 1].observation(for: joint),
                               let afterObs = frames[i].observation(for: joint) {
                                
                                for k in 0..<gapLength {
                                    let idx = start + k
                                    let t = Double(k + 1) / Double(gapLength + 1)
                                    let interpX = beforeObs.x + t * (afterObs.x - beforeObs.x)
                                    let interpY = beforeObs.y + t * (afterObs.y - beforeObs.y)
                                    let interpConf = min(beforeObs.confidence, afterObs.confidence) * 0.8
                                    
                                    var updatedJoints = result[idx].joints
                                    updatedJoints[joint] = JointObservation(
                                        point2D: CGPoint(x: interpX, y: interpY),
                                        depthZ: nil,
                                        confidence: interpConf
                                    )
                                    
                                    result[idx] = PoseFrame(
                                        timestamp: result[idx].timestamp,
                                        joints: updatedJoints,
                                        confidence: result[idx].confidence,
                                        isInterpolated: true
                                    )
                                }
                            }
                        }
                        gapStartIdx = nil
                    }
                }
            }
        }
        
        return result
    }
}
