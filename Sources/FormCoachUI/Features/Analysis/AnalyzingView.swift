import SwiftUI
import FormCoachCore

public struct AnalyzingView: View {
    let exercise: ExerciseType
    let progressText: String
    
    public init(exercise: ExerciseType, progressText: String) {
        self.exercise = exercise
        self.progressText = progressText
    }
    
    public var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 28) {
                // Animated Kinetic Spinner
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 6)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0.0, to: 0.7)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(360))
                        .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: progressText)
                }
                
                VStack(spacing: 8) {
                    Text("ANALYZING SET")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(2.0)
                    
                    Text(progressText)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Privacy / Local Verification Badge
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.green)
                    
                    Text("100% On-Device Deterministic Processing")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                }
                .padding(.top, 16)
            }
        }
    }
}
