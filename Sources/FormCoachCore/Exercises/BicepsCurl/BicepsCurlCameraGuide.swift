import Foundation
import CoreGraphics

/// Evaluates camera framing readiness specifically for Biceps Curls
public struct BicepsCurlCameraGuide: Sendable {
    public static let requiredJoints: Set<Joint> = [
        .nose,
        .leftShoulder, .rightShoulder,
        .leftElbow, .rightElbow,
        .leftWrist, .rightWrist,
        .leftHip, .rightHip
    ]
    
    public static func validate(
        frame: PoseFrame,
        view: CameraViewType
    ) -> CameraSetupValidation {
        let conf = PoseConfidence.evaluate(joints: frame.joints, required: requiredJoints)
        
        let hasNose = frame.joints[.nose]?.isTracked ?? false
        let hasShoulders = (frame.joints[.leftShoulder]?.isTracked ?? false) || (frame.joints[.rightShoulder]?.isTracked ?? false)
        let hasElbows = (frame.joints[.leftElbow]?.isTracked ?? false) || (frame.joints[.rightElbow]?.isTracked ?? false)
        let hasWrists = (frame.joints[.leftWrist]?.isTracked ?? false) || (frame.joints[.rightWrist]?.isTracked ?? false)
        let hasHips = (frame.joints[.leftHip]?.isTracked ?? false) || (frame.joints[.rightHip]?.isTracked ?? false)
        
        let upperBodyVisible = hasNose && hasShoulders && hasElbows && hasWrists && hasHips
        
        var isScaleOptimal = false
        var feedback: [String] = []
        
        if let bbox = frame.boundingBox {
            let heightRatio = bbox.height
            if heightRatio < 0.35 {
                feedback.append("Move closer to the camera")
            } else if heightRatio > 0.95 {
                feedback.append("Step back slightly — ensure arms fit in frame during curl")
            } else {
                isScaleOptimal = true
            }
            
            if bbox.minX < 0.08 || bbox.maxX > 0.92 {
                feedback.append("Center your arms in frame to allow full curl ROM")
            }
        } else {
            feedback.append("Step into the camera view")
        }
        
        if !hasWrists {
            feedback.append("Wrists/hands are not visible — adjust camera angle")
        }
        if !hasElbows {
            feedback.append("Elbows are obscured")
        }
        
        let isReady = upperBodyVisible && isScaleOptimal && (conf.level != .insufficient)
        
        return CameraSetupValidation(
            isReady: isReady,
            isFullBodyVisible: upperBodyVisible,
            areFeetVisible: true, // Not strictly required for upper-body curls
            isHeadVisible: hasNose,
            isHipsVisible: hasHips,
            isScaleOptimal: isScaleOptimal,
            poseConfidence: conf,
            feedbackPrompts: feedback
        )
    }
}
