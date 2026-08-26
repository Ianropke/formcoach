import XCTest
@testable import FormCoachCore

final class SquatRepSegmenterTests: XCTestCase {
    
    func testClean10RepsSegmentation() {
        let segmenter = SquatRepSegmenter()
        let timeSeries = SyntheticSquatGenerator.generateSquatSet(
            repCount: 10,
            fps: 30.0,
            standingKneeAngle: 175.0,
            bottomKneeAngles: Array(repeating: 85.0, count: 10),
            repDuration: 2.5,
            standingPauseDuration: 0.8
        )
        
        let reps = segmenter.segment(timeSeries: timeSeries, view: .side)
        
        XCTAssertEqual(reps.count, 10, "Should segment exactly 10 clean repetitions")
        
        for (i, rep) in reps.enumerated() {
            XCTAssertEqual(rep.index, i + 1)
            XCTAssertLessThanOrEqual(rep.primaryROM, 90.0, "Rep \(rep.index) should reach ~85° depth")
            XCTAssertGreaterThanOrEqual(rep.duration, 2.0, "Rep duration should be realistic")
        }
    }
    
    func testIncompleteFinalRepIgnored() {
        let segmenter = SquatRepSegmenter()
        
        // 5 clean reps
        var fullSeries = SyntheticSquatGenerator.generateSquatSet(
            repCount: 5,
            fps: 30.0,
            standingKneeAngle: 175.0,
            bottomKneeAngles: Array(repeating: 85.0, count: 5),
            repDuration: 2.5
        )
        
        // Add an aborted descent at the end that never recovers
        var frames = fullSeries.frames
        let lastTime = frames.last?.timestamp ?? 0.0
        for f in 0..<30 {
            let t = lastTime + (Double(f) / 30.0)
            let angle = 175.0 - (40.0 * (Double(f) / 30.0)) // Descents to 135° and cuts off
            frames.append(SyntheticSquatGenerator.createSquatFrame(timestamp: t, kneeAngle: angle))
        }
        
        let incompleteSeries = PoseTimeSeries(frames: frames, fps: 30.0)
        let reps = segmenter.segment(timeSeries: incompleteSeries, view: .side)
        
        XCTAssertEqual(reps.count, 5, "Incomplete final rep must not be counted as a completed rep")
    }
}
