import XCTest
@testable import FormCoachCore

final class AngleCalculatorTests: XCTestCase {
    
    func testOrthogonalAngle90Degrees() {
        let pA = CGPoint(x: 0.0, y: 1.0)
        let vertexB = CGPoint(x: 0.0, y: 0.0)
        let pC = CGPoint(x: 1.0, y: 0.0)
        
        let angle = AngleCalculator.angle2D(pointA: pA, vertexB: vertexB, pointC: pC)
        XCTAssertEqual(angle, 90.0, accuracy: 1e-4)
    }
    
    func testStraightLineAngle180Degrees() {
        let pA = CGPoint(x: -1.0, y: 0.0)
        let vertexB = CGPoint(x: 0.0, y: 0.0)
        let pC = CGPoint(x: 1.0, y: 0.0)
        
        let angle = AngleCalculator.angle2D(pointA: pA, vertexB: vertexB, pointC: pC)
        XCTAssertEqual(angle, 180.0, accuracy: 1e-4)
    }
    
    func testAcuteAngle45Degrees() {
        let pA = CGPoint(x: 1.0, y: 1.0)
        let vertexB = CGPoint(x: 0.0, y: 0.0)
        let pC = CGPoint(x: 1.0, y: 0.0)
        
        let angle = AngleCalculator.angle2D(pointA: pA, vertexB: vertexB, pointC: pC)
        XCTAssertEqual(angle, 45.0, accuracy: 1e-4)
    }
    
    func testAngleRelativeToVertical() {
        // Perfectly vertical torso: top is (0.5, 0.2), bottom is (0.5, 0.6)
        let top = CGPoint(x: 0.5, y: 0.2)
        let bottom = CGPoint(x: 0.5, y: 0.6)
        
        let angle = AngleCalculator.angleRelativeToVertical(top: top, bottom: bottom)
        XCTAssertEqual(angle, 0.0, accuracy: 1e-4)
        
        // 45 degree incline
        let inclinedTop = CGPoint(x: 0.1, y: 0.2)
        let inclinedBottom = CGPoint(x: 0.5, y: 0.6)
        let inclinedAngle = AngleCalculator.angleRelativeToVertical(top: inclinedTop, bottom: inclinedBottom)
        XCTAssertEqual(inclinedAngle, 45.0, accuracy: 1e-1)
    }
    
    func test3DAngleCalculation() {
        let a = (x: 1.0, y: 0.0, z: 0.0)
        let b = (x: 0.0, y: 0.0, z: 0.0)
        let c = (x: 0.0, y: 1.0, z: 0.0)
        
        let angle = AngleCalculator.angle3D(a: a, b: b, c: c)
        XCTAssertEqual(angle, 90.0, accuracy: 1e-4)
    }
}
