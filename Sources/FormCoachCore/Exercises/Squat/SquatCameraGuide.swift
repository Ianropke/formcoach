import Foundation
import CoreGraphics

/// Evaluates camera framing readiness specifically for Squats
public struct SquatCameraGuide: Sendable {
    public static let requiredJoints: Set<Joint> = [
        .nose,
        .leftHip, .rightHip,
        .leftKnee, .rightKnee,
        .leftAnkle, .rightAnkle
    ]
    
    public static func validate(
        frame: PoseFrame,
        view: CameraViewType
    ) -> CameraSetupValidation {
        let conf = PoseConfidence.evaluate(joints: frame.joints, required: requiredJoints)
        
        let hasNose = frame.joints[.nose]?.isTracked ?? false
        let hasHips = (frame.joints[.leftHip]?.isTracked ?? false) || (frame.joints[.rightHip]?.isTracked ?? false)
        let hasKnees = (frame.joints[.leftKnee]?.isTracked ?? false) || (frame.joints[.rightKnee]?.isTracked ?? false)
        let hasAnkles = (frame.joints[.leftAnkle]?.isTracked ?? false) || (frame.joints[.rightAnkle]?.isTracked ?? false)
        
        let fullBodyVisible = hasNose && hasHips && hasKnees && hasAnkles
        
        // Check scale
        var isScaleOptimal = false
        var feedback: [String] = []
        
        if let bbox = frame.boundingBox {
            let heightRatio = bbox.height
            if heightRatio < 0.40 {
                feedback.append("Move closer to the camera")
            } else if heightRatio > 0.92 {
                feedback.append("Step back — your full body must fit in frame")
            } else {
                isScaleOptimal = true
            }
            
            if bbox.minY < 0.05 {
                feedback.append("Head is near top edge — step back or lower camera")
            }
            if bbox.maxY > 0.96 {
                feedback.append("Feet are near bottom edge — step back")
            }
            if bbox.midX < 0.25 {
                feedback.append("Move right into center frame")
            } else if bbox.midX > 0.75 {
                feedback.append("Move left into center frame")
            }
        } else {
            feedback.append("Step into the camera view")
        }
        
        if !hasAnkles {
            feedback.append("Ankles / feet are obscured or out of frame")
        }
        if !hasHips {
            feedback.append("Hips are not clearly visible")
        }
        
        let isReady = fullBodyVisible && isScaleOptimal && (conf.level != .insufficient)
        
        return CameraSetupValidation(
            isReady: isReady,
            isFullBodyVisible: fullBodyVisible,
            areFeetVisible: hasAnkles,
            isHeadVisible: hasNose,
            isHipsVisible: hasHips,
            isScaleOptimal: isScaleOptimal,
            poseConfidence: conf,
            feedbackPrompts: feedback
        )
    }
}
