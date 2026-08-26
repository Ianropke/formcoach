import XCTest
@testable import FormCoachCore

final class SquatMetricsTests: XCTestCase {
    
    func testEarlyLateROMDeltaCalculation() {
        // Create 10 reps where first 4 are deep (80°) and last 4 are shallow (115°)
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
        
        let delta = SquatMetrics.computeEarlyLateROMDelta(reps: reps)
        XCTAssertNotNil(delta)
        
        // Early ROM = 180 - 80 = 100°
        // Late ROM = 180 - 115 = 65°
        // Delta = (65 - 100) / 100 = -35%
        XCTAssertEqual(delta!, -35.0, accuracy: 2.0, "Should detect ~35% decrease in ROM")
    }
    
    func testConsistencyScoreUniformReps() {
        let uniformReps: [Repetition] = (1...8).map { i in
            Repetition(
                index: i,
                startTime: Double(i) * 3.0,
                inflectionTime: Double(i) * 3.0 + 1.5,
                endTime: Double(i) * 3.0 + 3.0,
                eccentricDuration: 1.5,
                pauseDuration: 0.2,
                concentricDuration: 1.3,
                primaryROM: 85.0, // Identical depth
                confidence: 0.95
            )
        }
        
        let score = SquatMetrics.computeConsistencyScore(reps: uniformReps)
        XCTAssertGreaterThanOrEqual(score, 98.0, "Uniform reps should score near 100 consistency")
    }
}
