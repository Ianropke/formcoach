import Foundation

/// Heuristic explainable rules for Biceps Curl analysis
public struct BicepsCurlRules: Sendable {
    
    public static let standardRules: [BiomechanicalRule] = [
        // 1. Excessive Shoulder Drift / Momentum Cheating
        BiomechanicalRule(
            id: "curl.shoulder.drift",
            title: "Upper Arm Momentum / Shoulder Swing",
            severity: .warning,
            condition: { ctx in
                let meanDrift = ctx.reps.reduce(0.0) { $0 + ($1.secondaryROM ?? 0.0) } / Double(max(1, ctx.reps.count))
                guard meanDrift >= 18.0 else { return nil }
                
                let driftStr = String(format: "%.0f°", meanDrift)
                let swingingReps = ctx.reps.filter { ($0.secondaryROM ?? 0.0) >= 18.0 }.map { $0.index }
                
                return FormObservation(
                    id: "curl.shoulder.drift",
                    title: "Shoulder Momentum Detected",
                    detail: "Upper arm drifted forward by an average of \(driftStr), indicating momentum assistance rather than isolated elbow flexion.",
                    evidence: "Elbow moved forward from torso alignment during reps: \(swingingReps.map(String.init).joined(separator: ", ")). Keep elbows pinned to torso.",
                    severity: .warning,
                    affectedRepIndices: swingingReps
                )
            }
        ),
        
        // 2. Strict Form & Stable Elbows
        BiomechanicalRule(
            id: "curl.form.strict",
            title: "Strict Elbow Isolation",
            severity: .positive,
            condition: { ctx in
                let meanDrift = ctx.reps.reduce(0.0) { $0 + ($1.secondaryROM ?? 0.0) } / Double(max(1, ctx.reps.count))
                guard ctx.reps.count >= 5, meanDrift < 10.0, ctx.meanROM <= 68.0 else { return nil }
                
                return FormObservation(
                    id: "curl.form.strict",
                    title: "Excellent Elbow Isolation",
                    detail: "Strict technique with minimal shoulder movement and full peak contraction.",
                    evidence: "Upper arm drift stayed below 10° across all \(ctx.reps.count) repetitions.",
                    severity: .positive,
                    affectedRepIndices: ctx.reps.map { $0.index }
                )
            }
        ),
        
        // 3. Late-set ROM Deterioration
        BiomechanicalRule(
            id: "curl.rom.decay",
            title: "Decreased Late-Set Curl Height",
            severity: .warning,
            condition: { ctx in
                guard let delta = ctx.earlyLateROMDelta, delta <= -9.0 else { return nil }
                let percentStr = String(format: "%.0f%%", abs(delta))
                let lateCount = min(4, ctx.reps.count / 2)
                let affected = Array((ctx.reps.count - lateCount + 1)...ctx.reps.count)
                
                return FormObservation(
                    id: "curl.rom.decay",
                    title: "Reduced Late-Set Flexion",
                    detail: "Peak elbow flexion ROM decreased by ~\(percentStr) during the final repetitions.",
                    evidence: "Early reps achieved ~\(String(format: "%.0f°", ctx.meanROM)) peak flexion vs shallower curls in reps \(affected.map(String.init).joined(separator: ", ")).",
                    severity: .warning,
                    affectedRepIndices: affected
                )
            }
        ),
        
        // 4. Incomplete Flexion / Partial Reps
        BiomechanicalRule(
            id: "curl.rom.partial",
            title: "Incomplete Peak Contraction",
            severity: .info,
            condition: { ctx in
                guard ctx.meanROM > 80.0 else { return nil }
                return FormObservation(
                    id: "curl.rom.partial",
                    title: "Partial Contraction Depth",
                    detail: "Average peak elbow flexion was \(String(format: "%.0f°", ctx.meanROM)), stopping short of full contraction (~55°–65°).",
                    evidence: "Curl apex remained at \(String(format: "%.0f°", ctx.meanROM)).",
                    severity: .info,
                    affectedRepIndices: ctx.reps.map { $0.index }
                )
            }
        )
    ]
}
