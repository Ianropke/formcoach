import Foundation
import Vision
import CoreMedia
import CoreGraphics
import ImageIO

/// Production Apple Vision pose extraction service
public final class VisionPoseService: PoseServiceProtocol, @unchecked Sendable {
    
    public init() {}
    
    public func processFrame(
        sampleBuffer: CMSampleBuffer,
        timestamp: TimeInterval,
        orientation: CGImagePropertyOrientation = .up
    ) async throws -> PoseFrame? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        return try await processPixelBuffer(
            pixelBuffer: pixelBuffer,
            timestamp: timestamp,
            orientation: orientation
        )
    }
    
    public func processPixelBuffer(
        pixelBuffer: CVPixelBuffer,
        timestamp: TimeInterval,
        orientation: CGImagePropertyOrientation = .up
    ) async throws -> PoseFrame? {
        let request = VNDetectHumanBodyPoseRequest()
        
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: orientation,
            options: [:]
        )
        
        try handler.perform([request])
        
        guard let observations = request.results, !observations.isEmpty else {
            return nil
        }
        
        // Select primary athlete (largest bounding box or highest confidence)
        guard let primaryObservation = selectPrimaryObservation(from: observations) else {
            return nil
        }
        
        return extractPoseFrame(
            from: primaryObservation,
            timestamp: timestamp,
            orientation: orientation
        )
    }
    
    /// Selects the primary subject when multiple people are visible in the gym
    private func selectPrimaryObservation(
        from observations: [VNHumanBodyPoseObservation]
    ) -> VNHumanBodyPoseObservation? {
        guard observations.count > 1 else { return observations.first }
        
        // Pick observation with highest average confidence and largest spread
        return observations.max(by: { obs1, obs2 in
            let conf1 = obs1.confidence
            let conf2 = obs2.confidence
            return conf1 < conf2
        })
    }
    
    /// Maps VNHumanBodyPoseObservation into normalized PoseFrame domain model
    private func extractPoseFrame(
        from observation: VNHumanBodyPoseObservation,
        timestamp: TimeInterval,
        orientation: CGImagePropertyOrientation
    ) -> PoseFrame? {
        var jointsMap: [Joint: JointObservation] = [:]
        var totalConfidence = 0.0
        var trackedJointsCount = 0
        
        let jointMappings: [(VNHumanBodyPoseObservation.JointName, Joint)] = [
            (.nose, .nose),
            (.leftEye, .leftEye),
            (.rightEye, .rightEye),
            (.leftEar, .leftEar),
            (.rightEar, .rightEar),
            (.leftShoulder, .leftShoulder),
            (.rightShoulder, .rightShoulder),
            (.leftElbow, .leftElbow),
            (.rightElbow, .rightElbow),
            (.leftWrist, .leftWrist),
            (.rightWrist, .rightWrist),
            (.leftHip, .leftHip),
            (.rightHip, .rightHip),
            (.leftKnee, .leftKnee),
            (.rightKnee, .rightKnee),
            (.leftAnkle, .leftAnkle),
            (.rightAnkle, .rightAnkle),
            (.neck, .neck),
            (.root, .root)
        ]
        
        for (vnName, domainJoint) in jointMappings {
            if let recognizedPoint = try? observation.recognizedPoint(vnName), recognizedPoint.confidence > 0.05 {
                let normalizedPoint = CoordinateNormalizer.normalizeVisionPoint(
                    recognizedPoint.location,
                    orientation: orientation
                )
                let conf = Double(recognizedPoint.confidence)
                
                jointsMap[domainJoint] = JointObservation(
                    point2D: normalizedPoint,
                    depthZ: nil,
                    confidence: conf
                )
                
                totalConfidence += conf
                trackedJointsCount += 1
            }
        }
        
        guard trackedJointsCount > 0 else { return nil }
        
        let avgConfidence = totalConfidence / Double(trackedJointsCount)
        
        return PoseFrame(
            timestamp: timestamp,
            joints: jointsMap,
            confidence: avgConfidence,
            isInterpolated: false
        )
    }
}
