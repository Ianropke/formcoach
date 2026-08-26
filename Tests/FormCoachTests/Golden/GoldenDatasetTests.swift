import XCTest
@testable import FormCoachCore

final class GoldenDatasetTests: XCTestCase {
    
    func testGoldenClean10RepsAnalysis() {
        let analyzer = SquatAnalyzer()
        let timeSeries = SyntheticSquatGenerator.generateSquatSet(
            repCount: 10,
            fps: 30.0,
            standingKneeAngle: 175.0,
            bottomKneeAngles: Array(repeating: 85.0, count: 10),
            repDuration: 2.6,
            standingPauseDuration: 0.6
        )
        
        let reps = analyzer.segmentReps(timeSeries: timeSeries, view: .side)
        XCTAssertEqual(reps.count, 10)
        
        let analysis = analyzer.analyzeSet(reps: reps, timeSeries: timeSeries, view: .side)
        XCTAssertEqual(analysis.repCount, 10)
        XCTAssertEqual(analysis.trackingConfidence.level, .good)
        XCTAssertGreaterThanOrEqual(analysis.overallQualityScore, 90.0)
        XCTAssertGreaterThanOrEqual(analysis.consistencyScore, 95.0)
    }
    
    func testGoldenFatigueDeteriorationAnalysis() {
        let analyzer = SquatAnalyzer()
        // 12 reps: first 6 are 80°, last 6 deteriorate to 120°
        var depths: [Double] = []
        for i in 0..<12 {
            depths.append(i < 6 ? 80.0 : 120.0)
        }
        
        let timeSeries = SyntheticSquatGenerator.generateSquatSet(
            repCount: 12,
            fps: 30.0,
            standingKneeAngle: 175.0,
            bottomKneeAngles: depths,
            repDuration: 2.5,
            standingPauseDuration: 0.6
        )
        
        let reps = analyzer.segmentReps(timeSeries: timeSeries, view: .side)
        XCTAssertEqual(reps.count, 12)
        
        let analysis = analyzer.analyzeSet(reps: reps, timeSeries: timeSeries, view: .side)
        XCTAssertEqual(analysis.repCount, 12)
        
        let decayObs = analysis.observations.first(where: { $0.id == "squat.rom.decay" })
        XCTAssertNotNil(decayObs, "Golden dataset with late fatigue must produce decay observation")
    }
}
