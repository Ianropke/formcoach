import Foundation

/// Primary Shoulder Press exercise analyzer orchestrating segmentation, metrics, and rule evaluation
public struct ShoulderPressAnalyzer: ExerciseAnalyzerProtocol, Sendable {
    public let exerciseType: ExerciseType = .shoulderPress
    public let requiredJoints: Set<Joint> = ShoulderPressCameraGuide.requiredJoints
    public let supportedViews: [CameraViewType] = [.front, .front45, .side]
    
    private let segmenter: ShoulderPressRepSegmenter
    private let ruleEngine: FormRuleEngine
    
    public init() {
        self.segmenter = ShoulderPressRepSegmenter()
        self.ruleEngine = FormRuleEngine(rules: ShoulderPressRules.standardRules)
    }
    
    public func validateCameraSetup(
        frame: PoseFrame,
        view: CameraViewType
    ) -> CameraSetupValidation {
        ShoulderPressCameraGuide.validate(frame: frame, view: view)
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
                primaryObservation: "No completed shoulder press repetitions detected in the recorded set.",
                observations: [],
                trackingConfidence: confidence,
                repCount: 0,
                meanROM: 0.0,
                meanDuration: 0.0
            )
        }
        
        let meanLockout = ShoulderPressMetrics.computeMeanLockoutROM(reps: reps)
        let meanDuration = ShoulderPressMetrics.computeMeanDuration(reps: reps)
        let meanAsymmetry = ShoulderPressMetrics.computeMeanAsymmetry(reps: reps)
        let romScore = ShoulderPressMetrics.computeROMScore(reps: reps)
        let symmetryScore = ShoulderPressMetrics.computeSymmetryScore(reps: reps)
        let consistencyScore = ShoulderPressMetrics.computeConsistencyScore(reps: reps)
        let tempoScore = ShoulderPressMetrics.computeTempoScore(reps: reps)
        
        let earlyLateROMDelta = ShoulderPressMetrics.computeEarlyLateROMDelta(reps: reps)
        
        let context = SetAnalysisContext(
            exerciseType: .shoulderPress,
            reps: reps,
            cameraView: view,
            trackingConfidence: confidence,
            meanROM: meanLockout,
            meanDuration: meanDuration,
            earlyLateROMDelta: earlyLateROMDelta,
            earlyLateTempoDelta: nil
        )
        
        let observations = ruleEngine.evaluate(context: context)
        
        let primaryText: String
        if let firstObs = observations.first {
            primaryText = firstObs.detail
        } else if meanAsymmetry < 6.0 {
            primaryText = "Symmetrical overhead lockout (~\(String(format: "%.0f°", meanLockout))) across all \(reps.count) repetitions."
        } else {
            primaryText = "\(reps.count) repetitions performed with an average tempo of \(String(format: "%.1f", meanDuration)) seconds per rep."
        }
        
        let overallQuality = (romScore * 0.35) + (symmetryScore * 0.30) + (consistencyScore * 0.20) + (tempoScore * 0.15)
        
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
            meanROM: meanLockout,
            meanDuration: meanDuration,
            earlyLateROMDeltaPercent: earlyLateROMDelta,
            earlyLateTempoDeltaPercent: nil
        )
    }
}
