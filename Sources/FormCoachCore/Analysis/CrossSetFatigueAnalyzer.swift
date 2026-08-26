import Foundation

/// Analyzes cross-set fatigue trajectories and trends across multiple sets in a workout session
public struct CrossSetFatigueAnalyzer: Sendable {
    
    public static func analyzeSession(
        sets: [ExerciseSetModel],
        exerciseType: ExerciseType
    ) -> WorkoutSessionAnalysis {
        guard !sets.isEmpty else {
            return WorkoutSessionAnalysis(
                exerciseType: exerciseType,
                totalSets: 0,
                totalReps: 0,
                averageQualityScore: 0.0,
                averageROM: 0.0,
                romTrend: .stable,
                romDecayPercent: nil,
                tempoSlowdownPercent: nil,
                fatigueIndex: 0.0,
                setTrends: [],
                sessionObservations: []
            )
        }
        
        // 1. Build SetTrendDataPoints
        var trendPoints: [SetTrendDataPoint] = []
        var totalRepsCount = 0
        var qualitySum = 0.0
        var romSum = 0.0
        
        for (idx, setModel) in sets.enumerated() {
            let setNumber = idx + 1
            let repCount = setModel.repCount
            totalRepsCount += repCount
            
            let meanROM: Double
            let meanDuration: Double
            if !setModel.reps.isEmpty {
                meanROM = setModel.reps.reduce(0.0) { $0 + $1.primaryROM } / Double(setModel.reps.count)
                meanDuration = setModel.reps.reduce(0.0) { $0 + $1.duration } / Double(setModel.reps.count)
            } else {
                meanROM = 0.0
                meanDuration = 0.0
            }
            
            let quality = setModel.analysis?.overallQualityScore ?? 80.0
            let consistency = setModel.analysis?.consistencyScore ?? 80.0
            
            qualitySum += quality
            romSum += meanROM
            
            trendPoints.append(SetTrendDataPoint(
                setId: setModel.id,
                setNumber: setNumber,
                repCount: repCount,
                meanROM: meanROM,
                meanDuration: meanDuration,
                qualityScore: quality,
                consistencyScore: consistency,
                trackingConfidence: setModel.trackingConfidence
            ))
        }
        
        let avgQuality = qualitySum / Double(sets.count)
        let avgROM = romSum / Double(sets.count)
        
        // 2. Cross-Set Fatigue Metrics (comparing first set vs last set if >= 2 sets)
        var romDecay: Double? = nil
        var tempoSlowdown: Double? = nil
        var trend: TrendDirection = .stable
        var fatigueIndex: Double = 10.0
        var observations: [FormObservation] = []
        
        if sets.count >= 2, let firstSet = trendPoints.first, let lastSet = trendPoints.last {
            // For squat: higher knee angle = shallower depth (less ROM).
            // For curl: higher angle = less flexion (less ROM).
            let maxExpectedAngle = (exerciseType == .squat) ? 180.0 : 165.0
            let firstActualROM = maxExpectedAngle - firstSet.meanROM
            let lastActualROM = maxExpectedAngle - lastSet.meanROM
            
            if firstActualROM > 10.0 {
                let delta = ((lastActualROM - firstActualROM) / firstActualROM) * 100.0
                romDecay = delta
                
                if delta <= -12.0 {
                    trend = .degrading
                    fatigueIndex += min(45.0, abs(delta) * 1.5)
                } else if delta >= 6.0 {
                    trend = .improving
                }
            }
            
            if firstSet.meanDuration > 0.5 {
                let tempoDelta = ((lastSet.meanDuration - firstSet.meanDuration) / firstSet.meanDuration) * 100.0
                tempoSlowdown = tempoDelta
                if tempoDelta >= 15.0 {
                    fatigueIndex += min(35.0, tempoDelta * 1.0)
                }
            }
            
            // Generate explainable session observations
            if let decay = romDecay, decay <= -10.0 {
                let percentStr = String(format: "%.0f%%", abs(decay))
                observations.append(FormObservation(
                    id: "session.cross_set.rom_decay",
                    title: "Cross-Set Depth Deterioration",
                    detail: "Range of motion decreased by ~\(percentStr) from Set 1 (\(String(format: "%.0f°", firstSet.meanROM))) to Set \(lastSet.setNumber) (\(String(format: "%.0f°", lastSet.meanROM))).",
                    evidence: "Progression across \(sets.count) sets shows accumulated fatigue limiting full depth in closing sets.",
                    severity: .warning,
                    affectedRepIndices: []
                ))
            }
            
            if let slowdown = tempoSlowdown, slowdown >= 18.0 {
                let percentStr = String(format: "%.0f%%", abs(slowdown))
                observations.append(FormObservation(
                    id: "session.cross_set.tempo_slowdown",
                    title: "Concentric Tempo Fatigue",
                    detail: "Average repetition speed slowed by ~\(percentStr) between the opening and closing sets.",
                    evidence: "Set 1 avg \(String(format: "%.1f", firstSet.meanDuration))s vs Set \(lastSet.setNumber) avg \(String(format: "%.1f", lastSet.meanDuration))s.",
                    severity: .info,
                    affectedRepIndices: []
                ))
            }
            
            if (romDecay.map { abs($0) < 6.0 } ?? false) && sets.count >= 3 {
                observations.append(FormObservation(
                    id: "session.cross_set.high_endurance",
                    title: "Excellent Set-to-Set Consistency",
                    detail: "Maintained uniform technique and range of motion across all \(sets.count) sets.",
                    evidence: "Less than 6% variance in range of motion across the entire session.",
                    severity: .positive,
                    affectedRepIndices: []
                ))
            }
        }
        
        fatigueIndex = min(max(fatigueIndex, 5.0), 100.0)
        
        return WorkoutSessionAnalysis(
            exerciseType: exerciseType,
            totalSets: sets.count,
            totalReps: totalRepsCount,
            averageQualityScore: avgQuality,
            averageROM: avgROM,
            romTrend: trend,
            romDecayPercent: romDecay,
            tempoSlowdownPercent: tempoSlowdown,
            fatigueIndex: fatigueIndex,
            setTrends: trendPoints,
            sessionObservations: observations
        )
    }
}
