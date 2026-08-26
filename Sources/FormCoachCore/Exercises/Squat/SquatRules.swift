import Foundation

/// Heuristic explainable rules for Squat analysis
public struct SquatRules: Sendable {
    
    public static let standardRules: [BiomechanicalRule] = [
        // 1. Late-set ROM Deterioration
        BiomechanicalRule(
            id: "squat.rom.decay",
            title: "Decreased Late-Set Depth",
            severity: .warning,
            condition: { ctx in
                guard let delta = ctx.earlyLateROMDelta, delta <= -9.0 else { return nil }
                let percentStr = String(format: "%.0f%%", abs(delta))
                let lateCount = min(4, ctx.reps.count / 2)
                let affected = Array((ctx.reps.count - lateCount + 1)...ctx.reps.count)
                
                return FormObservation(
                    id: "squat.rom.decay",
                    title: "Reduced Late-Set Depth",
                    detail: "Knee range of motion decreased by approximately \(percentStr) during the final repetitions.",
                    evidence: "Early reps averaged ~\(String(format: "%.0f°", ctx.meanROM)) knee flexion vs shallower angles in reps \(affected.map(String.init).joined(separator: ", ")).",
                    severity: .warning,
                    affectedRepIndices: affected
                )
            }
        ),
        
        // 2. High Consistency & Solid Depth
        BiomechanicalRule(
            id: "squat.consistency.high",
            title: "Consistent Movement Pattern",
            severity: .positive,
            condition: { ctx in
                guard ctx.reps.count >= 5, (ctx.earlyLateROMDelta.map { abs($0) < 6.0 } ?? false), ctx.meanROM <= 100.0 else { return nil }
                return FormObservation(
                    id: "squat.consistency.high",
                    title: "Excellent Depth Consistency",
                    detail: "Repetition depth and tempo remained uniform across the entire set.",
                    evidence: "Range of motion varied by less than 6% between initial and closing repetitions.",
                    severity: .positive,
                    affectedRepIndices: ctx.reps.map { $0.index }
                )
            }
        ),
        
        // 3. Shallow Squat Depth
        BiomechanicalRule(
            id: "squat.rom.shallow",
            title: "Shallow Squat Depth",
            severity: .info,
            condition: { ctx in
                guard ctx.meanROM > 115.0 else { return nil }
                return FormObservation(
                    id: "squat.rom.shallow",
                    title: "Above Parallel Depth",
                    detail: "Average knee flexion was \(String(format: "%.0f°", ctx.meanROM)), remaining above parallel.",
                    evidence: "Knee angle reached \(String(format: "%.0f°", ctx.meanROM)) (target is ~90°–100° for full depth).",
                    severity: .info,
                    affectedRepIndices: ctx.reps.map { $0.index }
                )
            }
        ),
        
        // 4. Late-set Tempo Acceleration (Rushing)
        BiomechanicalRule(
            id: "squat.tempo.rushed",
            title: "Faster Late-Set Tempo",
            severity: .info,
            condition: { ctx in
                guard let tempoDelta = ctx.earlyLateTempoDelta, tempoDelta <= -20.0 else { return nil }
                let percentStr = String(format: "%.0f%%", abs(tempoDelta))
                return FormObservation(
                    id: "squat.tempo.rushed",
                    title: "Repetition Speed Increased",
                    detail: "Repetition duration became ~\(percentStr) faster toward the end of the set.",
                    evidence: "Eccentric control decreased in later reps.",
                    severity: .info,
                    affectedRepIndices: []
                )
            }
        )
    ]
}
