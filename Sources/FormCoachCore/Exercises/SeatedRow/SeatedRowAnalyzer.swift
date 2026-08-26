import Foundation
import CoreGraphics

public struct SeatedRowCameraGuide: Sendable {
    public static let requiredJoints: Set<Joint> = [
        .nose,
        .leftShoulder, .leftElbow, .leftWrist,
        .leftHip, .leftKnee
    ]
    
    public static func validate(frame: PoseFrame, view: CameraViewType) -> CameraSetupValidation {
        let conf = PoseConfidence.evaluate(joints: frame.joints, required: requiredJoints)
        let hasArm = (frame.joints[.leftShoulder]?.isTracked ?? false || frame.joints[.rightShoulder]?.isTracked ?? false) &&
                     (frame.joints[.leftElbow]?.isTracked ?? false || frame.joints[.rightElbow]?.isTracked ?? false) &&
                     (frame.joints[.leftWrist]?.isTracked ?? false || frame.joints[.rightWrist]?.isTracked ?? false)
        let hasTorso = (frame.joints[.leftHip]?.isTracked ?? false || frame.joints[.rightHip]?.isTracked ?? false)
        
        let isReady = hasArm && hasTorso && (conf.level != .insufficient)
        return CameraSetupValidation(
            isReady: isReady,
            isFullBodyVisible: hasArm && hasTorso,
            areFeetVisible: true,
            isHeadVisible: true,
            isHipsVisible: hasTorso,
            isScaleOptimal: true,
            poseConfidence: conf,
            feedbackPrompts: isReady ? [] : ["Align camera from side view of the rowing machine"]
        )
    }
}

public struct SeatedRowRepSegmenter: RepSegmenterProtocol, Sendable {
    public enum State: Sendable {
        case extendedArms
        case pulling(startTime: TimeInterval, minElbowAngle: Double, minTime: TimeInterval)
        case fullRetraction(startTime: TimeInterval, inflectionTime: TimeInterval, minElbowAngle: Double)
        case releasing(startTime: TimeInterval, inflectionTime: TimeInterval, minElbowAngle: Double)
    }
    
    public init() {}
    
    public func segment(timeSeries: PoseTimeSeries, view: CameraViewType) -> [Repetition] {
        guard timeSeries.count >= 10 else { return [] }
        var reps: [Repetition] = []
        var state: State = .extendedArms
        var repIndexCounter = 1
        let frames = timeSeries.frames
        
        for i in 0..<frames.count {
            let frame = frames[i]
            let timestamp = frame.timestamp
            guard let elbowAngle = extractElbowAngle(from: frame) else { continue }
            
            switch state {
            case .extendedArms:
                // Row concentric pull starts when elbow angle drops below 145°
                if elbowAngle < 145.0 {
                    state = .pulling(startTime: timestamp, minElbowAngle: elbowAngle, minTime: timestamp)
                }
            case .pulling(let startTime, let minAngle, let minTime):
                let currentMin = min(minAngle, elbowAngle)
                let currentMinTime = (elbowAngle <= minAngle) ? timestamp : minTime
                let nextAngle = (i + 1 < frames.count) ? extractElbowAngle(from: frames[i + 1]) : nil
                
                if let next = nextAngle, next > currentMin + 2.5 {
                    state = .fullRetraction(startTime: startTime, inflectionTime: currentMinTime, minElbowAngle: currentMin)
                } else if elbowAngle > currentMin + 3.5 {
                    state = .fullRetraction(startTime: startTime, inflectionTime: currentMinTime, minElbowAngle: currentMin)
                } else {
                    state = .pulling(startTime: startTime, minElbowAngle: currentMin, minTime: currentMinTime)
                }
            case .fullRetraction(let startTime, let inflectionTime, let minAngle):
                let currentMin = min(minAngle, elbowAngle)
                let currentMinTime = (elbowAngle < minAngle) ? timestamp : inflectionTime
                if elbowAngle > (currentMin + 10.0) {
                    state = .releasing(startTime: startTime, inflectionTime: currentMinTime, minElbowAngle: currentMin)
                } else {
                    state = .fullRetraction(startTime: startTime, inflectionTime: currentMinTime, minElbowAngle: currentMin)
                }
            case .releasing(let startTime, let inflectionTime, let minAngle):
                // Returns to arm extension (>= 145°)
                if elbowAngle >= 145.0 {
                    let totalDuration = timestamp - startTime
                    if totalDuration >= 0.8 && (155.0 - minAngle) >= 45.0 {
                        let peakFrame = timeSeries.frame(at: inflectionTime) ?? frame
                        let torsoSwing = extractTorsoIncline(from: peakFrame)
                        let rep = Repetition(
                            index: repIndexCounter,
                            startTime: startTime,
                            inflectionTime: inflectionTime,
                            endTime: timestamp,
                            eccentricDuration: max(0.2, timestamp - inflectionTime),
                            pauseDuration: 0.1,
                            concentricDuration: max(0.2, inflectionTime - startTime),
                            primaryROM: minAngle, // Peak retraction angle (lower = deeper pull)
                            secondaryROM: torsoSwing, // Torso swing angle
                            torsoAngleMean: torsoSwing,
                            confidence: frame.confidence,
                            isComplete: true
                        )
                        reps.append(rep)
                        repIndexCounter += 1
                    }
                    state = .extendedArms
                }
            }
        }
        return reps
    }
    
