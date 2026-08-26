import Foundation

/// Individualized athlete baseline replacing arbitrary population norms
public struct PersonalBaseline: Codable, Sendable, Equatable {
    public let exerciseType: ExerciseType
    public let sessionsCount: Int
    public let totalRepsLogged: Int
    public let hasSufficientData: Bool // True if >= 3 sessions & >= 25 reps
    
    // Normal Distributions for this specific athlete
    public let baselineROMMean: Double // Average normal depth / flexion
    public let baselineROMStdDev: Double // Natural variance range
    public let personalBestROM: Double // Deepest / highest quality rep achieved
    public let baselineDurationMean: Double
    public let baselineConsistencyScore: Double
    
    // Status message
    public let statusMessage: String
    
    public init(
        exerciseType: ExerciseType,
        sessionsCount: Int,
        totalRepsLogged: Int,
        hasSufficientData: Bool,
        baselineROMMean: Double,
        baselineROMStdDev: Double,
        personalBestROM: Double,
        baselineDurationMean: Double,
        baselineConsistencyScore: Double,
        statusMessage: String
    ) {
        self.exerciseType = exerciseType
        self.sessionsCount = sessionsCount
        self.totalRepsLogged = totalRepsLogged
        self.hasSufficientData = hasSufficientData
        self.baselineROMMean = baselineROMMean
        self.baselineROMStdDev = baselineROMStdDev
        self.personalBestROM = personalBestROM
        self.baselineDurationMean = baselineDurationMean
        self.baselineConsistencyScore = baselineConsistencyScore
        self.statusMessage = statusMessage
    }
}

/// Comparison result of a set/workout against the athlete's personal baseline
public struct BaselineComparisonResult: Codable, Sendable, Equatable {
    public let isPersonalBest: Bool
    public let zScoreROM: Double? // Standard deviations from athlete's personal mean
    public let deviationPercent: Double?
    public let insightText: String
    
    public init(
        isPersonalBest: Bool,
        zScoreROM: Double?,
        deviationPercent: Double?,
        insightText: String
    ) {
        self.isPersonalBest = isPersonalBest
        self.zScoreROM = zScoreROM
        self.deviationPercent = deviationPercent
        self.insightText = insightText
    }
}
