import Foundation
import CoreGraphics
import ImageIO

/// Transforms coordinates between Apple Vision normalized space and standard domain space
public struct CoordinateNormalizer: Sendable {
    
    /// Maps Vision normalized point (origin bottom-left, [0...1])
    /// to Domain space (origin top-left, [0...1]) with orientation adjustments.
    public static func normalizeVisionPoint(
        _ point: CGPoint,
        orientation: CGImagePropertyOrientation = .up
    ) -> CGPoint {
        // Vision has (0,0) at bottom-left. We map to top-left:
        var x = point.x
        var y = 1.0 - point.y
        
        switch orientation {
        case .up:
            // Standard portrait / default
            break
        case .upMirrored:
            x = 1.0 - x
        case .down:
            x = 1.0 - x
            y = 1.0 - y
        case .downMirrored:
            y = 1.0 - y
        case .left:
            let tmp = x
            x = y
            y = 1.0 - tmp
        case .right:
            let tmp = x
            x = 1.0 - y
            y = tmp
        default:
            break
        }
        
        // Clamp to valid [0.0, 1.0] range
        let clampedX = min(max(x, 0.0), 1.0)
        let clampedY = min(max(y, 0.0), 1.0)
        
        return CGPoint(x: clampedX, y: clampedY)
    }
    
    /// Converts a normalized domain point [0...1] to UIKit/SwiftUI screen coordinates
    public static func denormalize(
        point: CGPoint,
        viewSize: CGSize
    ) -> CGPoint {
        CGPoint(
            x: point.x * viewSize.width,
            y: point.y * viewSize.height
        )
    }
}
