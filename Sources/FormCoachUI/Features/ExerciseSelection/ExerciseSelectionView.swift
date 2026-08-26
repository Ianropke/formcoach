import SwiftUI
import FormCoachCore

public struct ExerciseSelectionView: View {
    @ObservedObject var coordinator: WorkoutSessionCoordinator
    @State private var selectedExercise: ExerciseType = .squat
    @State private var selectedView: CameraViewType = .side
    
    public init(coordinator: WorkoutSessionCoordinator) {
        self.coordinator = coordinator
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("FORMCOACH")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(.green)
                    .tracking(2.0)
                
                Text("Select Exercise")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
            
            // Exercise Cards Carousel / List
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    ForEach(ExerciseType.allCases) { exercise in
                        ExerciseCard(
                            exercise: exercise,
                            isSelected: selectedExercise == exercise,
                            onSelect: {
                                selectedExercise = exercise
                                selectedView = exercise.recommendedView
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Camera View Selector
            VStack(alignment: .leading, spacing: 10) {
                Text("CAMERA ANGLE")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                
                HStack(spacing: 10) {
                    ForEach(selectedExercise.supportedViews, id: \.self) { viewType in
                        Button(action: {
                            selectedView = viewType
                        }) {
                            Text(viewType.rawValue)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(selectedView == viewType ? .black : .white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(selectedView == viewType ? Color.green : Color(white: 0.18))
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Start Setup CTA
            PrimaryGymButton(
                title: "Setup Camera & Position",
                icon: "camera.fill",
                color: selectedExercise.isM1Available ? .green : .gray,
                action: {
                    guard selectedExercise.isM1Available else { return }
                    coordinator.state = .cameraSetup(exercise: selectedExercise, view: selectedView)
                    coordinator.cameraService.startSession()
                }
            )
            .disabled(!selectedExercise.isM1Available)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
}

struct ExerciseCard: View {
    let exercise: ExerciseType
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.displayName)
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(exercise.subtitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    if exercise.isM1Available {
                        Text("ACTIVE")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green)
                            .cornerRadius(6)
                    } else {
                        Text("COMING SOON")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(white: 0.2))
                            .cornerRadius(6)
                    }
                }
                
                // Key metrics list tags
                HStack(spacing: 6) {
                    ForEach(exercise.keyMetricsList, id: \.self) { metric in
                        Text(metric)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color(white: 0.16) : Color(white: 0.10))
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? Color.green : Color.white.opacity(0.06), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
