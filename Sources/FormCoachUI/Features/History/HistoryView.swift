import SwiftUI
import FormCoachCore

public struct HistoryView: View {
    @ObservedObject private var persistence = PersistenceController.shared
    @State private var selectedSet: ExerciseSetModel?
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TRAINING HISTORY")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(.green)
                        .tracking(1.5)
                    
                    Text("Recorded Sets")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("\(persistence.sets.count) SETS")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(white: 0.15))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 16)
            
            if persistence.sets.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("No Recorded Sets Yet")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Record a squat set to see deterministic form analysis and historical rep breakdowns here.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Spacer()
            } else {
                List {
                    ForEach(persistence.sets) { setModel in
                        HistorySetRow(setModel: setModel)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedSet = setModel
                            }
                            .listRowBackground(Color.black)
                            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    }
                    .onDelete(perform: deleteSets)
                }
                .listStyle(.plain)
                .background(Color.black)
            }
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .sheet(item: $selectedSet) { setModel in
            SetDetailView(setModel: setModel)
        }
    }
    
    private func deleteSets(at offsets: IndexSet) {
        for index in offsets {
            let setModel = persistence.sets[index]
            try? persistence.deleteSet(setModel: setModel)
        }
    }
}

struct HistorySetRow: View {
    let setModel: ExerciseSetModel
    
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(setModel.exerciseType.displayName)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                
                Text(formattedDate(setModel.recordedAt))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(setModel.repCount) REPS")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(.green)
                
                Text(setModel.cameraView.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(Color(white: 0.12))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

public struct SetDetailView: View {
    let setModel: ExerciseSetModel
    @Environment(\.dismiss) private var dismiss
    @State private var timeSeries: PoseTimeSeries?
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Metrics
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(setModel.exerciseType.displayName.uppercased())
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("\(setModel.repCount) reps • \(setModel.cameraView.rawValue)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // Rep Breakdown List
                    VStack(alignment: .leading, spacing: 10) {
                        Text("REPETITION BREAKDOWN")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                        
                        ForEach(setModel.reps.sorted(by: { $0.index < $1.index })) { rep in
                            HStack {
                                Text("Rep \(rep.index)")
                                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text("Depth: \(Int(rep.primaryROM))°")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.green)
                                
                                Text("Tempo: \(String(format: "%.1fs", rep.duration))")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.gray)
                                    .padding(.leading, 8)
                            }
                            .padding(14)
                            .background(Color(white: 0.12))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Main Observation
                    if let analysis = setModel.analysis {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SAVED OBSERVATION")
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundColor(.green)
                            
                            Text(analysis.primaryObservation)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(white: 0.10))
                        .cornerRadius(14)
                        .padding(.horizontal, 20)
                    }
                }
            }
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.green)
                }
            }
        }
    }
}
