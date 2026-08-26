import Foundation

/// Deterministic heuristic rule representation
public struct BiomechanicalRule: Sendable {
    public let id: String
    public let title: String
    public let severity: ObservationSeverity
    public let condition: @Sendable (SetAnalysisContext) -> FormObservation?
    
    public init(
        id: String,
        title: String,
        severity: ObservationSeverity,
        condition: @escaping @Sendable (SetAnalysisContext) -> FormObservation?
    ) {
        self.id = id
        self.title = title
        self.severity = severity
        self.condition = condition
    }
}

/// Context passed to rule evaluator
public struct SetAnalysisContext: Sendable {
    public let exerciseType: ExerciseType
    public let reps: [Repetition]
    public let cameraView: CameraViewType
    public let trackingConfidence: PoseConfidence
    public let meanROM: Double
    public let meanDuration: Double
    public let earlyLateROMDelta: Double?
    public let earlyLateTempoDelta: Double?
    
    public init(
        exerciseType: ExerciseType,
        reps: [Repetition],
        cameraView: CameraViewType,
        trackingConfidence: PoseConfidence,
        meanROM: Double,
        meanDuration: Double,
        earlyLateROMDelta: Double?,
        earlyLateTempoDelta: Double?
    ) {
        self.exerciseType = exerciseType
        self.reps = reps
        self.cameraView = cameraView
        self.trackingConfidence = trackingConfidence
        self.meanROM = meanROM
        self.meanDuration = meanDuration
        self.earlyLateROMDelta = earlyLateROMDelta
        self.earlyLateTempoDelta = earlyLateTempoDelta
    }
}

/// Evaluator that runs rules and generates explainable observations
public struct FormRuleEngine: Sendable {
    public let rules: [BiomechanicalRule]
    
    public init(rules: [BiomechanicalRule]) {
        self.rules = rules
    }
    
    public func evaluate(context: SetAnalysisContext) -> [FormObservation] {
        var observations: [FormObservation] = []
        
        for rule in rules {
            if let obs = rule.condition(context) {
                observations.append(obs)
            }
        }
        
        return observations
    }
}
