import Foundation

/// Relational workout session model
public final class WorkoutModel: Codable, Identifiable, @unchecked Sendable {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    public var notes: String?
    public var sets: [ExerciseSetModel]
    
    public init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        notes: String? = nil,
        sets: [ExerciseSetModel] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.notes = notes
        self.sets = sets
    }
}

/// Relational exercise set model
public final class ExerciseSetModel: Codable, Identifiable, @unchecked Sendable {
    public var id: UUID
    public var exerciseTypeRaw: String
    public var cameraViewRaw: String
    public var recordedAt: Date
    public var videoPath: String?
    public var poseDataPath: String?
    public var repCount: Int
    public var trackingConfidence: Double
    public var analyzerVersion: Int
    public var ruleVersion: Int
    public var reps: [RepModel]
    public var analysis: SetAnalysisModel?
    
    public init(
        id: UUID = UUID(),
        exerciseTypeRaw: String,
        cameraViewRaw: String,
        recordedAt: Date = Date(),
        videoPath: String? = nil,
        poseDataPath: String? = nil,
        repCount: Int = 0,
        trackingConfidence: Double = 1.0,
        analyzerVersion: Int = 1,
        ruleVersion: Int = 1,
        reps: [RepModel] = [],
        analysis: SetAnalysisModel? = nil
    ) {
        self.id = id
        self.exerciseTypeRaw = exerciseTypeRaw
        self.cameraViewRaw = cameraViewRaw
        self.recordedAt = recordedAt
        self.videoPath = videoPath
        self.poseDataPath = poseDataPath
        self.repCount = repCount
        self.trackingConfidence = trackingConfidence
        self.analyzerVersion = analyzerVersion
        self.ruleVersion = ruleVersion
        self.reps = reps
        self.analysis = analysis
    }
    
    public var exerciseType: ExerciseType {
        ExerciseType(rawValue: exerciseTypeRaw) ?? .squat
    }
    
    public var cameraView: CameraViewType {
        CameraViewType(rawValue: cameraViewRaw) ?? .side
    }
}

/// Relational rep model
public final class RepModel: Codable, Identifiable, @unchecked Sendable {
    public var id: UUID
    public var index: Int
    public var startTime: Double
    public var inflectionTime: Double
    public var endTime: Double
    public var duration: Double
    public var eccentricDuration: Double
    public var concentricDuration: Double
    public var pauseDuration: Double
    public var primaryROM: Double
    public var secondaryROM: Double?
    public var torsoAngleMean: Double?
    public var confidence: Double
    public var isComplete: Bool
    
    public init(
        id: UUID = UUID(),
        index: Int,
        startTime: Double,
        inflectionTime: Double,
        endTime: Double,
        duration: Double,
        eccentricDuration: Double,
        concentricDuration: Double,
        pauseDuration: Double,
        primaryROM: Double,
        secondaryROM: Double? = nil,
        torsoAngleMean: Double? = nil,
        confidence: Double = 1.0,
        isComplete: Bool = true
    ) {
        self.id = id
        self.index = index
        self.startTime = startTime
        self.inflectionTime = inflectionTime
        self.endTime = endTime
        self.duration = duration
        self.eccentricDuration = eccentricDuration
        self.concentricDuration = concentricDuration
        self.pauseDuration = pauseDuration
        self.primaryROM = primaryROM
        self.secondaryROM = secondaryROM
        self.torsoAngleMean = torsoAngleMean
        self.confidence = confidence
        self.isComplete = isComplete
    }
}

/// Relational set analysis model
public final class SetAnalysisModel: Codable, Identifiable, @unchecked Sendable {
    public var id: UUID
    public var overallQualityScore: Double
    public var romScore: Double
    public var consistencyScore: Double
    public var tempoScore: Double
    public var symmetryScore: Double?
    public var primaryObservation: String
    public var observationsJson: String
    
    public init(
        id: UUID = UUID(),
        overallQualityScore: Double,
        romScore: Double,
        consistencyScore: Double,
        tempoScore: Double,
        symmetryScore: Double? = nil,
        primaryObservation: String,
        observationsJson: String = "[]"
    ) {
        self.id = id
        self.overallQualityScore = overallQualityScore
        self.romScore = romScore
        self.consistencyScore = consistencyScore
        self.tempoScore = tempoScore
        self.symmetryScore = symmetryScore
        self.primaryObservation = primaryObservation
        self.observationsJson = observationsJson
    }
}
