import SwiftUI
import FormCoachCore

public struct ExerciseSelectionView: View {
    @ObservedObject var coordinator: WorkoutSessionCoordinator
    @State private var selectedCategory: ExerciseCategory? = nil // nil = All
    @State private var selectedExercise: ExerciseType = .squat
    @State private var selectedView: CameraViewType = .side
    
    public init(coordinator: WorkoutSessionCoordinator) {
        self.coordinator = coordinator
    }
    
    private var filteredExercises: [ExerciseType] {
        if let cat = selectedCategory {
            return ExerciseType.allCases.filter { $0.category == cat }
        }
        return ExerciseType.allCases
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("FORMCOACH")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(.green)
                    .tracking(2.0)
                
                Text("Select Exercise")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 10)
            
            // Category Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button(action: { selectedCategory = nil }) {
                        Text("All")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(selectedCategory == nil ? .black : .white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedCategory == nil ? Color.green : Color(white: 0.16))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    ForEach(ExerciseCategory.allCases) { cat in
                        Button(action: { selectedCategory = cat }) {
                            HStack(spacing: 4) {
                                Text(cat.icon)
                                Text(cat.rawValue)
                            }
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(selectedCategory == cat ? .black : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedCategory == cat ? Color.green : Color(white: 0.16))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
            
            // Exercise Cards List
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(filteredExercises) { exercise in
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
                .padding(.vertical, 2)
            }
            
            // Camera View Selector
            VStack(alignment: .leading, spacing: 8) {
                Text("RECOMMENDED CAMERA ANGLE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                
                HStack(spacing: 8) {
                    ForEach(selectedExercise.supportedViews, id: \.self) { viewType in
                        Button(action: {
                            selectedView = viewType
                        }) {
                            Text(viewType.rawValue)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(selectedView == viewType ? .black : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedView == viewType ? Color.green : Color(white: 0.18))
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Start Setup CTA
            PrimaryGymButton(
                title: "Setup \(selectedExercise.displayName) Camera",
                icon: "camera.fill",
                color: .green,
                action: {
                    coordinator.state = .cameraSetup(exercise: selectedExercise, view: selectedView)
                    coordinator.cameraService.startSession()
                }
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
}

struct ExerciseCard: View {
    let exercise: ExerciseType
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(exercise.displayName)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(exercise.subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Text("ACTIVE")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.green)
                        .cornerRadius(6)
                }
                
                // Key metrics list tags
                HStack(spacing: 5) {
                    ForEach(exercise.keyMetricsList, id: \.self) { metric in
                        Text(metric)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(5)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color(white: 0.16) : Color(white: 0.10))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.green : Color.white.opacity(0.06), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
