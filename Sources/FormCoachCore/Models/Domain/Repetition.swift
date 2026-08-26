import Foundation

/// Segmented repetition record with phase timestamps and kinematic metrics
public struct Repetition: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let index: Int
    
    // Timestamps (seconds from set start)
    public let startTime: TimeInterval
    public let inflectionTime: TimeInterval // Bottom of squat or top of curl
    public let endTime: TimeInterval
    
    // Phase Durations (seconds)
    public let eccentricDuration: TimeInterval
    public let pauseDuration: TimeInterval
    public let concentricDuration: TimeInterval
    public var duration: TimeInterval {
        endTime - startTime
    }
    
    // Biomechanical Metrics
    public let primaryROM: Double // e.g. minimum knee angle in degrees
    public let secondaryROM: Double? // e.g. hip angle in degrees
    public let torsoAngleMean: Double? // in degrees relative to vertical
    
    // Tracking & Integrity
    public let confidence: Double
    public let isComplete: Bool
    
    public init(
        id: UUID = UUID(),
        index: Int,
        startTime: TimeInterval,
        inflectionTime: TimeInterval,
        endTime: TimeInterval,
        eccentricDuration: TimeInterval,
        pauseDuration: TimeInterval,
        concentricDuration: TimeInterval,
        primaryROM: Double,
        secondaryROM: Double? = nil,
        torsoAngleMean: Double? = nil,
        confidence: Double,
        isComplete: Bool = true
    ) {
        self.id = id
        self.index = index
        self.startTime = startTime
        self.inflectionTime = inflectionTime
        self.endTime = endTime
        self.eccentricDuration = eccentricDuration
        self.pauseDuration = pauseDuration
        self.concentricDuration = concentricDuration
        self.primaryROM = primaryROM
        self.secondaryROM = secondaryROM
        self.torsoAngleMean = torsoAngleMean
        self.confidence = confidence
        self.isComplete = isComplete
    }
}
