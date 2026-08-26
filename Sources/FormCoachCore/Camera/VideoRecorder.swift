import Foundation
import AVFoundation
import CoreMedia

/// Asynchronously encodes CMSampleBuffers to local MP4 video file
public final class VideoRecorder: @unchecked Sendable {
    private var assetWriter: AVAssetWriter?
    private var assetWriterVideoInput: AVAssetWriterInput?
    private let recordingQueue = DispatchQueue(label: "com.formcoach.camera.recordingQueue")
    
    private var isRecording = false
    private var firstSampleTime: CMTime?
    
    public init() {}
    
    public func startRecording(to outputURL: URL, width: Int = 1080, height: Int = 1920) throws {
        try recordingQueue.sync {
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try? FileManager.default.removeItem(at: outputURL)
            }
            
            let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
            
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 6_000_000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                ]
            ]
            
            let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput.expectsMediaDataInRealTime = true
            
            if writer.canAdd(videoInput) {
                writer.add(videoInput)
            }
            
            self.assetWriter = writer
            self.assetWriterVideoInput = videoInput
            self.firstSampleTime = nil
            self.isRecording = true
        }
    }
    
    public func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        recordingQueue.async { [weak self] in
            guard let self = self, self.isRecording, let writer = self.assetWriter, let input = self.assetWriterVideoInput else {
                return
            }
            
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            
            if writer.status == .unknown {
                writer.startWriting()
                writer.startSession(atSourceTime: timestamp)
                self.firstSampleTime = timestamp
            }
            
            if writer.status == .writing && input.isReadyForMoreMediaData {
                input.append(sampleBuffer)
            }
        }
    }
    
    public func stopRecording() async throws {
        try await withCheckedThrowingContinuation { continuation in
            recordingQueue.async { [weak self] in
                guard let self = self, let writer = self.assetWriter else {
                    continuation.resume()
                    return
                }
                
                self.isRecording = false
                self.assetWriterVideoInput?.markAsFinished()
                
                writer.finishWriting {
                    if let error = writer.error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }
}
