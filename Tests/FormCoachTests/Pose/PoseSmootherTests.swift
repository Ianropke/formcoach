import XCTest
import CoreGraphics
@testable import FormCoachCore

final class PoseSmootherTests: XCTestCase {
    
    func testShortGapInterpolation() {
        let smoother = PoseSmoother(alpha: 0.7, maxInterpolationGap: 3)
        
        let frame1 = SyntheticSquatGenerator.createSquatFrame(timestamp: 0.0, kneeAngle: 170.0)
        let frame2 = SyntheticSquatGenerator.createSquatFrame(timestamp: 0.033, kneeAngle: 0.0, isOccluded: true) // Missing
        let frame3 = SyntheticSquatGenerator.createSquatFrame(timestamp: 0.066, kneeAngle: 0.0, isOccluded: true) // Missing
        let frame4 = SyntheticSquatGenerator.createSquatFrame(timestamp: 0.099, kneeAngle: 150.0)
        
        let frames = [frame1, frame2, frame3, frame4]
        let smoothed = smoother.smooth(frames: frames)
        
        XCTAssertEqual(smoothed.count, 4)
        
        // Frame 2 and Frame 3 should now be interpolated and tracked
        let leftKneeFrame2 = smoothed[1].observation(for: .leftKnee)
        XCTAssertNotNil(leftKneeFrame2)
        XCTAssertTrue(leftKneeFrame2!.isTracked)
        XCTAssertTrue(smoothed[1].isInterpolated)
    }
    
    func testNoiseDampening() {
        let smoother = PoseSmoother(alpha: 0.5, maxInterpolationGap: 2)
        
        let frame1 = SyntheticSquatGenerator.createSquatFrame(timestamp: 0.0, kneeAngle: 100.0)
        // Jitter frame (120°)
        let frame2 = SyntheticSquatGenerator.createSquatFrame(timestamp: 0.033, kneeAngle: 120.0)
        
        let smoothed = smoother.smooth(frames: [frame1, frame2])
        
        let rawPt2 = frame2.joints[.leftKnee]!.point2D
        let smoothPt2 = smoothed[1].joints[.leftKnee]!.point2D
        
        // Smoothed point should be between frame 1 and frame 2
        XCTAssertNotEqual(rawPt2.x, smoothPt2.x)
    }
}
