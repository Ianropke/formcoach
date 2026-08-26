import Foundation
import CoreGraphics

public struct TricepsPushdownCameraGuide: Sendable {
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
        
        var isScaleOptimal = false
        var feedback: [String] = []
        
        if let bbox = frame.boundingBox {
            if bbox.height < 0.35 {
                feedback.append("Move closer to the camera")
            } else if bbox.height > 0.95 {
                feedback.append("Step back slightly")
            } else {
                isScaleOptimal = true
            }
        } else {
            feedback.append("Step into the camera view")
        }
        
        let isReady = hasArm && hasTorso && isScaleOptimal && (conf.level != .insufficient)
        return CameraSetupValidation(
            isReady: isReady,
            isFullBodyVisible: hasArm && hasTorso,
            areFeetVisible: true,
            isHeadVisible: frame.joints[.nose]?.isTracked ?? false,
            isHipsVisible: hasTorso,
            isScaleOptimal: isScaleOptimal,
            poseConfidence: conf,
            feedbackPrompts: feedback
        )
    }
}

public struct TricepsPushdownRepSegmenter: RepSegmenterProtocol, Sendable {
    public enum State: Sendable {
        case topFlexion
        case extending(startTime: TimeInterval, maxExtension: Double, maxTime: TimeInterval)
        case lockout(startTime: TimeInterval, inflectionTime: TimeInterval, maxExtension: Double)
        case returning(startTime: TimeInterval, inflectionTime: TimeInterval, maxExtension: Double)
    }
    
    public init() {}
    
