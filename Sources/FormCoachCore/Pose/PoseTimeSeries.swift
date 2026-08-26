import Foundation

/// Continuous collection of timestamped pose observations for an entire workout set
public struct PoseTimeSeries: Codable, Sendable {
    public let frames: [PoseFrame]
    public let fps: Double
    
    public init(frames: [PoseFrame], fps: Double = 30.0) {
        self.frames = frames.sorted(by: { $0.timestamp < $1.timestamp })
        self.fps = fps
    }
    
    public var duration: TimeInterval {
        guard let first = frames.first, let last = frames.last else { return 0 }
        return last.timestamp - first.timestamp
    }
    
    public var count: Int {
        frames.count
    }
    
    public var isEmpty: Bool {
        frames.isEmpty
    }
    
    /// Finds the closest frame to the specified timestamp using binary search
    public func frame(at timestamp: TimeInterval) -> PoseFrame? {
        guard !frames.isEmpty else { return nil }
        
        var low = 0
        var high = frames.count - 1
        
        while low <= high {
            let mid = (low + high) / 2
            let midTime = frames[mid].timestamp
            
            if abs(midTime - timestamp) < (0.5 / fps) {
                return frames[mid]
            }
            
            if midTime < timestamp {
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        
        let clampedIdx = min(max(low, 0), frames.count - 1)
        return frames[clampedIdx]
    }
    
    /// Extracts a sub-series within the given time window
    public func slice(from startTime: TimeInterval, to endTime: TimeInterval) -> PoseTimeSeries {
        let slicedFrames = frames.filter { $0.timestamp >= startTime && $0.timestamp <= endTime }
        return PoseTimeSeries(frames: slicedFrames, fps: fps)
    }
}
