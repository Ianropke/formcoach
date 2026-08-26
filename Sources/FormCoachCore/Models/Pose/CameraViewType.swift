import Foundation

/// Angle of the camera relative to the athlete
public enum CameraViewType: String, Codable, CaseIterable, Sendable {
    case side = "Side View"
    case front = "Front View"
    case rear = "Rear View"
    case front45 = "45° Front Angle"
    case rear45 = "45° Rear Angle"
    
    public var shortDescription: String {
        switch self {
        case .side: return "Side profile (90°)"
        case .front: return "Directly in front (0°)"
        case .rear: return "Directly behind (180°)"
        case .front45: return "45° oblique front"
        case .rear45: return "45° oblique rear"
        }
    }
}