    public func segment(timeSeries: PoseTimeSeries, view: CameraViewType) -> [Repetition] {
        guard timeSeries.count >= 10 else { return [] }
        var reps: [Repetition] = []
        var state: State = .topFlexion
        var repIndexCounter = 1
        let frames = timeSeries.frames
        
        for i in 0..<frames.count {
            let frame = frames[i]
            let timestamp = frame.timestamp
            guard let elbowAngle = extractElbowAngle(from: frame) else { continue }
            
            switch state {
            case .topFlexion:
                // Pushdown starts when elbow angle expands > 95°
                if elbowAngle > 95.0 {
                    state = .extending(startTime: timestamp, maxExtension: elbowAngle, maxTime: timestamp)
                }
            case .extending(let startTime, let maxExt, let maxTime):
                let currentMax = max(maxExt, elbowAngle)
                let currentMaxTime = (elbowAngle >= maxExt) ? timestamp : maxTime
                let nextAngle = (i + 1 < frames.count) ? extractElbowAngle(from: frames[i + 1]) : nil
                
                if let next = nextAngle, next < currentMax - 2.5 {
                    state = .lockout(startTime: startTime, inflectionTime: currentMaxTime, maxExtension: currentMax)
                } else if elbowAngle < currentMax - 3.5 {
                    state = .lockout(startTime: startTime, inflectionTime: currentMaxTime, maxExtension: currentMax)
                } else {
                    state = .extending(startTime: startTime, maxExtension: currentMax, maxTime: currentMaxTime)
                }
            case .lockout(let startTime, let inflectionTime, let maxExt):
                let currentMax = max(maxExt, elbowAngle)
                let currentMaxTime = (elbowAngle > maxExt) ? timestamp : inflectionTime
                if elbowAngle < (currentMax - 8.0) {
                    state = .returning(startTime: startTime, inflectionTime: currentMaxTime, maxExtension: currentMax)
                } else {
                    state = .lockout(startTime: startTime, inflectionTime: currentMaxTime, maxExtension: currentMax)
                }
            case .returning(let startTime, let inflectionTime, let maxExt):
                // Returns to top flexion (<= 95°)
                if elbowAngle <= 95.0 {
                    let totalDuration = timestamp - startTime
                    if totalDuration >= 0.7 && (maxExt - 85.0) >= 40.0 {
                        let rep = Repetition(
                            index: repIndexCounter,
                            startTime: startTime,
                            inflectionTime: inflectionTime,
                            endTime: timestamp,
                            eccentricDuration: max(0.2, timestamp - inflectionTime),
                            pauseDuration: 0.1,
                            concentricDuration: max(0.2, inflectionTime - startTime),
                            primaryROM: maxExt,
                            secondaryROM: extractElbowDrift(from: timeSeries.frame(at: inflectionTime) ?? frame),
                            torsoAngleMean: 10.0,
                            confidence: frame.confidence,
                            isComplete: true
                        )
                        reps.append(rep)
                        repIndexCounter += 1
                    }
                    state = .topFlexion
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
    
    private func extractElbowDrift(from frame: PoseFrame) -> Double? {
        let hip = frame.joints[.leftHip]?.point2D ?? frame.joints[.rightHip]?.point2D
        let shoulder = frame.joints[.leftShoulder]?.point2D ?? frame.joints[.rightShoulder]?.point2D
        let elbow = frame.joints[.leftElbow]?.point2D ?? frame.joints[.rightElbow]?.point2D
        guard let h = hip, let s = shoulder, let e = elbow else { return nil }
        return AngleCalculator.angle2D(pointA: h, vertexB: s, pointC: e)
    }
}

public struct TricepsPushdownRules: Sendable {
    public static let standardRules: [BiomechanicalRule] = [
        BiomechanicalRule(
            id: "triceps.elbow.drift",
            title: "Pinned Elbow Drift",
            severity: .warning,
            condition: { ctx in
                let meanDrift = ctx.reps.reduce(0.0) { $0 + ($1.secondaryROM ?? 0.0) } / Double(max(1, ctx.reps.count))
                guard meanDrift >= 20.0 else { return nil }
                return FormObservation(
                    id: "triceps.elbow.drift",
                    title: "Elbows Drifting Forward",
                    detail: "Observed an average \(String(format: "%.0f°", meanDrift)) forward shoulder angle. Keep elbows pinned to your sides.",
                    evidence: "Elbows drifted forward during extension.",
                    severity: .warning,
                    affectedRepIndices: ctx.reps.map { $0.index }
                )
            }
        ),
        BiomechanicalRule(
            id: "triceps.lockout.incomplete",
            title: "Partial Extension",
            severity: .info,
            condition: { ctx in
                guard ctx.meanROM < 152.0 else { return nil }
                return FormObservation(
                    id: "triceps.lockout.incomplete",
                    title: "Incomplete Lockout",
                    detail: "Average elbow extension reached \(String(format: "%.0f°", ctx.meanROM)), stopping short of full triceps extension (~165°).",
                    evidence: "Elbow extension did not reach full lockout.",
                    severity: .info,
                    affectedRepIndices: ctx.reps.map { $0.index }
                )
            }
        ),
        BiomechanicalRule(
            id: "triceps.form.strict",
            title: "Pinned Strict Lockout",
            severity: .positive,
            condition: { ctx in
                let meanDrift = ctx.reps.reduce(0.0) { $0 + ($1.secondaryROM ?? 0.0) } / Double(max(1, ctx.reps.count))
                guard ctx.reps.count >= 5, meanDrift < 12.0, ctx.meanROM >= 160.0 else { return nil }
                return FormObservation(
                    id: "triceps.form.strict",
                    title: "Strict Triceps Lockout",
                    detail: "Elbows stayed tightly pinned with complete extension on every rep.",
                    evidence: "Full extension with under 12° shoulder deviation.",
                    severity: .positive,
                    affectedRepIndices: ctx.reps.map { $0.index }
                )
            }
        )
    ]
}

public struct TricepsPushdownAnalyzer: ExerciseAnalyzerProtocol, Sendable {
    public let exerciseType: ExerciseType = .tricepsPushdown
    public let requiredJoints: Set<Joint> = TricepsPushdownCameraGuide.requiredJoints
    public let supportedViews: [CameraViewType] = [.side, .front45, .front]
    private let segmenter = TricepsPushdownRepSegmenter()
    private let ruleEngine = FormRuleEngine(rules: TricepsPushdownRules.standardRules)
    
    public init() {}
    
    public func validateCameraSetup(frame: PoseFrame, view: CameraViewType) -> CameraSetupValidation {
        TricepsPushdownCameraGuide.validate(frame: frame, view: view)
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
        let romScore = meanROM >= 160.0 ? 98.0 : (75.0 + (meanROM - 140.0))
        let consistencyScore = 94.0
        let tempoScore = 90.0
        
        let ctx = SetAnalysisContext(exerciseType: .tricepsPushdown, reps: reps, cameraView: view, trackingConfidence: confidence, meanROM: meanROM, meanDuration: meanDur, earlyLateROMDelta: 0.0, earlyLateTempoDelta: nil)
        let obs = ruleEngine.evaluate(context: ctx)
        let primaryText = obs.first?.detail ?? "Clean triceps pushdown set with ~\(String(format: "%.0f°", meanROM)) lockout."
        let overallQuality = (romScore * 0.4) + (consistencyScore * 0.3) + (tempoScore * 0.3)
        return SetAnalysis(overallQualityScore: overallQuality, romScore: romScore, consistencyScore: consistencyScore, tempoScore: tempoScore, symmetryScore: nil, primaryObservation: primaryText, observations: obs, trackingConfidence: confidence, repCount: reps.count, meanROM: meanROM, meanDuration: meanDur)
    }
}
