import SwiftUI
import FormCoachCore

public struct RepetitionTimelineView: View {
    public let reps: [Repetition]
    public let selectedRepIndex: Int?
    public let onSelectRep: (Repetition) -> Void
    
    public init(
        reps: [Repetition],
        selectedRepIndex: Int?,
        onSelectRep: @escaping (Repetition) -> Void
    ) {
        self.reps = reps
        self.selectedRepIndex = selectedRepIndex
        self.onSelectRep = onSelectRep
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("REPETITION TIMELINE")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(reps) { rep in
                        RepTimelineCard(
                            rep: rep,
                            isSelected: selectedRepIndex == rep.index,
                            onTap: { onSelectRep(rep) }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct RepTimelineCard: View {
    let rep: Repetition
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("REP \(rep.index)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(statusLabel)
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.15))
                        .cornerRadius(6)
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DEPTH")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.gray)
                        Text("\(Int(rep.primaryROM))°")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TEMPO")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.gray)
                        Text(String(format: "%.1fs", rep.duration))
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(12)
            .frame(width: 145)
            .background(isSelected ? Color(white: 0.20) : Color(white: 0.12))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.green : Color.white.opacity(0.06), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var statusLabel: String {
        if rep.primaryROM <= 100.0 {
            return "GOOD"
        } else if rep.primaryROM <= 112.0 {
            return "PARALLEL"
        } else {
            return "ROM ↓"
        }
    }
    
    private var statusColor: Color {
        if rep.primaryROM <= 100.0 {
            return .green
        } else if rep.primaryROM <= 112.0 {
            return .yellow
        } else {
            return .orange
        }
    }
}
