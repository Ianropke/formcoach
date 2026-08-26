import Foundation

/// Protocol for exercise-specific repetition state machines
public protocol RepSegmenterProtocol: Sendable {
    func segment(
        timeSeries: PoseTimeSeries,
        view: CameraViewType
    ) -> [Repetition]
}
