import Foundation

/// Mathematical calculation of Biceps Curl kinematic indicators
public struct BicepsCurlMetrics: Sendable {
    
    public static func computeMeanPeakROM(reps: [Repetition]) -> Double {
        guard !reps.isEmpty else { return 0.0 }
        let total = reps.reduce(0.0) { $0 + $1.primaryROM }
        return total / Double(reps.count)
    }
    
    public static func computeMeanShoulderDrift(reps: [Repetition]) -> Double {
        guard !reps.isEmpty else { return 0.0 }
        let total = reps.reduce(0.0) { $0 + ($1.secondaryROM ?? 0.0) }
        return total / Double(reps.count)
    }
    
    public static func computeMeanDuration(reps: [Repetition]) -> Double {
        guard !reps.isEmpty else { return 0.0 }
        let total = reps.reduce(0.0) { $0 + $1.duration }
        return total / Double(reps.count)
    }
    
    /// Computes percentage change in elbow flexion ROM from early to late reps
    public static func computeEarlyLateROMDelta(reps: [Repetition]) -> Double? {
        guard reps.count >= 4 else { return nil }
        
        let sampleSize = min(4, reps.count / 2)
        let earlyReps = reps.prefix(sampleSize)
        let lateReps = reps.suffix(sampleSize)
        
        let earlyMean = earlyReps.reduce(0.0) { $0 + $1.primaryROM } / Double(sampleSize)
        let lateMean = lateReps.reduce(0.0) { $0 + $1.primaryROM } / Double(sampleSize)
        
        // Lower angle = higher peak flexion (more ROM). ROM = (165° - peakAngle)
        let earlyActualROM = 165.0 - earlyMean
        let lateActualROM = 165.0 - lateMean
        
        guard earlyActualROM > 10.0 else { return 0.0 }
        return ((lateActualROM - earlyActualROM) / earlyActualROM) * 100.0
    }
    
    /// Computes change in shoulder drift from early to late reps (detecting fatigue swinging)
    public static func computeEarlyLateShoulderDriftDelta(reps: [Repetition]) -> Double? {
        guard reps.count >= 4 else { return nil }
        
        let sampleSize = min(4, reps.count / 2)
        let earlyMean = reps.prefix(sampleSize).reduce(0.0) { $0 + ($1.secondaryROM ?? 0.0) } / Double(sampleSize)
        let lateMean = reps.suffix(sampleSize).reduce(0.0) { $0 + ($1.secondaryROM ?? 0.0) } / Double(sampleSize)
        
        return lateMean - earlyMean // Positive if late reps have more shoulder drift
    }
    
    /// Heuristic ROM score [0 ... 100] based on peak contraction and lockout extension
    public static func computeROMScore(reps: [Repetition]) -> Double {
        guard !reps.isEmpty else { return 0.0 }
        let meanPeak = computeMeanPeakROM(reps: reps)
        
        // Strict full curl <= 60° = 95-100; standard 60°-75° = 85-95; shallow > 85° = < 75
        if meanPeak <= 60.0 {
            return 98.0
        } else if meanPeak <= 75.0 {
            return 92.0 - ((meanPeak - 60.0) * 0.8)
        } else if meanPeak <= 95.0 {
            return 80.0 - ((meanPeak - 75.0) * 1.2)
        } else {
            return max(50.0, 56.0 - ((meanPeak - 95.0) * 1.5))
        }
    }
    
    /// Consistency score [0 ... 100] based on standard deviation of peak flexion
    public static func computeConsistencyScore(reps: [Repetition]) -> Double {
        guard reps.count >= 2 else { return 85.0 }
        
        let mean = computeMeanPeakROM(reps: reps)
        let variance = reps.reduce(0.0) { $0 + pow($1.primaryROM - mean, 2) } / Double(reps.count)
        let stdDev = sqrt(variance)
        
        let score = 100.0 - (stdDev * 3.0)
        return min(max(score, 40.0), 100.0)
    }
    
    /// Tempo score [0 ... 100] penalizing dropping weights quickly on eccentric
    public static func computeTempoScore(reps: [Repetition]) -> Double {
        guard reps.count >= 2 else { return 80.0 }
        let meanDur = computeMeanDuration(reps: reps)
        let variance = reps.reduce(0.0) { $0 + pow($1.duration - meanDur, 2) } / Double(reps.count)
        let stdDev = sqrt(variance)
        
        let score = 95.0 - (stdDev * 15.0)
        return min(max(score, 45.0), 100.0)
    }
}
