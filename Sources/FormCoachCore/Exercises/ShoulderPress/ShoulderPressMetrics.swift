import Foundation

/// Mathematical calculation of Shoulder Press kinematic indicators
public struct ShoulderPressMetrics: Sendable {
    
    public static func computeMeanLockoutROM(reps: [Repetition]) -> Double {
        guard !reps.isEmpty else { return 0.0 }
        let total = reps.reduce(0.0) { $0 + $1.primaryROM }
        return total / Double(reps.count)
    }
    
    public static func computeMeanAsymmetry(reps: [Repetition]) -> Double {
        guard !reps.isEmpty else { return 0.0 }
        let total = reps.reduce(0.0) { $0 + ($1.secondaryROM ?? 0.0) }
        return total / Double(reps.count)
    }
    
    public static func computeMeanDuration(reps: [Repetition]) -> Double {
        guard !reps.isEmpty else { return 0.0 }
        let total = reps.reduce(0.0) { $0 + $1.duration }
        return total / Double(reps.count)
    }
    
    /// Computes percentage change in overhead lockout ROM from early to late reps
    public static func computeEarlyLateROMDelta(reps: [Repetition]) -> Double? {
        guard reps.count >= 4 else { return nil }
        
        let sampleSize = min(4, reps.count / 2)
        let earlyReps = reps.prefix(sampleSize)
        let lateReps = reps.suffix(sampleSize)
        
        let earlyMean = earlyReps.reduce(0.0) { $0 + $1.primaryROM } / Double(sampleSize)
        let lateMean = lateReps.reduce(0.0) { $0 + $1.primaryROM } / Double(sampleSize)
        
        // Lockout ROM = (lockoutAngle - 80° rack)
        let earlyActualROM = earlyMean - 80.0
        let lateActualROM = lateMean - 80.0
        
        guard earlyActualROM > 10.0 else { return 0.0 }
        return ((lateActualROM - earlyActualROM) / earlyActualROM) * 100.0
    }
    
    /// ROM score [0 ... 100] based on full overhead elbow extension (>= 165° = 95-100)
    public static func computeROMScore(reps: [Repetition]) -> Double {
        guard !reps.isEmpty else { return 0.0 }
        let meanLockout = computeMeanLockoutROM(reps: reps)
        
        if meanLockout >= 165.0 {
            return 98.0
        } else if meanLockout >= 155.0 {
            return 90.0 + ((meanLockout - 155.0) * 0.8)
        } else if meanLockout >= 140.0 {
            return 75.0 + ((meanLockout - 140.0) * 1.0)
        } else {
            return max(45.0, 50.0 + ((meanLockout - 120.0) * 1.25))
        }
    }
    
    /// Symmetry score [0 ... 100] based on bilateral arm angle delta (delta < 5° = 95-100)
    public static func computeSymmetryScore(reps: [Repetition]) -> Double {
        guard !reps.isEmpty else { return 90.0 }
        let meanAsymmetry = computeMeanAsymmetry(reps: reps)
        
        let score = 100.0 - (meanAsymmetry * 4.0)
        return min(max(score, 40.0), 100.0)
    }
    
    /// Consistency score [0 ... 100] based on variance across reps
    public static func computeConsistencyScore(reps: [Repetition]) -> Double {
        guard reps.count >= 2 else { return 85.0 }
        
        let mean = computeMeanLockoutROM(reps: reps)
        let variance = reps.reduce(0.0) { $0 + pow($1.primaryROM - mean, 2) } / Double(reps.count)
        let stdDev = sqrt(variance)
        
        let score = 100.0 - (stdDev * 3.5)
        return min(max(score, 40.0), 100.0)
    }
    
    /// Tempo score [0 ... 100]
    public static func computeTempoScore(reps: [Repetition]) -> Double {
        guard reps.count >= 2 else { return 80.0 }
        let meanDur = computeMeanDuration(reps: reps)
        let variance = reps.reduce(0.0) { $0 + pow($1.duration - meanDur, 2) } / Double(reps.count)
        let stdDev = sqrt(variance)
        
        let score = 95.0 - (stdDev * 15.0)
        return min(max(score, 45.0), 100.0)
    }
}
