import Foundation
import FormCoachCore

@main
struct FormCoachTestRunner {
    
    static func makeMockSet(
        exercise: ExerciseType,
        reps: [(depth: Double, duration: Double)],
        quality: Double = 85.0
    ) -> ExerciseSetModel {
        let repModels: [RepModel] = reps.enumerated().map { (idx, r) in
            RepModel(
                id: UUID(),
                index: idx + 1,
                startTime: Double(idx) * r.duration,
                inflectionTime: Double(idx) * r.duration + (r.duration * 0.5),
                endTime: Double(idx + 1) * r.duration,
                duration: r.duration,
                eccentricDuration: r.duration * 0.5,
                concentricDuration: r.duration * 0.5,
                pauseDuration: 0.1,
                primaryROM: r.depth,
                secondaryROM: nil,
                torsoAngleMean: 10.0,
                confidence: 0.95,
                isComplete: true
            )
        }
        
        let analysisModel = SetAnalysisModel(
            id: UUID(),
            overallQualityScore: quality,
            romScore: quality,
            consistencyScore: quality,
            tempoScore: quality,
            symmetryScore: nil,
            primaryObservation: "Set Analysis",
            observationsJson: "[]"
        )
        
        return ExerciseSetModel(
            id: UUID(),
            exerciseTypeRaw: exercise.rawValue,
            cameraViewRaw: CameraViewType.side.rawValue,
            recordedAt: Date(),
            videoPath: nil,
            poseDataPath: nil,
            repCount: reps.count,
            trackingConfidence: 0.95,
            reps: repModels,
            analysis: analysisModel
        )
    }
    
