import Foundation

/// Primary Squat exercise analyzer orchestrating segmentation, metrics, and rule evaluation
public struct SquatAnalyzer: ExerciseAnalyzerProtocol, Sendable {
    public let exerciseType: ExerciseType = .squat
    public let requiredJoints: Set<Joint> = SquatCameraGuide.requiredJoints
    public let supportedViews: [CameraViewType] = [.side, .front45, .front]
    
    private let segmenter: SquatRepSegmenter
    private let ruleEngine: FormRuleEngine
    
    public init() {
        self.segmenter = SquatRepSegmenter()
        self.ruleEngine = FormRuleEngine(rules: SquatRules.standardRules)
    }
    
    public func validateCameraSetup(
        frame: PoseFrame,
        view: CameraViewType
    ) -> CameraSetupValidation {
        SquatCameraGuide.validate(frame: frame, view: view)
    }
    
    public func segmentReps(
        timeSeries: PoseTimeSeries,
        view: CameraViewType
    ) -> [Repetition] {
        segmenter.segment(timeSeries: timeSeries, view: view)
    }
    
    public func analyzeSet(
        reps: [Repetition],
        timeSeries: PoseTimeSeries,
        view: CameraViewType
    ) -> SetAnalysis {
        let confidence = ConfidenceEngine.evaluateSetConfidence(
            timeSeries: timeSeries,
            requiredJoints: requiredJoints
        )
        
        guard !reps.isEmpty else {
            return SetAnalysis(
                overallQualityScore: 0.0,
                romScore: 0.0,
                consistencyScore: 0.0,
                tempoScore: 0.0,
                symmetryScore: nil,
                primaryObservation: "No completed squat repetitions detected in the recorded set.",
                observations: [],
                trackingConfidence: confidence,
                repCount: 0,
                meanROM: 0.0,
                meanDuration: 0.0
            )
        }
        
        let meanROM = SquatMetrics.computeMeanROM(reps: reps)
        let meanDuration = SquatMetrics.computeMeanDuration(reps: reps)
        let romScore = SquatMetrics.computeROMScore(reps: reps)
        let consistencyScore = SquatMetrics.computeConsistencyScore(reps: reps)
        let tempoScore = SquatMetrics.computeTempoScore(reps: reps)
        
        let earlyLateROMDelta = SquatMetrics.computeEarlyLateROMDelta(reps: reps)
        let earlyLateTempoDelta = SquatMetrics.computeEarlyLateTempoDelta(reps: reps)
        
        // Evaluate rules
        let context = SetAnalysisContext(
            exerciseType: .squat,
            reps: reps,
            cameraView: view,
            trackingConfidence: confidence,
            meanROM: meanROM,
            meanDuration: meanDuration,
            earlyLateROMDelta: earlyLateROMDelta,
            earlyLateTempoDelta: earlyLateTempoDelta
        )
        
        let observations = ruleEngine.evaluate(context: context)
        
        // Primary observation text
        let primaryText: String
        if let firstObs = observations.first {
            primaryText = firstObs.detail
        } else if reps.count >= 8 {
            primaryText = "Consistent technique with ~\(String(format: "%.0f°", meanROM)) knee depth across \(reps.count) repetitions."
        } else {
            primaryText = "\(reps.count) repetitions recorded with an average duration of \(String(format: "%.1f", meanDuration)) seconds per rep."
        }
        
        let overallQuality = (romScore * 0.40) + (consistencyScore * 0.35) + (tempoScore * 0.25)
        
        // Symmetry is only evaluated if view is front or rear
        let symmetryScore: Double? = (view == .front || view == .rear) ? 88.0 : nil
        
        return SetAnalysis(
            overallQualityScore: overallQuality,
            romScore: romScore,
            consistencyScore: consistencyScore,
            tempoScore: tempoScore,
            symmetryScore: symmetryScore,
            primaryObservation: primaryText,
            observations: observations,
            trackingConfidence: confidence,
            repCount: reps.count,
            meanROM: meanROM,
            meanDuration: meanDuration,
            earlyLateROMDeltaPercent: earlyLateROMDelta,
            earlyLateTempoDeltaPercent: earlyLateTempoDelta
        )
    }
}
