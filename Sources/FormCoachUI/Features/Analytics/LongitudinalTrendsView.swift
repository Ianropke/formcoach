import SwiftUI
import FormCoachCore

public struct LongitudinalTrendsView: View {
    @ObservedObject private var persistence = PersistenceController.shared
    @State private var selectedExercise: ExerciseType = .squat
    
    public init() {}
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("LONGITUDINAL ANALYTICS")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(.green)
                        .tracking(1.5)
                    
                    Text("Personal Baselines")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Exercise Picker Tabs
                HStack(spacing: 10) {
                    ForEach([ExerciseType.squat, ExerciseType.bicepsCurl]) { exercise in
                        Button(action: { selectedExercise = exercise }) {
                            Text(exercise.displayName)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(selectedExercise == exercise ? .black : .white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(selectedExercise == exercise ? Color.green : Color(white: 0.16))
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                
                // Personal Baseline Card
                let baseline = PersonalBaselineEngine.computeBaseline(
                    sets: persistence.sets,
                    exerciseType: selectedExercise
                )
                
                PersonalBaselineCard(baseline: baseline)
                    .padding(.horizontal, 20)
                
                // Historical Sets Progression List
                let exerciseSets = persistence.sets.filter { $0.exerciseType == selectedExercise }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("HISTORICAL SET PROGRESSION")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 20)
                    
                    if exerciseSets.isEmpty {
                        VStack(spacing: 8) {
                            Text("No sets recorded for \(selectedExercise.displayName) yet.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(Color(white: 0.10))
                        .cornerRadius(14)
                        .padding(.horizontal, 20)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(exerciseSets) { setModel in
                                let comp = PersonalBaselineEngine.compareSet(setModel: setModel, baseline: baseline)
                                HistoricalSetProgressionRow(setModel: setModel, comparison: comp)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
}

struct PersonalBaselineCard: View {
    let baseline: PersonalBaseline
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: baseline.hasSufficientData ? "person.crop.circle.badge.checkmark" : "hourglass")
                        .foregroundColor(baseline.hasSufficientData ? .green : .orange)
                    
                    Text(baseline.hasSufficientData ? "INDIVIDUAL BASELINE" : "CALIBRATING BASELINE")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(baseline.hasSufficientData ? .green : .orange)
                        .tracking(1.2)
                }
                
                Spacer()
                
                Text("\(baseline.sessionsCount) SETS LOGGED")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
            }
            
            if baseline.hasSufficientData {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NORMAL RANGE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                        
                        Text("~\(Int(baseline.baselineROMMean))° ±\(Int(baseline.baselineROMStdDev))°")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    Divider().frame(height: 35).background(Color.white.opacity(0.1))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PERSONAL BEST")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                        
                        Text("\(Int(baseline.personalBestROM))°")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(.green)
                    }
                }
            }
            
            Text(baseline.statusMessage)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(3)
        }
        .padding(18)
        .background(Color(white: 0.12))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(baseline.hasSufficientData ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

struct HistoricalSetProgressionRow: View {
    let setModel: ExerciseSetModel
    let comparison: BaselineComparisonResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formattedDate(setModel.recordedAt))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(setModel.repCount) REPS")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(.green)
            }
            
            Text(comparison.insightText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(14)
        .background(Color(white: 0.12))
        .cornerRadius(12)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
