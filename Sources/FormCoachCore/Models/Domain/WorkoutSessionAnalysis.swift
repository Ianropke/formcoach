import Foundation

/// Trajectory direction across multiple sets in a workout session
public enum TrendDirection: String, Codable, Sendable {
    case stable
    case improving
    case degrading
}

/// Set-by-set data point for cross-set trend visualization
public struct SetTrendDataPoint: Codable, Sendable, Identifiable, Equatable {
    public var id: UUID { setId }
    public let setId: UUID
    public let setNumber: Int
    public let repCount: Int
    public let meanROM: Double
    public let meanDuration: Double
    public let qualityScore: Double
    public let consistencyScore: Double
    public let trackingConfidence: Double
    
    public init(
        setId: UUID,
        setNumber: Int,
        repCount: Int,
        meanROM: Double,
        meanDuration: Double,
        qualityScore: Double,
        consistencyScore: Double,
        trackingConfidence: Double
    ) {
        self.setId = setId
        self.setNumber = setNumber
        self.repCount = repCount
        self.meanROM = meanROM
        self.meanDuration = meanDuration
        self.qualityScore = qualityScore
        self.consistencyScore = consistencyScore
        self.trackingConfidence = trackingConfidence
    }
}

/// Comprehensive cross-set analysis for an entire workout session
public struct WorkoutSessionAnalysis: Codable, Sendable, Equatable {
    public let exerciseType: ExerciseType
    public let totalSets: Int
    public let totalReps: Int
    public let averageQualityScore: Double
    public let averageROM: Double
    public let romTrend: TrendDirection
    public let romDecayPercent: Double?
    public let tempoSlowdownPercent: Double?
    public let fatigueIndex: Double // 0 ... 100 (0 = fresh, 100 = severe fatigue)
    
    public let setTrends: [SetTrendDataPoint]
    public let sessionObservations: [FormObservation]
    
    public init(
        exerciseType: ExerciseType,
        totalSets: Int,
        totalReps: Int,
        averageQualityScore: Double,
        averageROM: Double,
        romTrend: TrendDirection,
        romDecayPercent: Double?,
        tempoSlowdownPercent: Double?,
        fatigueIndex: Double,
        setTrends: [SetTrendDataPoint],
        sessionObservations: [FormObservation]
    ) {
        self.exerciseType = exerciseType
        self.totalSets = totalSets
        self.totalReps = totalReps
        self.averageQualityScore = averageQualityScore
        self.averageROM = averageROM
        self.romTrend = romTrend
        self.romDecayPercent = romDecayPercent
        self.tempoSlowdownPercent = tempoSlowdownPercent
        self.fatigueIndex = fatigueIndex
        self.setTrends = setTrends
        self.sessionObservations = sessionObservations
    }
}
