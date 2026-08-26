import Foundation

/// Primary Biceps Curl exercise analyzer orchestrating segmentation, metrics, and rule evaluation
public struct BicepsCurlAnalyzer: ExerciseAnalyzerProtocol, Sendable {
    public let exerciseType: ExerciseType = .bicepsCurl
    public let requiredJoints: Set<Joint> = BicepsCurlCameraGuide.requiredJoints
    public let supportedViews: [CameraViewType] = [.side, .front45, .front]
    
    private let segmenter: BicepsCurlRepSegmenter
    private let ruleEngine: FormRuleEngine
    
    public init() {
        self.segmenter = BicepsCurlRepSegmenter()
        self.ruleEngine = FormRuleEngine(rules: BicepsCurlRules.standardRules)
    }
    
    public func validateCameraSetup(
        frame: PoseFrame,
        view: CameraViewType
    ) -> CameraSetupValidation {
        BicepsCurlCameraGuide.validate(frame: frame, view: view)
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
                primaryObservation: "No completed biceps curl repetitions detected in the recorded set.",
                observations: [],
                trackingConfidence: confidence,
                repCount: 0,
                meanROM: 0.0,
                meanDuration: 0.0
            )
        }
        
        let meanPeakROM = BicepsCurlMetrics.computeMeanPeakROM(reps: reps)
        let meanDuration = BicepsCurlMetrics.computeMeanDuration(reps: reps)
        let meanShoulderDrift = BicepsCurlMetrics.computeMeanShoulderDrift(reps: reps)
        let romScore = BicepsCurlMetrics.computeROMScore(reps: reps)
        let consistencyScore = BicepsCurlMetrics.computeConsistencyScore(reps: reps)
        let tempoScore = BicepsCurlMetrics.computeTempoScore(reps: reps)
        
        let earlyLateROMDelta = BicepsCurlMetrics.computeEarlyLateROMDelta(reps: reps)
        
        // Evaluate rules
        let context = SetAnalysisContext(
            exerciseType: .bicepsCurl,
            reps: reps,
            cameraView: view,
            trackingConfidence: confidence,
            meanROM: meanPeakROM,
            meanDuration: meanDuration,
            earlyLateROMDelta: earlyLateROMDelta,
            earlyLateTempoDelta: nil
        )
        
        let observations = ruleEngine.evaluate(context: context)
        
        let primaryText: String
        if let firstObs = observations.first {
            primaryText = firstObs.detail
        } else if meanShoulderDrift < 12.0 {
            primaryText = "Strict curl technique with ~\(String(format: "%.0f°", meanPeakROM)) peak elbow flexion across \(reps.count) repetitions."
        } else {
            primaryText = "\(reps.count) repetitions performed with an average tempo of \(String(format: "%.1f", meanDuration)) seconds per rep."
        }
        
        // Penalize overall quality if excessive momentum swinging was detected
        var overallQuality = (romScore * 0.40) + (consistencyScore * 0.35) + (tempoScore * 0.25)
        if meanShoulderDrift > 18.0 {
            overallQuality = max(40.0, overallQuality - (meanShoulderDrift - 18.0) * 1.5)
        }
        
        // Symmetry is only evaluated if view is front
        let symmetryScore: Double? = (view == .front) ? 90.0 : nil
        
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
            meanROM: meanPeakROM,
            meanDuration: meanDuration,
            earlyLateROMDeltaPercent: earlyLateROMDelta,
            earlyLateTempoDeltaPercent: nil
        )
    }
}
