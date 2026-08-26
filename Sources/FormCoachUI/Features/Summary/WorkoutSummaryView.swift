import SwiftUI
import FormCoachCore

public struct WorkoutSummaryView: View {
    public let sessionAnalysis: WorkoutSessionAnalysis
    public let onDone: () -> Void
    
    public init(
        sessionAnalysis: WorkoutSessionAnalysis,
        onDone: @escaping () -> Void
    ) {
        self.sessionAnalysis = sessionAnalysis
        self.onDone = onDone
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("WORKOUT COMPLETE")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(.green)
                        .tracking(1.5)
                    
                    Text("\(sessionAnalysis.exerciseType.displayName) Session")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("\(sessionAnalysis.totalSets) sets • \(sessionAnalysis.totalReps) total reps logged")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Session Fatigue & Trajectory Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SESSION FATIGUE INDEX")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.gray)
                            
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(Int(sessionAnalysis.fatigueIndex))")
                                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                                    .foregroundColor(fatigueColor)
                                
                                Text("/100")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()
                        
                        Text(trendText.uppercased())
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundColor(fatigueColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(fatigueColor.opacity(0.15))
                            .cornerRadius(10)
                    }
                    
                    if let decay = sessionAnalysis.romDecayPercent {
                        Text(decay < -8 ? "Depth decreased by ~\(Int(abs(decay)))% from opening to closing sets." : "Depth remained stable across all sets.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(18)
                .background(Color(white: 0.12))
                .cornerRadius(16)
                .padding(.horizontal, 20)
                
                // Set-by-Set Trajectory Comparison
                VStack(alignment: .leading, spacing: 12) {
                    Text("SET-BY-SET PROGRESSION")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 10) {
                        ForEach(sessionAnalysis.setTrends) { trend in
                            HStack {
                                Text("SET \(trend.setNumber)")
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(width: 55, alignment: .leading)
                                
                                Spacer()
                                
                                Text("\(trend.repCount) reps")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.gray)
                                
                                Text("Depth: \(Int(trend.meanROM))°")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.green)
                                    .frame(width: 90, alignment: .trailing)
                                
                                Text("Score: \(Int(trend.qualityScore))")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.yellow)
                                    .frame(width: 75, alignment: .trailing)
                            }
                            .padding(14)
                            .background(Color(white: 0.12))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Session Observations
                if !sessionAnalysis.sessionObservations.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SESSION FINDINGS")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                        
                        ForEach(sessionAnalysis.sessionObservations) { obs in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(obs.title)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text(obs.detail)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(white: 0.10))
                    .cornerRadius(14)
                    .padding(.horizontal, 20)
                }
                
                // Finish Button
                PrimaryGymButton(
                    title: "DONE & RETURN HOME",
                    icon: "checkmark.circle.fill",
                    color: .green,
                    action: onDone
                )
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
    
    private var fatigueColor: Color {
        if sessionAnalysis.fatigueIndex <= 25.0 {
            return .green
        } else if sessionAnalysis.fatigueIndex <= 50.0 {
            return .yellow
        } else {
            return .orange
        }
    }
    
    private var trendText: String {
        switch sessionAnalysis.romTrend {
        case .stable: return "Stable Endurance"
        case .improving: return "Improving Depth"
        case .degrading: return "Fatigue Decay"
        }
    }
}
