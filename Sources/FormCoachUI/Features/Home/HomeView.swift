import SwiftUI
import FormCoachCore

public struct HomeView: View {
    @StateObject private var coordinator = WorkoutSessionCoordinator()
    @State private var selectedTab = 0
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Main Flow Routing
            switch coordinator.state {
            case .idle, .exerciseSelection:
                TabView(selection: $selectedTab) {
                    ExerciseSelectionView(coordinator: coordinator)
                        .tabItem {
                            Label("Analyze", systemImage: "figure.strengthtraining.traditional")
                        }
                        .tag(0)
                    
                    HistoryView()
                        .tabItem {
                            Label("History", systemImage: "clock.arrow.circlepath")
                        }
                        .tag(1)
                    
                    LongitudinalTrendsView()
                        .tabItem {
                            Label("Baselines", systemImage: "chart.line.uptrend.xyaxis")
                        }
                        .tag(2)
                    
                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gearshape")
                        }
                        .tag(3)
                }
                .accentColor(.green)
                
            case .cameraSetup(let exercise, let viewType):
                CameraSetupView(
                    coordinator: coordinator,
                    exercise: exercise,
                    viewType: viewType
                )
                
            case .countdown(let exercise, let viewType, _):
                CameraSetupView(
                    coordinator: coordinator,
                    exercise: exercise,
                    viewType: viewType
                )
                
            case .recording(let exercise, let viewType, let startTime):
                RecordingView(
                    coordinator: coordinator,
                    exercise: exercise,
                    viewType: viewType,
                    startTime: startTime
                )
                
            case .analyzing(let exercise, let progressText):
                AnalyzingView(
                    exercise: exercise,
                    progressText: progressText
                )
                
            case .results(let setId, let exercise, let viewType):
                ResultsView(
                    coordinator: coordinator,
                    setId: setId,
                    exercise: exercise,
                    viewType: viewType
                )
                
            case .workoutSummary(let sessionAnalysis):
                WorkoutSummaryView(
                    sessionAnalysis: sessionAnalysis,
                    onDone: {
                        coordinator.resetToHome()
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
    }
}
