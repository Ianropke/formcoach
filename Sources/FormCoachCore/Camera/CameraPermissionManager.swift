import Foundation
import AVFoundation

/// Manages AVFoundation camera permissions
@MainActor
public final class CameraPermissionManager: ObservableObject {
    public static let shared = CameraPermissionManager()
    
    @Published public var authorizationStatus: AVAuthorizationStatus
    
    public init() {
        self.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    public var isAuthorized: Bool {
        authorizationStatus == .authorized
    }
    
    public func requestPermission() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        self.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        return granted
    }
}
