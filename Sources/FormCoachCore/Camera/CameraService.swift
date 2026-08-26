import Foundation
import AVFoundation
import CoreMedia
import CoreGraphics
import ImageIO

/// Protocol for camera frame delegate callbacks
public protocol CameraFrameDelegate: AnyObject, Sendable {
    func cameraService(
        _ service: CameraService,
        didOutput sampleBuffer: CMSampleBuffer,
        timestamp: TimeInterval
    )
}

/// AVFoundation Camera Service providing live preview and frame streaming for computer vision
public final class CameraService: NSObject, @unchecked Sendable {
    public let captureSession = AVCaptureSession()
    
    private let sessionQueue = DispatchQueue(label: "com.formcoach.camera.sessionQueue")
    private let videoDataOutputQueue = DispatchQueue(label: "com.formcoach.camera.videoOutputQueue", qos: .userInitiated)
    
    private var videoOutput: AVCaptureVideoDataOutput?
    public weak var delegate: CameraFrameDelegate?
    
    private var startTime: TimeInterval?
    private var isConfigured = false
    
    public override init() {
        super.init()
    }
    
    /// Configures the AVCaptureSession with rear camera and video data output
    public func configureSession(targetFPS: Int = 30) {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.isConfigured else { return }
            
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .high
            
            // 1. Setup Camera Input (Default to rear wide-angle camera)
            #if os(iOS)
            let deviceDiscovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: .back
            )
            
            guard let camera = deviceDiscovery.devices.first,
                  let videoInput = try? AVCaptureDeviceInput(device: camera),
                  self.captureSession.canAddInput(videoInput) else {
                self.captureSession.commitConfiguration()
                return
            }
            
            self.captureSession.addInput(videoInput)
            #endif
            
            // 2. Setup Video Data Output
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            
            output.setSampleBufferDelegate(self, queue: self.videoDataOutputQueue)
            
            if self.captureSession.canAddOutput(output) {
                self.captureSession.addOutput(output)
                self.videoOutput = output
            }
            
            self.captureSession.commitConfiguration()
            self.isConfigured = true
        }
    }
    
    public func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.isConfigured, !self.captureSession.isRunning else { return }
            self.startTime = ProcessInfo.processInfo.systemUptime
            self.captureSession.startRunning()
        }
    }
    
    public func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            self.startTime = nil
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let start = startTime else { return }
        let current = ProcessInfo.processInfo.systemUptime
        let relativeTimestamp = max(0.0, current - start)
        
        delegate?.cameraService(self, didOutput: sampleBuffer, timestamp: relativeTimestamp)
    }
}
