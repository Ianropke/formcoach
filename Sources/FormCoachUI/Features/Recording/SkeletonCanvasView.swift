import SwiftUI
import FormCoachCore

/// High-performance Canvas rendering of normalized skeletal landmarks and connections
public struct SkeletonCanvasView: View {
    public let poseFrame: PoseFrame?
    public let highlightJoints: Set<Joint>
    public let jointColor: Color
    public let boneColor: Color
    
    public init(
        poseFrame: PoseFrame?,
        highlightJoints: Set<Joint> = [],
        jointColor: Color = .green,
        boneColor: Color = .white.opacity(0.85)
    ) {
        self.poseFrame = poseFrame
        self.highlightJoints = highlightJoints
        self.jointColor = jointColor
        self.boneColor = boneColor
    }
    
    public var body: some View {
        Canvas { context, size in
            guard let frame = poseFrame else { return }
            
            // 1. Draw Bones (Connections)
            for conn in JointConnection.standardSkeleton {
                if let p1 = frame.point(for: conn.from),
                   let p2 = frame.point(for: conn.to) {
                    
                    let screenPt1 = CoordinateNormalizer.denormalize(point: p1, viewSize: size)
                    let screenPt2 = CoordinateNormalizer.denormalize(point: p2, viewSize: size)
                    
                    var path = Path()
                    path.move(to: screenPt1)
                    path.addLine(to: screenPt2)
                    
                    context.stroke(
                        path,
                        with: .color(boneColor),
                        lineWidth: 3.5
                    )
                }
            }
            
            // 2. Draw Joints (Circles)
            for (joint, observation) in frame.joints where observation.isTracked {
                let screenPt = CoordinateNormalizer.denormalize(point: observation.point2D, viewSize: size)
                let isHighlighted = highlightJoints.contains(joint)
                let radius: CGFloat = isHighlighted ? 6.5 : 4.5
                let color = isHighlighted ? Color.yellow : jointColor
                
                let rect = CGRect(
                    x: screenPt.x - radius,
                    y: screenPt.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(color)
                )
                
                // Outer ring
                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color(.black.opacity(0.6)),
                    lineWidth: 1.5
                )
            }
        }
        .allowsHitTesting(false)
    }
}
