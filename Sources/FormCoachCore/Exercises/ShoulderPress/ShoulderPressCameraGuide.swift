import Foundation
import CoreGraphics

/// Evaluates camera framing readiness specifically for Overhead Shoulder Press
public struct ShoulderPressCameraGuide: Sendable {
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
        let hasLeftArm = (frame.joints[.leftShoulder]?.isTracked ?? false) &&
                         (frame.joints[.leftElbow]?.isTracked ?? false) &&
                         (frame.joints[.leftWrist]?.isTracked ?? false)
        let hasRightArm = (frame.joints[.rightShoulder]?.isTracked ?? false) &&
                          (frame.joints[.rightElbow]?.isTracked ?? false) &&
                          (frame.joints[.rightWrist]?.isTracked ?? false)
        let hasHips = (frame.joints[.leftHip]?.isTracked ?? false) || (frame.joints[.rightHip]?.isTracked ?? false)
        
        let upperBodyVisible = hasNose && (hasLeftArm || hasRightArm) && hasHips
        
        var isScaleOptimal = false
        var feedback: [String] = []
        
        if let bbox = frame.boundingBox {
            // Need sufficient overhead clearance for full arm extension
            if bbox.minY < 0.15 {
                feedback.append("Tilt camera up or step back — ensure overhead lockout stays in frame")
            } else if bbox.height < 0.35 {
                feedback.append("Move closer to the camera")
            } else if bbox.height > 0.90 {
                feedback.append("Step back slightly for overhead clearance")
            } else {
                isScaleOptimal = true
            }
            
            if bbox.minX < 0.08 || bbox.maxX > 0.92 {
                feedback.append("Center yourself in frame")
            }
        } else {
            feedback.append("Step into the camera view")
        }
        
        if !hasLeftArm && !hasRightArm {
            feedback.append("Arms/wrists are not visible — adjust camera angle")
        }
        
        let isReady = upperBodyVisible && isScaleOptimal && (conf.level != .insufficient)
        
        return CameraSetupValidation(
            isReady: isReady,
            isFullBodyVisible: upperBodyVisible,
            areFeetVisible: true,
            isHeadVisible: hasNose,
            isHipsVisible: hasHips,
            isScaleOptimal: isScaleOptimal,
            poseConfidence: conf,
            feedbackPrompts: feedback
        )
    }
}
