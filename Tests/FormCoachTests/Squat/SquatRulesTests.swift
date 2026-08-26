import XCTest
@testable import FormCoachCore

final class SquatRulesTests: XCTestCase {
    
    func testFatigueROMDecayRuleTriggers() {
        let engine = FormRuleEngine(rules: SquatRules.standardRules)
        
        let reps: [Repetition] = (1...10).map { i in
            let depth = i <= 4 ? 80.0 : (i >= 7 ? 115.0 : 95.0)
            return Repetition(
                index: i,
                startTime: Double(i) * 3.0,
                inflectionTime: Double(i) * 3.0 + 1.5,
                endTime: Double(i) * 3.0 + 3.0,
                eccentricDuration: 1.5,
                pauseDuration: 0.2,
                concentricDuration: 1.3,
                primaryROM: depth,
                confidence: 0.95
            )
        }
        
        let context = SetAnalysisContext(
            exerciseType: .squat,
            reps: reps,
            cameraView: .side,
            trackingConfidence: PoseConfidence(overallScore: 0.95, level: .good, visibleJointRatio: 1.0, meanJointConfidence: 0.95),
            meanROM: 95.0,
            meanDuration: 3.0,
            earlyLateROMDelta: -35.0,
            earlyLateTempoDelta: 0.0
        )
        
        let observations = engine.evaluate(context: context)
        
        let decayObs = observations.first(where: { $0.id == "squat.rom.decay" })
        XCTAssertNotNil(decayObs, "Fatigue ROM decay rule must trigger when late-set depth drops by > 9%")
        XCTAssertEqual(decayObs?.severity, .warning)
    }
}
