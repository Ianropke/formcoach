import Foundation

/// Comprehensive analysis results for a recorded exercise set
public struct SetAnalysis: Codable, Sendable, Equatable {
    public let overallQualityScore: Double // 0 ... 100
    public let romScore: Double // 0 ... 100
    public let consistencyScore: Double // 0 ... 100
    public let tempoScore: Double // 0 ... 100
    public let symmetryScore: Double? // 0 ... 100 (nil if view doesn't support symmetry)
    
    public let primaryObservation: String
    public let observations: [FormObservation]
    public let trackingConfidence: PoseConfidence
    
    // Aggregated Rep Summary Metrics
    public let repCount: Int
    public let meanROM: Double
    public let meanDuration: TimeInterval
    public let earlyLateROMDeltaPercent: Double?
    public let earlyLateTempoDeltaPercent: Double?
    
    public init(
        overallQualityScore: Double,
        romScore: Double,
        consistencyScore: Double,
        tempoScore: Double,
        symmetryScore: Double? = nil,
        primaryObservation: String,
        observations: [FormObservation],
        trackingConfidence: PoseConfidence,
        repCount: Int,
        meanROM: Double,
        meanDuration: TimeInterval,
        earlyLateROMDeltaPercent: Double? = nil,
        earlyLateTempoDeltaPercent: Double? = nil
    ) {
        self.overallQualityScore = overallQualityScore
        self.romScore = romScore
        self.consistencyScore = consistencyScore
        self.tempoScore = tempoScore
        self.symmetryScore = symmetryScore
        self.primaryObservation = primaryObservation
        self.observations = observations
        self.trackingConfidence = trackingConfidence
        self.repCount = repCount
        self.meanROM = meanROM
        self.meanDuration = meanDuration
        self.earlyLateROMDeltaPercent = earlyLateROMDeltaPercent
        self.earlyLateTempoDeltaPercent = earlyLateTempoDeltaPercent
    }
}
