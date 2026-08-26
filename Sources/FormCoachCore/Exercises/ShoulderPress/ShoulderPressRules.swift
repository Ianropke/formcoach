import Foundation

/// Heuristic explainable rules for Shoulder Press analysis
public struct ShoulderPressRules: Sendable {
    
    public static let standardRules: [BiomechanicalRule] = [
        // 1. Bilateral Press Asymmetry
        BiomechanicalRule(
            id: "press.symmetry.asymmetry",
            title: "Bilateral Press Imbalance",
            severity: .warning,
            condition: { ctx in
                let meanAsymmetry = ctx.reps.reduce(0.0) { $0 + ($1.secondaryROM ?? 0.0) } / Double(max(1, ctx.reps.count))
                guard meanAsymmetry >= 12.0 else { return nil }
                
                let asymStr = String(format: "%.0f°", meanAsymmetry)
                let affected = ctx.reps.filter { ($0.secondaryROM ?? 0.0) >= 12.0 }.map { $0.index }
                
                return FormObservation(
                    id: "press.symmetry.asymmetry",
                    title: "Bilateral Arm Imbalance",
                    detail: "Observed an average \(asymStr) extension difference between left and right arms during overhead lockout.",
                    evidence: "Asymmetrical lockout detected on reps: \(affected.map(String.init).joined(separator: ", ")).",
                    severity: .warning,
                    affectedRepIndices: affected
                )
            }
        ),
        
        // 2. Strict Symmetrical Lockout
        BiomechanicalRule(
            id: "press.form.strict",
            title: "Symmetrical Overhead Lockout",
            severity: .positive,
            condition: { ctx in
                let meanAsymmetry = ctx.reps.reduce(0.0) { $0 + ($1.secondaryROM ?? 0.0) } / Double(max(1, ctx.reps.count))
                guard ctx.reps.count >= 5, meanAsymmetry < 6.0, ctx.meanROM >= 162.0 else { return nil }
                
                return FormObservation(
                    id: "press.form.strict",
                    title: "Excellent Symmetrical Lockout",
                    detail: "Clean overhead extension with balanced bilateral arm synchronization.",
                    evidence: "Arm asymmetry remained under 6° with full ~\(String(format: "%.0f°", ctx.meanROM)) lockout across all \(ctx.reps.count) reps.",
                    severity: .positive,
                    affectedRepIndices: ctx.reps.map { $0.index }
                )
            }
        ),
        
        // 3. Late-set Press Height Deterioration
        BiomechanicalRule(
            id: "press.rom.decay",
            title: "Decreased Late-Set Overhead Reach",
            severity: .warning,
            condition: { ctx in
                guard let delta = ctx.earlyLateROMDelta, delta <= -9.0 else { return nil }
                let percentStr = String(format: "%.0f%%", abs(delta))
                let lateCount = min(4, ctx.reps.count / 2)
                let affected = Array((ctx.reps.count - lateCount + 1)...ctx.reps.count)
                
                return FormObservation(
                    id: "press.rom.decay",
                    title: "Reduced Late-Set Lockout",
                    detail: "Overhead extension height decreased by ~\(percentStr) during the final repetitions.",
                    evidence: "Early reps achieved ~\(String(format: "%.0f°", ctx.meanROM)) extension vs incomplete lockout in reps \(affected.map(String.init).joined(separator: ", ")).",
                    severity: .warning,
                    affectedRepIndices: affected
                )
            }
        ),
        
        // 4. Incomplete Lockout
        BiomechanicalRule(
            id: "press.lockout.incomplete",
            title: "Incomplete Overhead Lockout",
            severity: .info,
            condition: { ctx in
                guard ctx.meanROM < 155.0 else { return nil }
                return FormObservation(
                    id: "press.lockout.incomplete",
                    title: "Partial Overhead Lockout",
                    detail: "Average elbow extension reached \(String(format: "%.0f°", ctx.meanROM)), stopping short of complete overhead lockout (~165°–175°).",
                    evidence: "Overhead apex remained at \(String(format: "%.0f°", ctx.meanROM)).",
                    severity: .info,
                    affectedRepIndices: ctx.reps.map { $0.index }
                )
            }
        )
    ]
}