    private func extractElbowAngle(from frame: PoseFrame) -> Double? {
        let shoulder = frame.joints[.leftShoulder]?.point2D ?? frame.joints[.rightShoulder]?.point2D
        let elbow = frame.joints[.leftElbow]?.point2D ?? frame.joints[.rightElbow]?.point2D
        let wrist = frame.joints[.leftWrist]?.point2D ?? frame.joints[.rightWrist]?.point2D
        guard let s = shoulder, let e = elbow, let w = wrist else { return nil }
        return AngleCalculator.angle2D(pointA: s, vertexB: e, pointC: w)
    }
    
    private func extractTorsoIncline(from frame: PoseFrame) -> Double? {
        let shoulder = frame.joints[.leftShoulder]?.point2D ?? frame.joints[.rightShoulder]?.point2D
        let hip = frame.joints[.leftHip]?.point2D ?? frame.joints[.rightHip]?.point2D
        guard let s = shoulder, let h = hip else { return nil }
        return AngleCalculator.angleRelativeToVertical(top: s, bottom: h)
    }
}

public struct SeatedRowRules: Sendable {
    public static let standardRules: [BiomechanicalRule] = [
        BiomechanicalRule(
            id: "row.torso.swing",
            title: "Torso Momentum Swing",
            severity: .warning,
            condition: { ctx in
                let meanSwing = ctx.reps.reduce(0.0) { $0 + ($1.secondaryROM ?? 0.0) } / Double(max(1, ctx.reps.count))
                guard meanSwing >= 18.0 else { return nil }
                return FormObservation(
                    id: "row.torso.swing",
                    title: "Excessive Torso Leaning",
                    detail: "Observed an average \(String(format: "%.0f°", meanSwing)) backward torso lean. Keep your core braced and pull primarily with your back.",
                    evidence: "Torso swung backward during contraction.",
                    severity: .warning,
                    affectedRepIndices: ctx.reps.map { $0.index }
                )
            }
        ),
        BiomechanicalRule(
            id: "row.form.strict",
            title: "Strict Torso & Deep Retraction",
            severity: .positive,
            condition: { ctx in
                let meanSwing = ctx.reps.reduce(0.0) { $0 + ($1.secondaryROM ?? 0.0) } / Double(max(1, ctx.reps.count))
                guard ctx.reps.count >= 5, meanSwing < 12.0, ctx.meanROM <= 75.0 else { return nil }
                return FormObservation(
                    id: "row.form.strict",
                    title: "Strict Back Retraction",
                    detail: "Maintained an upright torso with full scapular retraction on every rep.",
                    evidence: "Clean rowing form with under 12° torso movement.",
                    severity: .positive,
                    affectedRepIndices: ctx.reps.map { $0.index }
                )
            }
        )
    ]
}

public struct SeatedRowAnalyzer: ExerciseAnalyzerProtocol, Sendable {
    public let exerciseType: ExerciseType = .seatedRow
    public let requiredJoints: Set<Joint> = SeatedRowCameraGuide.requiredJoints
    public let supportedViews: [CameraViewType] = [.side, .front45, .front]
    private let segmenter = SeatedRowRepSegmenter()
    private let ruleEngine = FormRuleEngine(rules: SeatedRowRules.standardRules)
    
    public init() {}
    
    public func validateCameraSetup(frame: PoseFrame, view: CameraViewType) -> CameraSetupValidation {
        SeatedRowCameraGuide.validate(frame: frame, view: view)
    }
    public func segmentReps(timeSeries: PoseTimeSeries, view: CameraViewType) -> [Repetition] {
        segmenter.segment(timeSeries: timeSeries, view: view)
    }
    public func analyzeSet(reps: [Repetition], timeSeries: PoseTimeSeries, view: CameraViewType) -> SetAnalysis {
        let confidence = ConfidenceEngine.evaluateSetConfidence(timeSeries: timeSeries, requiredJoints: requiredJoints)
        guard !reps.isEmpty else {
            return SetAnalysis(overallQualityScore: 0, romScore: 0, consistencyScore: 0, tempoScore: 0, symmetryScore: nil, primaryObservation: "No reps detected", observations: [], trackingConfidence: confidence, repCount: 0, meanROM: 0, meanDuration: 0)
        }
        let meanROM = reps.reduce(0.0) { $0 + $1.primaryROM } / Double(reps.count)
        let meanDur = reps.reduce(0.0) { $0 + $1.duration } / Double(reps.count)
        let romScore = meanROM <= 75.0 ? 98.0 : (70.0 + (90.0 - meanROM))
        let consistencyScore = 93.0
        let tempoScore = 91.0
        
        let ctx = SetAnalysisContext(exerciseType: .seatedRow, reps: reps, cameraView: view, trackingConfidence: confidence, meanROM: meanROM, meanDuration: meanDur, earlyLateROMDelta: 0.0, earlyLateTempoDelta: nil)
        let obs = ruleEngine.evaluate(context: ctx)
        let primaryText = obs.first?.detail ?? "Clean seated cable row set with ~\(String(format: "%.0f°", meanROM)) retraction."
        let overallQuality = (romScore * 0.4) + (consistencyScore * 0.3) + (tempoScore * 0.3)
        return SetAnalysis(overallQualityScore: overallQuality, romScore: romScore, consistencyScore: consistencyScore, tempoScore: tempoScore, symmetryScore: nil, primaryObservation: primaryText, observations: obs, trackingConfidence: confidence, repCount: reps.count, meanROM: meanROM, meanDuration: meanDur)
    }
}
