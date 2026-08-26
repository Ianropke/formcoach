import SwiftUI
import FormCoachCore

public struct DebugOverlayView: View {
    public let poseFrame: PoseFrame?
    public let currentFPS: Double
    public let activePhase: String
    
    public init(
        poseFrame: PoseFrame?,
        currentFPS: Double = 30.0,
        activePhase: String = "Monitoring"
    ) {
        self.poseFrame = poseFrame
        self.currentFPS = currentFPS
        self.activePhase = activePhase
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("DEV / KINEMATIC DEBUG")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundColor(.yellow)
                Spacer()
                Text("\(Int(currentFPS)) FPS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
            }
            
            Divider().background(Color.white.opacity(0.2))
            
            Text("Phase: \(activePhase)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            if let frame = poseFrame {
                if let kneeAngle = extractKneeAngle(from: frame) {
                    Text("Knee Angle: \(String(format: "%.1f°", kneeAngle))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.green)
                }
                
                if let hipAngle = extractHipAngle(from: frame) {
                    Text("Hip Angle: \(String(format: "%.1f°", hipAngle))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.cyan)
                }
                
                Text("Confidence: \(String(format: "%.0f%%", frame.confidence * 100))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.yellow)
            }
        }
        .padding(10)
        .frame(width: 220)
        .background(Color.black.opacity(0.85))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
        )
    }
    
    private func extractKneeAngle(from frame: PoseFrame) -> Double? {
        let leftHip = frame.joints[.leftHip]?.point2D
        let leftKnee = frame.joints[.leftKnee]?.point2D
        let leftAnkle = frame.joints[.leftAnkle]?.point2D
        
        guard let h = leftHip, let k = leftKnee, let a = leftAnkle else { return nil }
        return AngleCalculator.angle2D(pointA: h, vertexB: k, pointC: a)
    }
    
    private func extractHipAngle(from frame: PoseFrame) -> Double? {
        let shoulder = frame.joints[.leftShoulder]?.point2D ?? frame.joints[.rightShoulder]?.point2D
        let hip = frame.joints[.leftHip]?.point2D ?? frame.joints[.rightHip]?.point2D
        let knee = frame.joints[.leftKnee]?.point2D ?? frame.joints[.rightKnee]?.point2D
        
        guard let s = shoulder, let h = hip, let k = knee else { return nil }
        return AngleCalculator.angle2D(pointA: s, vertexB: h, pointC: k)
    }
}
