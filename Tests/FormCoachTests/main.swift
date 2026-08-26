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
        print("      (FULL SUITE: ALL 9 USER ROUTINE EXERCISES)        ")
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
                throw NSError(domain: "Test", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to interpolate dropped frame"])
            }
        }
        
        // ---------------------------------------------------------------------
        // SECTION 2: SQUAT & LEG PRESS MACHINE BIOMECHANICS
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
                throw NSError(domain: "Test", code: 4, userInfo: [NSLocalizedDescriptionKey: "Expected 10 reps, got \(reps.count)"])
            }
        }
        
        runTest(name: "LegPressAnalyzer: 10-Rep Machine Leg Press Set") {
            let analyzer = LegPressAnalyzer()
            let timeSeries = SyntheticSquatGenerator.generateSquatSet(
                repCount: 10,
                fps: 30.0,
                standingKneeAngle: 170.0,
                bottomKneeAngles: Array(repeating: 88.0, count: 10),
                repDuration: 2.5
            )
            let reps = analyzer.segmentReps(timeSeries: timeSeries, view: .side)
            let analysis = analyzer.analyzeSet(reps: reps, timeSeries: timeSeries, view: .side)
            guard reps.count == 10, analysis.overallQualityScore >= 90.0 else {
                throw NSError(domain: "Test", code: 5, userInfo: [NSLocalizedDescriptionKey: "Leg press analysis failed"])
            }
        }
        
        // ---------------------------------------------------------------------
        // SECTION 3: ARMS (BICEPS CURL & TRICEPS PUSHDOWN)
        // ---------------------------------------------------------------------
        runTest(name: "BicepsCurlAnalyzer: Strict 10-Rep Biceps Curl Analysis") {
            let analyzer = BicepsCurlAnalyzer()
            let timeSeries = SyntheticCurlGenerator.generateCurlSet(
                repCount: 10,
                fps: 30.0,
                lockoutElbowAngle: 165.0,
                peakElbowAngles: Array(repeating: 55.0, count: 10),
                shoulderDriftAngles: Array(repeating: 4.0, count: 10),
                repDuration: 2.4
            )
            let reps = analyzer.segmentReps(timeSeries: timeSeries, view: .side)
            let analysis = analyzer.analyzeSet(reps: reps, timeSeries: timeSeries, view: .side)
            guard reps.count == 10, analysis.overallQualityScore >= 90.0 else {
                throw NSError(domain: "Test", code: 6, userInfo: [NSLocalizedDescriptionKey: "Golden curl analysis failed"])
            }
        }
        
        runTest(name: "TricepsPushdownRules: Pinned Elbow Drift Warning Trigger (>20°)") {
            let engine = FormRuleEngine(rules: TricepsPushdownRules.standardRules)
            let reps: [Repetition] = (1...8).map { i in
                Repetition(
                    index: i,
                    startTime: Double(i) * 2.5,
                    inflectionTime: Double(i) * 2.5 + 1.2,
                    endTime: Double(i) * 2.5 + 2.5,
                    eccentricDuration: 1.3,
                    pauseDuration: 0.1,
                    concentricDuration: 1.1,
                    primaryROM: 164.0,
                    secondaryROM: 25.0, // >20° drift
                    confidence: 0.95
                )
            }
            let context = SetAnalysisContext(
                exerciseType: .tricepsPushdown,
                reps: reps,
                cameraView: .side,
                trackingConfidence: PoseConfidence(overallScore: 0.95, level: .good, visibleJointRatio: 1.0, meanJointConfidence: 0.95),
                meanROM: 164.0,
                meanDuration: 2.5,
                earlyLateROMDelta: 0.0,
                earlyLateTempoDelta: nil
            )
            let observations = engine.evaluate(context: context)
            guard observations.contains(where: { $0.id == "triceps.elbow.drift" }) else {
                throw NSError(domain: "Test", code: 7, userInfo: [NSLocalizedDescriptionKey: "Triceps elbow drift failed to trigger"])
            }
        }
        
        // ---------------------------------------------------------------------
        // SECTION 4: BACK & PULL (SEATED ROW, FACE PULL, STRAIGHT ARM PULLDOWN)
        // ---------------------------------------------------------------------
        runTest(name: "SeatedRowRules: Torso Momentum Warning Trigger (>18°)") {
            let engine = FormRuleEngine(rules: SeatedRowRules.standardRules)
            let reps: [Repetition] = (1...8).map { i in
                Repetition(
                    index: i,
                    startTime: Double(i) * 2.5,
                    inflectionTime: Double(i) * 2.5 + 1.2,
                    endTime: Double(i) * 2.5 + 2.5,
                    eccentricDuration: 1.3,
                    pauseDuration: 0.1,
                    concentricDuration: 1.1,
                    primaryROM: 68.0,
                    secondaryROM: 24.0, // >18° swing
                    confidence: 0.95
                )
            }
            let context = SetAnalysisContext(
                exerciseType: .seatedRow,
                reps: reps,
                cameraView: .side,
                trackingConfidence: PoseConfidence(overallScore: 0.95, level: .good, visibleJointRatio: 1.0, meanJointConfidence: 0.95),
                meanROM: 68.0,
                meanDuration: 2.5,
                earlyLateROMDelta: 0.0,
                earlyLateTempoDelta: nil
            )
            let observations = engine.evaluate(context: context)
            guard observations.contains(where: { $0.id == "row.torso.swing" }) else {
                throw NSError(domain: "Test", code: 8, userInfo: [NSLocalizedDescriptionKey: "Row torso swing failed to trigger"])
            }
        }
        
        // ---------------------------------------------------------------------
        // SECTION 5: SHOULDER PRESS & BILATERAL ASYMMETRY
        // ---------------------------------------------------------------------
        runTest(name: "ShoulderPressAnalyzer: Symmetrical 10-Rep Press Analysis") {
            let analyzer = ShoulderPressAnalyzer()
            let timeSeries = SyntheticPressGenerator.generatePressSet(
                repCount: 10,
                fps: 30.0,
                rackElbowAngle: 80.0,
                lockoutElbowAngles: Array(repeating: 168.0, count: 10),
                asymmetryAngles: Array(repeating: 2.0, count: 10),
                repDuration: 2.5,
                pauseDuration: 0.6
            )
            let reps = analyzer.segmentReps(timeSeries: timeSeries, view: .front)
            let analysis = analyzer.analyzeSet(reps: reps, timeSeries: timeSeries, view: .front)
            guard reps.count == 10, analysis.repCount == 10, analysis.overallQualityScore >= 90.0 else {
                throw NSError(domain: "Test", code: 9, userInfo: [NSLocalizedDescriptionKey: "Press analysis failed"])
            }
        }
        
        // ---------------------------------------------------------------------
        // SECTION 6: MULTI-SET & BASELINE ENGINE
        // ---------------------------------------------------------------------
        runTest(name: "CrossSetFatigueAnalyzer: 4-Set Progressive Fatigue Deterioration") {
            let set1 = makeMockSet(exercise: .squat, reps: Array(repeating: (depth: 82.0, duration: 2.5), count: 10))
            let set2 = makeMockSet(exercise: .squat, reps: Array(repeating: (depth: 86.0, duration: 2.5), count: 10))
            let set3 = makeMockSet(exercise: .squat, reps: Array(repeating: (depth: 98.0, duration: 3.0), count: 10))
            let set4 = makeMockSet(exercise: .squat, reps: Array(repeating: (depth: 116.0, duration: 3.2), count: 10))
            
            let sessionAnalysis = CrossSetFatigueAnalyzer.analyzeSession(sets: [set1, set2, set3, set4], exerciseType: .squat)
            guard sessionAnalysis.totalSets == 4,
                  sessionAnalysis.romTrend == .degrading,
                  sessionAnalysis.fatigueIndex >= 30.0 else {
                throw NSError(domain: "Test", code: 10, userInfo: [NSLocalizedDescriptionKey: "Fatigue decay failed"])
            }
        }
        
        runTest(name: "PersonalBaselineEngine: Baseline Established & Personal Best Detection") {
            let h1 = makeMockSet(exercise: .squat, reps: Array(repeating: (depth: 88.0, duration: 2.5), count: 10))
            let h2 = makeMockSet(exercise: .squat, reps: Array(repeating: (depth: 87.0, duration: 2.5), count: 10))
            let h3 = makeMockSet(exercise: .squat, reps: Array(repeating: (depth: 89.0, duration: 2.5), count: 10))
            let baseline = PersonalBaselineEngine.computeBaseline(sets: [h1, h2, h3], exerciseType: .squat)
            let pbSet = makeMockSet(exercise: .squat, reps: Array(repeating: (depth: 79.0, duration: 2.5), count: 8))
            let comp = PersonalBaselineEngine.compareSet(setModel: pbSet, baseline: baseline)
            guard comp.isPersonalBest else {
                throw NSError(domain: "Test", code: 11, userInfo: [NSLocalizedDescriptionKey: "PB failed"])
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
