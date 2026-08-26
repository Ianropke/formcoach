import SwiftUI
import FormCoachCore

public struct RecordingView: View {
    @ObservedObject var coordinator: WorkoutSessionCoordinator
    let exercise: ExerciseType
    let viewType: CameraViewType
    let startTime: Date
    
    @State private var elapsedTime: TimeInterval = 0.0
    @State private var isBlinking = false
    
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    public init(
        coordinator: WorkoutSessionCoordinator,
        exercise: ExerciseType,
        viewType: CameraViewType,
        startTime: Date
    ) {
        self.coordinator = coordinator
        self.exercise = exercise
        self.viewType = viewType
        self.startTime = startTime
    }
    
    public var body: some View {
        ZStack {
            // 1. Live Camera Feed
            CameraPreviewView(session: coordinator.cameraService.captureSession)
                .edgesIgnoringSafeArea(.all)
            
            // 2. Real-time Skeleton Overlay
            SkeletonCanvasView(
                poseFrame: coordinator.livePoseFrame,
                jointColor: .green
            )
            .edgesIgnoringSafeArea(.all)
            
            // 3. Gym HUD Overlay
            VStack {
                // Top Status Bar (REC indicator + Elapsed Timer)
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                            .opacity(isBlinking ? 0.3 : 1.0)
                        
                        Text("REC")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                    
                    Spacer()
                    
                    Text(formattedTime(elapsedTime))
                        .font(.system(size: 18, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                // Exercise Label
                Text(exercise.displayName.uppercased())
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(10)
                    .padding(.bottom, 12)
                
                // Giant Stop Button
                PrimaryGymButton(
                    title: "STOP RECORDING",
                    icon: "stop.fill",
                    color: .red,
                    action: {
                        coordinator.stopRecording()
                    }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .onReceive(timer) { now in
            elapsedTime = now.timeIntervalSince(startTime)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isBlinking = true
            }
        }
    }
    
    private func formattedTime(_ interval: TimeInterval) -> String {
        let mins = Int(interval) / 60
        let secs = Int(interval) % 60
        let tenths = Int((interval.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", mins, secs, tenths)
    }
}
