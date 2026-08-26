import Foundation

/// Core contract for pluggable exercise analyzers
public protocol ExerciseAnalyzerProtocol: Sendable {
    var exerciseType: ExerciseType { get }
    var requiredJoints: Set<Joint> { get }
    var supportedViews: [CameraViewType] { get }
    
    /// Evaluates framing readiness during camera setup
    func validateCameraSetup(
        frame: PoseFrame,
        view: CameraViewType
    ) -> CameraSetupValidation
    
    /// Segments raw pose time-series into discreet repetitions
    func segmentReps(
        timeSeries: PoseTimeSeries,
        view: CameraViewType
    ) -> [Repetition]
    
    /// Computes comprehensive set metrics, consistency, and explainable observations
    func analyzeSet(
        reps: [Repetition],
        timeSeries: PoseTimeSeries,
        view: CameraViewType
    ) -> SetAnalysis
}
