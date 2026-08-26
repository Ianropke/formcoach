import Foundation

/// Supported strength-training exercises
public enum ExerciseType: String, Codable, CaseIterable, Sendable, Identifiable {
    case squat
    case bicepsCurl
    case shoulderPress
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .squat: return "Squat"
        case .bicepsCurl: return "Biceps Curl"
        case .shoulderPress: return "Shoulder Press"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .squat: return "Bodyweight / Goblet Squat"
        case .bicepsCurl: return "Dumbbell / Barbell Curl"
        case .shoulderPress: return "Overhead Press"
        }
    }
    
    public var recommendedView: CameraViewType {
        switch self {
        case .squat: return .side
        case .bicepsCurl: return .side
        case .shoulderPress: return .front
        }
    }
    
    public var supportedViews: [CameraViewType] {
        switch self {
        case .squat: return [.side, .front45, .front]
        case .bicepsCurl: return [.side, .front45, .front]
        case .shoulderPress: return [.front, .front45, .side]
        }
    }
    
    public var keyMetricsList: [String] {
        switch self {
        case .squat: return ["Knee Depth / ROM", "Tempo Consistency", "Torso Angle", "Rep Count"]
        case .bicepsCurl: return ["Elbow ROM", "Shoulder Drift", "Tempo", "Rep Count"]
        case .shoulderPress: return ["Lockout ROM", "Press Symmetry", "Tempo", "Rep Count"]
        }
    }
    
    public var isAvailable: Bool {
        true
    }
    
    public var isM1Available: Bool {
        true
    }
}