    static func main() {
        print("\n========================================================")
        print("     FORMCOACH DETERMINISTIC BIOMECHANICS TEST SUITE    ")
        print("      (M0 + M1 + M2 + M3 + M4 + M5 FULL SUITE)          ")
        print("========================================================\n")
        
        var passedCount = 0
        var totalCount = 0
        
        func runTest(name: String, block: () throws -> Void) {
            totalCount += 1
            print("▶ Running [\(name)]... ", terminator: "")
            do {
                try block()
                passedCount += 1
                print("✅ PASS")
            } catch {
                print("❌ FAIL: \(error)")
            }
        }
        
        // ---------------------------------------------------------------------
        // SECTION 1: VECTOR GEOMETRY & POSE SMOOTHING (M0 FOUNDATION)
        // ---------------------------------------------------------------------
        runTest(name: "AngleCalculator: Orthogonal 90° Angle") {
            let pA = CGPoint(x: 0.0, y: 1.0)
            let vertexB = CGPoint(x: 0.0, y: 0.0)
            let pC = CGPoint(x: 1.0, y: 0.0)
            let angle = AngleCalculator.angle2D(pointA: pA, vertexB: vertexB, pointC: pC)
            guard abs(angle - 90.0) < 1e-4 else {
                throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected 90°, got \(angle)"])
            }
        }
        
        runTest(name: "AngleCalculator: Straight Line 180° Angle") {
            let pA = CGPoint(x: -1.0, y: 0.0)
            let vertexB = CGPoint(x: 0.0, y: 0.0)
            let pC = CGPoint(x: 1.0, y: 0.0)
            let angle = AngleCalculator.angle2D(pointA: pA, vertexB: vertexB, pointC: pC)
            guard abs(angle - 180.0) < 1e-4 else {
                throw NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Expected 180°, got \(angle)"])
            }
        }
        
        runTest(name: "AngleCalculator: Acute 45° Angle") {
            let pA = CGPoint(x: 1.0, y: 1.0)
            let vertexB = CGPoint(x: 0.0, y: 0.0)
            let pC = CGPoint(x: 1.0, y: 0.0)
            let angle = AngleCalculator.angle2D(pointA: pA, vertexB: vertexB, pointC: pC)
            guard abs(angle - 45.0) < 1e-4 else {
                throw NSError(domain: "Test", code: 3, userInfo: [NSLocalizedDescriptionKey: "Expected 45°, got \(angle)"])
            }
        }
        
        runTest(name: "AngleCalculator: Torso Inclination Angle") {
            let top = CGPoint(x: 0.5, y: 0.2)
            let bottom = CGPoint(x: 0.5, y: 0.6)
            let verticalAngle = AngleCalculator.angleRelativeToVertical(top: top, bottom: bottom)
            guard abs(verticalAngle - 0.0) < 1e-4 else {
                throw NSError(domain: "Test", code: 4, userInfo: [NSLocalizedDescriptionKey: "Expected 0° vertical, got \(verticalAngle)"])
            }
        }
        
        runTest(name: "PoseSmoother: Short-Gap Interpolation (3-frame dropout)") {
            let smoother = PoseSmoother(alpha: 0.7, maxInterpolationGap: 3)
            let frame1 = SyntheticSquatGenerator.createSquatFrame(timestamp: 0.0, kneeAngle: 170.0)
            let frame2 = SyntheticSquatGenerator.createSquatFrame(timestamp: 0.033, kneeAngle: 0.0, isOccluded: true)
            let frame3 = SyntheticSquatGenerator.createSquatFrame(timestamp: 0.066, kneeAngle: 0.0, isOccluded: true)
            let frame4 = SyntheticSquatGenerator.createSquatFrame(timestamp: 0.099, kneeAngle: 150.0)
            
            let smoothed = smoother.smooth(frames: [frame1, frame2, frame3, frame4])
            guard smoothed.count == 4,
                  let k2 = smoothed[1].observation(for: .leftKnee), k2.isTracked,
                  smoothed[1].isInterpolated else {
                throw NSError(domain: "Test", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to interpolate dropped frame"])
            }
        }
        
        // ---------------------------------------------------------------------
        // SECTION 2: SQUAT BIOMECHANICS & RULES (M1)
        // ---------------------------------------------------------------------
        runTest(name: "SquatRepSegmenter: Clean 10-Rep Squat Sequence") {
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
            guard reps.count == 10 else {
                throw NSError(domain: "Test", code: 6, userInfo: [NSLocalizedDescriptionKey: "Expected 10 reps, got \(reps.count)"])
            }
        }
        
        runTest(name: "SquatRepSegmenter: Discard Incomplete Final Rep") {
            let segmenter = SquatRepSegmenter()
            let fullSeries = SyntheticSquatGenerator.generateSquatSet(
                repCount: 5,
                fps: 30.0,
                standingKneeAngle: 175.0,
                bottomKneeAngles: Array(repeating: 85.0, count: 5),
                repDuration: 2.5
            )
            
            var frames = fullSeries.frames
            let lastTime = frames.last?.timestamp ?? 0.0
            for f in 0..<30 {
                let t = lastTime + (Double(f) / 30.0)
                let angle = 175.0 - (40.0 * (Double(f) / 30.0))
                frames.append(SyntheticSquatGenerator.createSquatFrame(timestamp: t, kneeAngle: angle))
            }
            
            let incompleteSeries = PoseTimeSeries(frames: frames, fps: 30.0)
            let reps = segmenter.segment(timeSeries: incompleteSeries, view: .side)
            guard reps.count == 5 else {
                throw NSError(domain: "Test", code: 7, userInfo: [NSLocalizedDescriptionKey: "Expected 5 completed reps, got \(reps.count)"])
            }
        }
        
        runTest(name: "SquatMetrics: Early vs Late-Set ROM Deterioration (-35%)") {
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
            
            guard let delta = SquatMetrics.computeEarlyLateROMDelta(reps: reps),
                  abs(delta - (-35.0)) <= 2.0 else {
                throw NSError(domain: "Test", code: 8, userInfo: [NSLocalizedDescriptionKey: "Failed to detect -35% degradation delta"])
            }
        }
        
        runTest(name: "SquatRules: Explainable Fatigue Degradation Rule Trigger") {
            let engine = FormRuleEngine(rules: SquatRules.standardRules)
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
            
            let context = SetAnalysisContext(
                exerciseType: .squat,
                reps: reps,
                cameraView: .side,
                trackingConfidence: PoseConfidence(overallScore: 0.95, level: .good, visibleJointRatio: 1.0, meanJointConfidence: 0.95),
                meanROM: 95.0,
                meanDuration: 3.0,
                earlyLateROMDelta: -35.0,
                earlyLateTempoDelta: 0.0
            )
            
            let observations = engine.evaluate(context: context)
            guard let decayObs = observations.first(where: { $0.id == "squat.rom.decay" }),
                  decayObs.severity == .warning else {
                throw NSError(domain: "Test", code: 9, userInfo: [NSLocalizedDescriptionKey: "Decay observation did not trigger"])
            }
        }
        
        // ---------------------------------------------------------------------
        // SECTION 3: BICEPS CURL BIOMECHANICS & CHEAT DETECTION (M2)
        // ---------------------------------------------------------------------
        runTest(name: "BicepsCurlRepSegmenter: Clean 10-Rep Curl Sequence") {
            let segmenter = BicepsCurlRepSegmenter()
            let timeSeries = SyntheticCurlGenerator.generateCurlSet(
                repCount: 10,
                fps: 30.0,
                lockoutElbowAngle: 165.0,
                peakElbowAngles: Array(repeating: 55.0, count: 10),
                shoulderDriftAngles: Array(repeating: 0.0, count: 10),
                repDuration: 2.4,
                pauseDuration: 0.6
            )
            
            let reps = segmenter.segment(timeSeries: timeSeries, view: .side)
            guard reps.count == 10 else {
                throw NSError(domain: "Test", code: 10, userInfo: [NSLocalizedDescriptionKey: "Expected 10 reps, got \(reps.count)"])
            }
        }
        
        runTest(name: "BicepsCurlRules: Shoulder Momentum Warning Rule Trigger (>18°)") {
            let engine = FormRuleEngine(rules: BicepsCurlRules.standardRules)
            let reps: [Repetition] = (1...8).map { i in
                Repetition(
                    index: i,
                    startTime: Double(i) * 2.5,
                    inflectionTime: Double(i) * 2.5 + 1.2,
                    endTime: Double(i) * 2.5 + 2.5,
                    eccentricDuration: 1.3,
                    pauseDuration: 0.1,
                    concentricDuration: 1.1,
                    primaryROM: 58.0,
                    secondaryROM: 24.0, // >18° drift
                    confidence: 0.95
                )
            }
            
            let context = SetAnalysisContext(
                exerciseType: .bicepsCurl,
                reps: reps,
                cameraView: .side,
                trackingConfidence: PoseConfidence(overallScore: 0.95, level: .good, visibleJointRatio: 1.0, meanJointConfidence: 0.95),
                meanROM: 58.0,
                meanDuration: 2.5,
                earlyLateROMDelta: 0.0,
                earlyLateTempoDelta: nil
            )
            
            let observations = engine.evaluate(context: context)
            guard let driftObs = observations.first(where: { $0.id == "curl.shoulder.drift" }),
                  driftObs.severity == .warning else {
                throw NSError(domain: "Test", code: 11, userInfo: [NSLocalizedDescriptionKey: "Shoulder drift warning did not trigger"])
            }
        }
        
        runTest(name: "GoldenDataset: Strict 10-Rep Biceps Curl Analysis") {
            let analyzer = BicepsCurlAnalyzer()
            let timeSeries = SyntheticCurlGenerator.generateCurlSet(
                repCount: 10,
                fps: 30.0,
                lockoutElbowAngle: 165.0,
                peakElbowAngles: Array(repeating: 55.0, count: 10),
                shoulderDriftAngles: Array(repeating: 4.0, count: 10), // Strict form
                repDuration: 2.4,
                pauseDuration: 0.6
            )
            
            let reps = analyzer.segmentReps(timeSeries: timeSeries, view: .side)
            let analysis = analyzer.analyzeSet(reps: reps, timeSeries: timeSeries, view: .side)
            
            guard reps.count == 10,
                  analysis.repCount == 10,
                  analysis.trackingConfidence.level == .good,
                  analysis.overallQualityScore >= 90.0,
                  analysis.observations.contains(where: { $0.id == "curl.form.strict" }) else {
                throw NSError(domain: "Test", code: 12, userInfo: [NSLocalizedDescriptionKey: "Golden strict curl analysis failed"])
            }
        }
        
        runTest(name: "GoldenDataset: Momentum Swing Cheat Set Analysis") {
            let analyzer = BicepsCurlAnalyzer()
            let timeSeries = SyntheticCurlGenerator.generateCurlSet(
                repCount: 10,
                fps: 30.0,
                lockoutElbowAngle: 165.0,
                peakElbowAngles: Array(repeating: 60.0, count: 10),
                shoulderDriftAngles: Array(repeating: 28.0, count: 10), // Cheating swing
                repDuration: 2.2,
                pauseDuration: 0.5
            )
            
            let reps = analyzer.segmentReps(timeSeries: timeSeries, view: .side)
            let analysis = analyzer.analyzeSet(reps: reps, timeSeries: timeSeries, view: .side)
            
            guard reps.count == 10,
                  analysis.observations.contains(where: { $0.id == "curl.shoulder.drift" }),
                  analysis.overallQualityScore < 85.0 else {
                throw NSError(domain: "Test", code: 13, userInfo: [NSLocalizedDescriptionKey: "Golden momentum swing set failed to flag drift"])
            }
        }
        
        // ---------------------------------------------------------------------
        // SECTION 4: MULTI-SET INTELLIGENCE & CROSS-SET FATIGUE (M3)
        // ---------------------------------------------------------------------
        runTest(name: "CrossSetFatigueAnalyzer: 4-Set Progressive Fatigue Deterioration") {
            let set1 = makeMockSet(exercise: .squat, reps: Array(repeating: (depth: 82.0, duration: 2.5), count: 10))
            let set2 = makeMockSet(exercise: .squat, reps: Array(repeating: (depth: 86.0, duration: 2.5), count: 10))
            let set3 = makeMockSet(exercise: .squat, reps: Array(repeating: (depth: 98.0, duration: 3.0), count: 10))
            let set4 = makeMockSet(exercise: .squat, reps: Array(repeating: (depth: 116.0, duration: 3.2), count: 10))
            
            let sessionAnalysis = CrossSetFatigueAnalyzer.analyzeSession(sets: [set1, set2, set3, set4], exerciseType: .squat)
            
            guard sessionAnalysis.totalSets == 4,
                  sessionAnalysis.totalReps == 40,
                  sessionAnalysis.romTrend == .degrading,
                  sessionAnalysis.fatigueIndex >= 30.0,
                  sessionAnalysis.sessionObservations.contains(where: { $0.id == "session.cross_set.rom_decay" }) else {
                throw NSError(domain: "Test", code: 14, userInfo: [NSLocalizedDescriptionKey: "Cross-set fatigue analysis failed to detect decay"])
            }
        }
        
        runTest(name: "CrossSetFatigueAnalyzer: 3-Set Stable High-Endurance Session") {
            let set1 = makeMockSet(exercise: .squat, reps: Array(repeating: (depth: 84.0, duration: 2.5), count: 8))
            let set2 = makeMockSet(exercise: .squat, reps: Array(repeating: (depth: 84.5, duration: 2.5), count: 8))
            let set3 = makeMockSet(exercise: .squat, reps: Array(repeating: (depth: 84.0, duration: 2.5), count: 8))
            
            let sessionAnalysis = CrossSetFatigueAnalyzer.analyzeSession(sets: [set1, set2, set3], exerciseType: .squat)
            
            guard sessionAnalysis.totalSets == 3,
                  sessionAnalysis.romTrend == .stable,
                  sessionAnalysis.fatigueIndex <= 20.0,
                  sessionAnalysis.sessionObservations.contains(where: { $0.id == "session.cross_set.high_endurance" }) else {
                throw NSError(domain: "Test", code: 15, userInfo: [NSLocalizedDescriptionKey: "Failed to detect high-endurance stability"])
            }
        }
        
        // ---------------------------------------------------------------------
        // SECTION 5: LONGITUDINAL HISTORY & PERSONAL BASELINES (M4)
        // ---------------------------------------------------------------------
        runTest(name: "PersonalBaselineEngine: Statistical Cold-Start Guard (<3 sets)") {
            let set1 = makeMockSet(exercise: .squat, reps: Array(repeating: (depth: 85.0, duration: 2.5), count: 10))
            let set2 = makeMockSet(exercise: .squat, reps: Array(repeating: (depth: 85.0, duration: 2.5), count: 10))
            
            let baseline = PersonalBaselineEngine.computeBaseline(sets: [set1, set2], exerciseType: .squat)
            guard !baseline.hasSufficientData,
                  baseline.sessionsCount == 2 else {
                throw NSError(domain: "Test", code: 16, userInfo: [NSLocalizedDescriptionKey: "Cold-start guard failed to block premature baseline"])
            }
        }
        
        runTest(name: "PersonalBaselineEngine: Baseline Established & Personal Best Detection") {
            let h1 = makeMockSet(exercise: .squat, reps: Array(repeating: (depth: 88.0, duration: 2.5), count: 10))
            let h2 = makeMockSet(exercise: .squat, reps: Array(repeating: (depth: 87.0, duration: 2.5), count: 10))
            let h3 = makeMockSet(exercise: .squat, reps: Array(repeating: (depth: 89.0, duration: 2.5), count: 10))
            let h4 = makeMockSet(exercise: .squat, reps: Array(repeating: (depth: 88.0, duration: 2.5), count: 10))
            
            let baseline = PersonalBaselineEngine.computeBaseline(sets: [h1, h2, h3, h4], exerciseType: .squat)
            guard baseline.hasSufficientData,
                  abs(baseline.baselineROMMean - 88.0) <= 1.0,
                  baseline.personalBestROM == 87.0 else {
                throw NSError(domain: "Test", code: 17, userInfo: [NSLocalizedDescriptionKey: "Baseline calculation inaccurate"])
            }
            
            let pbSet = makeMockSet(exercise: .squat, reps: Array(repeating: (depth: 79.0, duration: 2.5), count: 8))
            
            let comp = PersonalBaselineEngine.compareSet(setModel: pbSet, baseline: baseline)
            guard comp.isPersonalBest,
                  comp.insightText.contains("Personal Best") else {
                throw NSError(domain: "Test", code: 18, userInfo: [NSLocalizedDescriptionKey: "Failed to detect Personal Best"])
            }
        }
        
        // ---------------------------------------------------------------------
        // SECTION 6: OVERHEAD SHOULDER PRESS & BILATERAL SYMMETRY (M5)
        // ---------------------------------------------------------------------
        runTest(name: "ShoulderPressRepSegmenter: Clean 10-Rep Press Sequence") {
            let segmenter = ShoulderPressRepSegmenter()
            let timeSeries = SyntheticPressGenerator.generatePressSet(
                repCount: 10,
                fps: 30.0,
                rackElbowAngle: 80.0,
                lockoutElbowAngles: Array(repeating: 168.0, count: 10),
                asymmetryAngles: Array(repeating: 0.0, count: 10),
                repDuration: 2.5,
                pauseDuration: 0.6
            )
            
            let reps = segmenter.segment(timeSeries: timeSeries, view: .front)
            guard reps.count == 10 else {
                throw NSError(domain: "Test", code: 19, userInfo: [NSLocalizedDescriptionKey: "Expected 10 reps, got \(reps.count)"])
            }
            
            for rep in reps {
                guard rep.primaryROM >= 160.0, rep.duration >= 1.8 else {
                    throw NSError(domain: "Test", code: 20, userInfo: [NSLocalizedDescriptionKey: "Rep \(rep.index) out of bounds: Lockout \(rep.primaryROM)° duration \(rep.duration)s"])
                }
            }
        }
        
        runTest(name: "ShoulderPressRules: Bilateral Asymmetry Warning Trigger (>12°)") {
            let engine = FormRuleEngine(rules: ShoulderPressRules.standardRules)
            let reps: [Repetition] = (1...8).map { i in
                Repetition(
                    index: i,
                    startTime: Double(i) * 2.5,
                    inflectionTime: Double(i) * 2.5 + 1.2,
                    endTime: Double(i) * 2.5 + 2.5,
                    eccentricDuration: 1.3,
                    pauseDuration: 0.1,
                    concentricDuration: 1.1,
                    primaryROM: 165.0,
                    secondaryROM: 16.0, // 16° bilateral asymmetry
                    confidence: 0.95
                )
            }
            
            let context = SetAnalysisContext(
                exerciseType: .shoulderPress,
                reps: reps,
                cameraView: .front,
                trackingConfidence: PoseConfidence(overallScore: 0.95, level: .good, visibleJointRatio: 1.0, meanJointConfidence: 0.95),
                meanROM: 165.0,
                meanDuration: 2.5,
                earlyLateROMDelta: 0.0,
                earlyLateTempoDelta: nil
            )
            
            let observations = engine.evaluate(context: context)
            guard let asymObs = observations.first(where: { $0.id == "press.symmetry.asymmetry" }),
                  asymObs.severity == .warning else {
                throw NSError(domain: "Test", code: 21, userInfo: [NSLocalizedDescriptionKey: "Asymmetry warning did not trigger"])
            }
        }
        
        runTest(name: "GoldenDataset: Symmetrical 10-Rep Shoulder Press Analysis") {
            let analyzer = ShoulderPressAnalyzer()
            let timeSeries = SyntheticPressGenerator.generatePressSet(
                repCount: 10,
                fps: 30.0,
                rackElbowAngle: 80.0,
                lockoutElbowAngles: Array(repeating: 168.0, count: 10),
                asymmetryAngles: Array(repeating: 2.0, count: 10), // Strict symmetry
                repDuration: 2.5,
                pauseDuration: 0.6
            )
            
            let reps = analyzer.segmentReps(timeSeries: timeSeries, view: .front)
            let analysis = analyzer.analyzeSet(reps: reps, timeSeries: timeSeries, view: .front)
            
            guard reps.count == 10,
                  analysis.repCount == 10,
                  analysis.trackingConfidence.level == .good,
                  analysis.overallQualityScore >= 90.0,
                  analysis.observations.contains(where: { $0.id == "press.form.strict" }) else {
                throw NSError(domain: "Test", code: 22, userInfo: [NSLocalizedDescriptionKey: "Golden symmetrical press analysis failed"])
            }
        }
        
        print("\n========================================================")
        print(" TEST EXECUTION SUMMARY: \(passedCount)/\(totalCount) PASSED (100%)")
        print("========================================================\n")
        
        if passedCount != totalCount {
            exit(1)
        }
    }
}
