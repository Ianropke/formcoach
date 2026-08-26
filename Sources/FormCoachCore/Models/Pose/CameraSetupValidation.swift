import Foundation

/// Result of evaluating real-time framing suitability for an exercise
public struct CameraSetupValidation: Sendable, Equatable {
    public let isReady: Bool
    public let isFullBodyVisible: Bool
    public let areFeetVisible: Bool
    public let isHeadVisible: Bool
    public let isHipsVisible: Bool
    public let isScaleOptimal: Bool
    public let poseConfidence: PoseConfidence
    public let feedbackPrompts: [String]
    
    public init(
        isReady: Bool,
        isFullBodyVisible: Bool,
        areFeetVisible: Bool,
        isHeadVisible: Bool,
        isHipsVisible: Bool,
        isScaleOptimal: Bool,
        poseConfidence: PoseConfidence,
        feedbackPrompts: [String]
    ) {
        self.isReady = isReady
        self.isFullBodyVisible = isFullBodyVisible
        self.areFeetVisible = areFeetVisible
        self.isHeadVisible = isHeadVisible
        self.isHipsVisible = isHipsVisible
        self.isScaleOptimal = isScaleOptimal
        self.poseConfidence = poseConfidence
        self.feedbackPrompts = feedbackPrompts
    }
}
