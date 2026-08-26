import SwiftUI
import FormCoachCore

public struct CameraSetupView: View {
    @ObservedObject var coordinator: WorkoutSessionCoordinator
    let exercise: ExerciseType
    let viewType: CameraViewType
    
    public init(
        coordinator: WorkoutSessionCoordinator,
        exercise: ExerciseType,
        viewType: CameraViewType
    ) {
        self.coordinator = coordinator
        self.exercise = exercise
        self.viewType = viewType
    }
    
    public var body: some View {
        ZStack {
            // 1. Live Camera Feed
            CameraPreviewView(session: coordinator.cameraService.captureSession)
                .edgesIgnoringSafeArea(.all)
            
            // 2. Real-time Skeleton Overlay
            SkeletonCanvasView(
                poseFrame: coordinator.livePoseFrame,
                jointColor: isFramingReady ? .green : .orange
            )
            .edgesIgnoringSafeArea(.all)
            
            // 3. UI Overlay Controls
            VStack {
                // Top Header with Back Button and Setup Status
                HStack {
                    Button(action: {
                        coordinator.resetToHome()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.displayName.uppercased())
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(viewType.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.leading, 8)
                    
                    Spacer()
                    
                    if let validation = coordinator.setupValidation {
                        StatusBadge(level: validation.poseConfidence.level)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Guidance Prompts Banner
                if let validation = coordinator.setupValidation, !validation.feedbackPrompts.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(validation.feedbackPrompts, id: \.self) { prompt in
                            Text(prompt)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(12)
                    .padding(.top, 8)
                }
                
                Spacer()
                
                // Checklist HUD
                if let validation = coordinator.setupValidation {
                    HStack(spacing: 12) {
                        FramingCheckItem(title: "Full Body", isValid: validation.isFullBodyVisible)
                        FramingCheckItem(title: "Feet in View", isValid: validation.areFeetVisible)
                        FramingCheckItem(title: "Optimal Scale", isValid: validation.isScaleOptimal)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(14)
                    .padding(.bottom, 16)
                }
                
                // Giant Start Button
                PrimaryGymButton(
                    title: isFramingReady ? "START RECORDING (3s)" : "ALIGN CAMERA TO START",
                    icon: "record.circle.fill",
                    color: isFramingReady ? .green : .gray,
                    action: {
                        coordinator.startCountdown()
                    }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            
            // 4. Countdown Overlay (if countdown is running)
            if case .countdown(_, _, let seconds) = coordinator.state {
                ZStack {
                    Color.black.opacity(0.8)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 16) {
                        Text("\(seconds)")
                            .font(.system(size: 120, weight: .heavy, design: .rounded))
                            .foregroundColor(.green)
                            .shadow(color: .green.opacity(0.5), radius: 20)
                        
                        Text("GET READY")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .tracking(3.0)
                    }
                }
                .transition(.opacity)
            }
        }
    }
    
    private var isFramingReady: Bool {
        coordinator.setupValidation?.isReady ?? false
    }
}

struct FramingCheckItem: View {
    let title: String
    let isValid: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(isValid ? .green : .orange)
                .font(.system(size: 14))
            
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}
