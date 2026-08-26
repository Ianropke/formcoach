import Foundation

/// Mathematical engine for calculating individualized athlete baselines and historical trends
public struct PersonalBaselineEngine: Sendable {
    public static let minimumSessionsThreshold = 3
    public static let minimumRepsThreshold = 25
    
    /// Computes the athlete's current personal baseline for a specific exercise from historical sets
    public static func computeBaseline(
        sets: [ExerciseSetModel],
        exerciseType: ExerciseType
    ) -> PersonalBaseline {
        let matchingSets = sets.filter { $0.exerciseType == exerciseType && $0.trackingConfidence >= 0.70 }
        let totalReps = matchingSets.reduce(0) { $0 + $1.repCount }
        
        guard matchingSets.count >= minimumSessionsThreshold && totalReps >= minimumRepsThreshold else {
            let setsNeeded = max(0, minimumSessionsThreshold - matchingSets.count)
            return PersonalBaseline(
                exerciseType: exerciseType,
                sessionsCount: matchingSets.count,
                totalRepsLogged: totalReps,
                hasSufficientData: false,
                baselineROMMean: 0.0,
                baselineROMStdDev: 0.0,
                personalBestROM: 0.0,
                baselineDurationMean: 0.0,
                baselineConsistencyScore: 0.0,
                statusMessage: "Collecting baseline data (\(matchingSets.count)/\(minimumSessionsThreshold) sets logged). Complete \(setsNeeded) more sets to establish your personal norm."
            )
        }
        
        // Extract all completed rep metrics
        var allRoms: [Double] = []
        var allDurations: [Double] = []
        var consistencySum = 0.0
        
        for setModel in matchingSets {
            for rep in setModel.reps where rep.isComplete {
                allRoms.append(rep.primaryROM)
                allDurations.append(rep.duration)
            }
            if let quality = setModel.analysis?.consistencyScore {
                consistencySum += quality
            }
        }
        
        guard !allRoms.isEmpty else {
            return PersonalBaseline(
                exerciseType: exerciseType,
                sessionsCount: matchingSets.count,
                totalRepsLogged: totalReps,
                hasSufficientData: false,
                baselineROMMean: 0.0,
                baselineROMStdDev: 0.0,
                personalBestROM: 0.0,
                baselineDurationMean: 0.0,
                baselineConsistencyScore: 0.0,
                statusMessage: "Insufficient completed rep data."
            )
        }
        
        // 1. Mean ROM
        let meanROM = allRoms.reduce(0.0, +) / Double(allRoms.count)
        
        // 2. Standard Deviation of ROM
        let variance = allRoms.reduce(0.0) { $0 + pow($1 - meanROM, 2) } / Double(allRoms.count)
        let stdDev = sqrt(variance)
        
        // 3. Personal Best ROM (minimum knee angle for squat / minimum angle for curl)
        let bestROM = allRoms.min() ?? meanROM
        
        // 4. Mean Duration
        let meanDur = allDurations.reduce(0.0, +) / Double(allDurations.count)
        let meanConsistency = consistencySum / Double(matchingSets.count)
        
        let message = "Personal baseline established from \(matchingSets.count) sets (\(totalReps) reps). Normal depth: ~\(String(format: "%.0f°", meanROM)) ± \(String(format: "%.0f°", stdDev))."
        
        return PersonalBaseline(
            exerciseType: exerciseType,
            sessionsCount: matchingSets.count,
            totalRepsLogged: totalReps,
            hasSufficientData: true,
            baselineROMMean: meanROM,
            baselineROMStdDev: stdDev,
            personalBestROM: bestROM,
            baselineDurationMean: meanDur,
            baselineConsistencyScore: meanConsistency,
            statusMessage: message
        )
    }
    
    /// Compares a single set against the athlete's personal baseline
    public static func compareSet(
        setModel: ExerciseSetModel,
        baseline: PersonalBaseline
    ) -> BaselineComparisonResult {
        guard baseline.hasSufficientData else {
            return BaselineComparisonResult(
                isPersonalBest: false,
                zScoreROM: nil,
                deviationPercent: nil,
                insightText: baseline.statusMessage
            )
        }
        
        guard !setModel.reps.isEmpty else {
            return BaselineComparisonResult(
                isPersonalBest: false,
                zScoreROM: nil,
                deviationPercent: nil,
                insightText: "No completed reps in set."
            )
        }
        
        let setMeanROM = setModel.reps.reduce(0.0) { $0 + $1.primaryROM } / Double(setModel.reps.count)
        let setBestROM = setModel.reps.map { $0.primaryROM }.min() ?? setMeanROM
        
        let isPB = setBestROM < (baseline.personalBestROM - 1.5)
        
        let diff = setMeanROM - baseline.baselineROMMean
        let zScore = baseline.baselineROMStdDev > 0.5 ? (-diff / baseline.baselineROMStdDev) : 0.0
        
        let maxExpected = (setModel.exerciseType == .squat) ? 180.0 : 165.0
        let baselineActualROM = maxExpected - baseline.baselineROMMean
        let setActualROM = maxExpected - setMeanROM
        let devPercent = ((setActualROM - baselineActualROM) / baselineActualROM) * 100.0
        
        let insight: String
        if isPB {
            insight = "🏆 New Personal Best! Achieved \(String(format: "%.0f°", setBestROM)) depth (surpassing prior best of \(String(format: "%.0f°", baseline.personalBestROM)))."
        } else if zScore >= 1.5 {
            insight = "✨ Outstanding set! Depth was \(String(format: "%.0f%%", abs(devPercent))) above your historical baseline average."
        } else if zScore <= -1.8 {
            insight = "⚠️ Below normal baseline: Depth was ~\(String(format: "%.0f%%", abs(devPercent))) shallower than your typical \(String(format: "%.0f°", baseline.baselineROMMean)) standard."
        } else {
            insight = "✓ Consistent with your personal baseline (\(String(format: "%.0f°", setMeanROM)) vs historical \(String(format: "%.0f°", baseline.baselineROMMean))). "
        }
        
        return BaselineComparisonResult(
            isPersonalBest: isPB,
            zScoreROM: zScore,
            deviationPercent: devPercent,
            insightText: insight
        )
    }
}
