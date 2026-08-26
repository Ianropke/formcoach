import Foundation

/// Mathematical calculation of Squat kinematic indicators
public struct SquatMetrics: Sendable {
    
    public static func computeMeanROM(reps: [Repetition]) -> Double {
        guard !reps.isEmpty else { return 0.0 }
        let total = reps.reduce(0.0) { $0 + $1.primaryROM }
        return total / Double(reps.count)
    }
    
    public static func computeMeanDuration(reps: [Repetition]) -> Double {
        guard !reps.isEmpty else { return 0.0 }
        let total = reps.reduce(0.0) { $0 + $1.duration }
        return total / Double(reps.count)
    }
    
    /// Computes percentage change in ROM from early reps to late reps.
    /// Returns negative value if ROM decreased (shallower knee flexion).
    public static func computeEarlyLateROMDelta(reps: [Repetition]) -> Double? {
        guard reps.count >= 4 else { return nil }
        
        let sampleSize = min(4, reps.count / 2)
        let earlyReps = reps.prefix(sampleSize)
        let lateReps = reps.suffix(sampleSize)
        
        let earlyMean = earlyReps.reduce(0.0) { $0 + $1.primaryROM } / Double(sampleSize)
        let lateMean = lateReps.reduce(0.0) { $0 + $1.primaryROM } / Double(sampleSize)
        
        // Note: For squat, higher knee angle = shallower depth (less ROM).
        // Actual ROM = (180° - kneeAngle)
        let earlyActualROM = 180.0 - earlyMean
        let lateActualROM = 180.0 - lateMean
        
        guard earlyActualROM > 10.0 else { return 0.0 }
        return ((lateActualROM - earlyActualROM) / earlyActualROM) * 100.0
    }
    
    /// Computes percentage change in repetition tempo from early reps to late reps
    public static func computeEarlyLateTempoDelta(reps: [Repetition]) -> Double? {
        guard reps.count >= 4 else { return nil }
        
        let sampleSize = min(4, reps.count / 2)
        let earlyMean = reps.prefix(sampleSize).reduce(0.0) { $0 + $1.duration } / Double(sampleSize)
        let lateMean = reps.suffix(sampleSize).reduce(0.0) { $0 + $1.duration } / Double(sampleSize)
        
        guard earlyMean > 0.1 else { return 0.0 }
        return ((lateMean - earlyMean) / earlyMean) * 100.0
    }
    
    /// Heuristic consistency score [0 ... 100] based on standard deviation of ROM
    public static func computeConsistencyScore(reps: [Repetition]) -> Double {
        guard reps.count >= 2 else { return 85.0 }
        
        let mean = computeMeanROM(reps: reps)
        let variance = reps.reduce(0.0) { $0 + pow($1.primaryROM - mean, 2) } / Double(reps.count)
        let stdDev = sqrt(variance)
        
        // StdDev of 0° = 100 score; StdDev of 15°+ = ~60 score
        let score = 100.0 - (stdDev * 2.5)
        return min(max(score, 40.0), 100.0)
    }
    
    /// Heuristic ROM score [0 ... 100] based on average depth
    public static func computeROMScore(reps: [Repetition]) -> Double {
        guard !reps.isEmpty else { return 0.0 }
        let meanKnee = computeMeanROM(reps: reps)
        
        // Deep squat <= 90° = 95-100; Parallel 90°-105° = 85-95; Shallow > 115° = < 75
        if meanKnee <= 90.0 {
            return 98.0
        } else if meanKnee <= 105.0 {
            return 90.0 - ((meanKnee - 90.0) * 0.8)
        } else if meanKnee <= 125.0 {
            return 78.0 - ((meanKnee - 105.0) * 1.2)
        } else {
            return max(50.0, 54.0 - ((meanKnee - 125.0) * 1.5))
        }
    }
    
    /// Heuristic tempo score [0 ... 100] based on eccentric control and duration consistency
    public static func computeTempoScore(reps: [Repetition]) -> Double {
        guard reps.count >= 2 else { return 80.0 }
        let meanDur = computeMeanDuration(reps: reps)
        let variance = reps.reduce(0.0) { $0 + pow($1.duration - meanDur, 2) } / Double(reps.count)
        let stdDev = sqrt(variance)
        
        // Penalize erratic speed fluctuations
        let score = 95.0 - (stdDev * 15.0)
        return min(max(score, 45.0), 100.0)
    }
}
