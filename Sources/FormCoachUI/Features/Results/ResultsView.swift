import SwiftUI
import FormCoachCore

public struct ResultsView: View {
    @ObservedObject var coordinator: WorkoutSessionCoordinator
    let setId: UUID
    let exercise: ExerciseType
    let viewType: CameraViewType
    
    @State private var currentPlaybackTime: TimeInterval = 0.0
    @State private var selectedRepIndex: Int?
    
    public init(
        coordinator: WorkoutSessionCoordinator,
        setId: UUID,
        exercise: ExerciseType,
        viewType: CameraViewType
    ) {
        self.coordinator = coordinator
        self.setId = setId
        self.exercise = exercise
        self.viewType = viewType
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // Top Navigation Bar
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.displayName.uppercased())
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("\(coordinator.currentReps.count) reps detected • \(viewType.rawValue)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    if let analysis = coordinator.currentAnalysis {
                        StatusBadge(level: analysis.trackingConfidence.level)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Video & Skeleton Replay
                VideoPosePlayerView(
                    videoURL: coordinator.currentVideoURL,
                    timeSeries: coordinator.currentTimeSeries,
                    currentPlaybackTime: $currentPlaybackTime
                )
                .padding(.horizontal, 20)
                
                // Repetition Timeline Scrub Bar
                if !coordinator.currentReps.isEmpty {
                    RepetitionTimelineView(
                        reps: coordinator.currentReps,
                        selectedRepIndex: selectedRepIndex,
                        onSelectRep: { rep in
                            selectedRepIndex = rep.index
                            currentPlaybackTime = rep.inflectionTime
                        }
                    )
                }
                
                // Primary Explainable Observation Card
                if let analysis = coordinator.currentAnalysis {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkle.magnifyingglass")
                                .foregroundColor(.green)
                            
                            Text("KEY FINDING")
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundColor(.green)
                                .tracking(1.5)
                        }
                        
                        Text(analysis.primaryObservation)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineSpacing(4)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(white: 0.12))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                }
                
                // Core Kinematic Metric Cards Grid
                if let analysis = coordinator.currentAnalysis {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("KINEMATIC METRICS")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            MetricCard(
                                title: "Range of Motion",
                                value: "\(Int(analysis.romScore))",
                                unit: "/100",
                                subtitle: "Avg depth ~\(Int(analysis.meanROM))°"
                            )
                            
                            MetricCard(
                                title: "Consistency",
                                value: "\(Int(analysis.consistencyScore))",
                                unit: "/100",
                                subtitle: analysis.earlyLateROMDeltaPercent.map {
                                    $0 < -6 ? "Late ROM \($0 < 0 ? "-" : "+")\(Int(abs($0)))%" : "Stable ROM across set"
                                } ?? "Even reps"
                            )
                            
                            MetricCard(
                                title: "Tempo Control",
                                value: "\(Int(analysis.tempoScore))",
                                unit: "/100",
                                subtitle: "\(String(format: "%.1f", analysis.meanDuration))s avg per rep"
                            )
                            
                            MetricCard(
                                title: "Symmetry",
                                value: analysis.symmetryScore.map { "\(Int($0))" } ?? "N/A",
                                unit: analysis.symmetryScore != nil ? "/100" : nil,
                                subtitle: analysis.symmetryScore != nil ? "Left vs Right" : "Requires Front View"
                            )
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                // Additional Evidence Observations
                if let analysis = coordinator.currentAnalysis, analysis.observations.count > 1 {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("DETAILED OBSERVATIONS")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                        
                        ForEach(analysis.observations.dropFirst()) { obs in
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(obsColor(for: obs.severity))
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 5)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(obs.title)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    
                                    Text(obs.detail)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.gray)
                                    
                                    Text(obs.evidence)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.gray.opacity(0.8))
                                        .padding(.top, 2)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(white: 0.10))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                }
                
                // Multi-Set Session Flow Buttons
                VStack(spacing: 12) {
                    PrimaryGymButton(
                        title: "LOG NEXT SET (SET \(coordinator.activeWorkoutSets.count + 1))",
                        icon: "plus.circle.fill",
                        color: .green,
                        action: {
                            coordinator.logNextSet(exercise: exercise, view: viewType)
                        }
                    )
                    
                    if coordinator.activeWorkoutSets.count >= 2 {
                        PrimaryGymButton(
                            title: "FINISH WORKOUT & VIEW SUMMARY",
                            icon: "chart.bar.xaxis",
                            color: .blue,
                            action: {
                                coordinator.finishWorkout(exercise: exercise)
                            }
                        )
                    }
                    
                    Button(action: { coordinator.resetToHome() }) {
                        Text("Save & Return Home")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
    
    private func obsColor(for severity: ObservationSeverity) -> Color {
        switch severity {
        case .positive: return .green
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }
}
