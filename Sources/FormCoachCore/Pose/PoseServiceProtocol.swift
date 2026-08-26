import Foundation
import CoreMedia
import CoreGraphics

/// Abstraction protocol for pose estimation backends
public protocol PoseServiceProtocol: Sendable {
    /// Detect pose in a single CMSampleBuffer frame at specified timestamp
    func processFrame(
        sampleBuffer: CMSampleBuffer,
        timestamp: TimeInterval,
        orientation: CGImagePropertyOrientation
    ) async throws -> PoseFrame?
    
    /// Detect pose in a CVPixelBuffer
    func processPixelBuffer(
        pixelBuffer: CVPixelBuffer,
        timestamp: TimeInterval,
        orientation: CGImagePropertyOrientation
    ) async throws -> PoseFrame?
}
