import Foundation

/// Categories for organizing strength-training exercises
public enum ExerciseCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case arms = "Arms"
    case pull = "Back & Pull"
    case push = "Chest & Shoulders"
    case legs = "Legs & Lower Body"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .arms: return "💪"
        case .pull: return "🚣‍♂️"
        case .push: return "🏋️‍♂️"
        case .legs: return "🦵"
        }
    }
}

/// Supported strength-training exercises in FormCoach
public enum ExerciseType: String, Codable, CaseIterable, Sendable, Identifiable {
    // Arms
    case bicepsCurl
    case tricepsPushdown
    
    // Back & Pull
    case seatedRow
    case chestSupportedRow
    case facePull
    case straightArmPulldown
    
    // Chest & Shoulders
    case chestPress
    case shoulderPress
    
    // Legs & Lower Body
    case squat
    case legPress
    case calfExtension
    
    public var id: String { rawValue }
    
    public var category: ExerciseCategory {
        switch self {
        case .bicepsCurl, .tricepsPushdown:
            return .arms
        case .seatedRow, .chestSupportedRow, .facePull, .straightArmPulldown:
            return .pull
        case .chestPress, .shoulderPress:
            return .push
        case .squat, .legPress, .calfExtension:
            return .legs
        }
    }
    
    public var displayName: String {
        switch self {
        case .bicepsCurl: return "Biceps Curl"
        case .tricepsPushdown: return "Triceps Pushdown"
        case .seatedRow: return "Seated Cable Row"
        case .chestSupportedRow: return "Chest Supported Incline Row"
        case .facePull: return "Face Pull"
        case .straightArmPulldown: return "Rope Straight Arm Pulldown"
        case .chestPress: return "Chest Press Machine"
        case .shoulderPress: return "Shoulder Press"
        case .squat: return "Squat"
        case .legPress: return "Leg Press Machine"
        case .calfExtension: return "Calf Extension / Raise"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .bicepsCurl: return "Dumbbell / Barbell Curl"
        case .tricepsPushdown: return "Cable Rope / Bar Extension"
        case .seatedRow: return "Cable / Machine Row"
        case .chestSupportedRow: return "Incline Dumbbell / Machine Row"
        case .facePull: return "High Cable Rope Face Pull"
        case .straightArmPulldown: return "High Cable Lat Pulldown"
        case .chestPress: return "Machine / Dumbbell Press"
        case .shoulderPress: return "Overhead Press"
        case .squat: return "Bodyweight / Barbell Squat"
        case .legPress: return "45° / Horizontal Leg Press"
        case .calfExtension: return "Machine / Leg Press Calf Raise"
        }
    }
    
    public var recommendedView: CameraViewType {
        switch self {
        case .bicepsCurl, .tricepsPushdown, .seatedRow, .chestSupportedRow, .straightArmPulldown, .squat, .legPress, .calfExtension:
            return .side
        case .chestPress:
            return .side
        case .facePull, .shoulderPress:
            return .front
        }
    }
    
    public var supportedViews: [CameraViewType] {
        switch self {
        case .bicepsCurl, .tricepsPushdown, .seatedRow, .chestSupportedRow, .straightArmPulldown, .chestPress, .squat, .legPress, .calfExtension:
            return [.side, .front45, .front]
        case .facePull, .shoulderPress:
            return [.front, .front45, .side]
        }
    }
    
    public var keyMetricsList: [String] {
        switch self {
        case .bicepsCurl: return ["Elbow ROM", "Shoulder Drift", "Tempo", "Rep Count"]
        case .tricepsPushdown: return ["Lockout ROM", "Pinned Elbow Stability", "Tempo", "Rep Count"]
        case .seatedRow: return ["Retraction ROM", "Torso Stability", "Tempo", "Rep Count"]
        case .chestSupportedRow: return ["Peak Retraction", "Eccentric Control", "Tempo", "Rep Count"]
        case .facePull: return ["Elbow Height Level", "External Rotation", "Tempo", "Rep Count"]
        case .straightArmPulldown: return ["Arm Arc ROM", "Elbow Lock Stability", "Tempo", "Rep Count"]
        case .chestPress: return ["Chest Depth ROM", "Lockout Extension", "Tempo", "Rep Count"]
        case .shoulderPress: return ["Lockout ROM", "Press Symmetry", "Tempo", "Rep Count"]
        case .squat: return ["Knee Depth / ROM", "Torso Incline", "Tempo", "Rep Count"]
        case .legPress: return ["Knee Flexion Depth", "Controlled Extension", "Tempo", "Rep Count"]
        case .calfExtension: return ["Ankle ROM", "Peak Stretch & Squeeze", "Tempo", "Rep Count"]
        }
    }
    
    public var isAvailable: Bool {
        true
    }
    
    public var isM1Available: Bool {
        true
    }
}
