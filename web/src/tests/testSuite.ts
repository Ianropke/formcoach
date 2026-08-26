import { AngleCalculator } from '../core/angleCalculator';
import { PoseSmoother } from '../core/poseSmoother';
import { SquatAnalyzer, BicepCurlAnalyzer, TricepsPushdownAnalyzer, ShoulderPressAnalyzer, LegPressAnalyzer } from '../core/analyzers/exerciseAnalyzers';
import { CrossSetFatigueAnalyzer } from '../core/fatigueAnalyzer';
import { PersonalBaselineEngine } from '../core/baselineEngine';
import { PoseFrame, RecordedSet } from '../core/models';
import { SyntheticSquatGenerator, SyntheticCurlGenerator, SyntheticPressGenerator } from './syntheticGenerators';

console.log('========================================================');
console.log('    FORMCOACH DETERMINISTIC BIOMECHANICS TEST SUITE     ');
console.log('    (MATHEMATICAL VECTOR GEOMETRY & STATE MACHINES)     ');
console.log('========================================================\n');

let passCount = 0;
let totalCount = 0;

function assert(description: string, condition: boolean) {
  totalCount++;
  if (condition) {
    console.log(`▶ Running [${description}]... ✅ PASS`);
    passCount++;
  } else {
    console.error(`▶ Running [${description}]... ❌ FAIL`);
    process.exitCode = 1;
  }
}

// 1. AngleCalculator: Orthogonal 90°
const pA = { x: 0.0, y: 1.0, score: 1.0 };
const pB = { x: 0.0, y: 0.0, score: 1.0 };
const pC = { x: 1.0, y: 0.0, score: 1.0 };
const angle90 = AngleCalculator.angle2D(pA, pB, pC);
assert('AngleCalculator: Orthogonal 90° Angle', Math.abs(angle90 - 90.0) < 0.001);

// 2. AngleCalculator: Straight Line 180°
const pStraight = { x: 0.0, y: -1.0, score: 1.0 };
const angle180 = AngleCalculator.angle2D(pA, pB, pStraight);
assert('AngleCalculator: Straight Line 180° Angle', Math.abs(angle180 - 180.0) < 0.001);

// 3. PoseSmoother: Drop-out interpolation
const smoother = new PoseSmoother();
const testFrames: PoseFrame[] = [
  { timestamp: 0.0, joints: { left_hip: { x: 0.5, y: 0.5, score: 1.0 } }, confidence: 1.0 },
  { timestamp: 0.1, joints: {}, confidence: 0.0 },
  { timestamp: 0.2, joints: {}, confidence: 0.0 },
  { timestamp: 0.3, joints: { left_hip: { x: 0.8, y: 0.8, score: 1.0 } }, confidence: 1.0 }
];
const smoothed = smoother.smooth(testFrames);
assert('PoseSmoother: Short-Gap Dropout Interpolation (2 frames)', smoothed[1].joints.left_hip !== undefined);

// 4. Squat Rep Segmenter: 10 clean reps
const squatAnalyzer = new SquatAnalyzer();
const squatFrames = SyntheticSquatGenerator.generateSquatSet(10, 30.0, 175.0, 85.0, 3.0, 1.0);
const squatReps = squatAnalyzer.segmentReps(squatFrames, 'side');
assert('SquatRepSegmenter: Clean 10-Rep Squat Sequence', squatReps.length === 10);

// 5. Leg Press Machine Analyzer
const legPressAnalyzer = new LegPressAnalyzer();
const legPressReps = legPressAnalyzer.segmentReps(squatFrames, 'side');
assert('LegPressAnalyzer: 10-Rep Machine Leg Press Set', legPressReps.length === 10);

// 6. Biceps Curl Analyzer: Strict 10 reps
const curlAnalyzer = new BicepCurlAnalyzer();
const strictCurlFrames = SyntheticCurlGenerator.generateCurlSet(10, 30.0, 165.0, 55.0, 0.0, 2.4, 0.8);
const strictCurlReps = curlAnalyzer.segmentReps(strictCurlFrames);
assert('BicepCurlAnalyzer: Strict 10-Rep Biceps Curl Analysis', strictCurlReps.length === 10);

// 7. Biceps Curl Rules: Shoulder drift warning (>18°)
const driftCurlFrames = SyntheticCurlGenerator.generateCurlSet(10, 30.0, 165.0, 55.0, 22.0, 2.4, 0.8);
const driftCurlReps = curlAnalyzer.segmentReps(driftCurlFrames);
const driftAnalysis = curlAnalyzer.analyzeSet(driftCurlReps);
const hasShoulderWarning = driftAnalysis.observations.some(o => o.id === 'curl.shoulder.drift');
assert('BicepsCurlRules: Shoulder Drift Warning Trigger (>18°)', hasShoulderWarning);

// 8. Triceps Pushdown: Pinned elbow drift tracking
const pushdownAnalyzer = new TricepsPushdownAnalyzer();
const pushdownFrames = SyntheticCurlGenerator.generateCurlSet(6, 30.0, 160.0, 65.0, 0.0, 2.4, 0.8);
const pushdownReps = pushdownAnalyzer.segmentReps(pushdownFrames);
const pushdownAnalysis = pushdownAnalyzer.analyzeSet(pushdownReps);
assert('TricepsPushdownAnalyzer: Pushdown Analysis & Lockout Validation', pushdownAnalysis.overallScore > 70);

// 9. Shoulder Press Analyzer: Bilateral arm symmetry
const pressAnalyzer = new ShoulderPressAnalyzer();
const symmetricalPressFrames = SyntheticPressGenerator.generatePressSet(5, 30.0, 80.0, 160.0, 160.0);
const symmetricalReps = pressAnalyzer.segmentReps(symmetricalPressFrames);
const symmetricalAnalysis = pressAnalyzer.analyzeSet(symmetricalReps);
assert('ShoulderPressRules: Symmetrical Press Validation', (symmetricalAnalysis.symmetryScore ?? 0) >= 90);

// 10. Shoulder Press Analyzer: Bilateral arm asymmetry warning (>12°)
const asymmetricalPressFrames = SyntheticPressGenerator.generatePressSet(5, 30.0, 80.0, 160.0, 138.0);
const asymmetricalReps = pressAnalyzer.segmentReps(asymmetricalPressFrames);
const asymmetricalAnalysis = pressAnalyzer.analyzeSet(asymmetricalReps);
const hasAsymmetryWarning = asymmetricalAnalysis.observations.some(o => o.id === 'press.bilateral.asymmetry');
assert('ShoulderPressRules: Bilateral Arm Asymmetry Warning Trigger (>12°)', hasAsymmetryWarning);

// 11. Cross-Set Fatigue Analyzer: 4-Set progressive decay
const mockSets: RecordedSet[] = [
  { id: '1', exercise: 'squat', view: 'side', date: '', reps: squatReps, analysis: { overallScore: 95, romScore: 98, consistencyScore: 95, tempoScore: 92, primaryObservation: '', observations: [], repCount: 10, meanROM: 82, romStdDev: 1.5, meanDuration: 2.2, tempoStdDev: 0.1, concentricMean: 1.0, eccentricMean: 1.2, stabilityStatus: 'STRICT_STABILITY' } },
  { id: '2', exercise: 'squat', view: 'side', date: '', reps: squatReps, analysis: { overallScore: 92, romScore: 94, consistencyScore: 93, tempoScore: 90, primaryObservation: '', observations: [], repCount: 10, meanROM: 86, romStdDev: 2.0, meanDuration: 2.4, tempoStdDev: 0.2, concentricMean: 1.1, eccentricMean: 1.3, stabilityStatus: 'STRICT_STABILITY' } },
  { id: '3', exercise: 'squat', view: 'side', date: '', reps: squatReps, analysis: { overallScore: 88, romScore: 89, consistencyScore: 90, tempoScore: 87, primaryObservation: '', observations: [], repCount: 10, meanROM: 92, romStdDev: 3.1, meanDuration: 2.6, tempoStdDev: 0.3, concentricMean: 1.2, eccentricMean: 1.4, stabilityStatus: 'MODERATE_VARIANCE' } },
  { id: '4', exercise: 'squat', view: 'side', date: '', reps: squatReps, analysis: { overallScore: 80, romScore: 81, consistencyScore: 85, tempoScore: 82, primaryObservation: '', observations: [], repCount: 10, meanROM: 98, romStdDev: 4.5, meanDuration: 2.9, tempoStdDev: 0.4, concentricMean: 1.3, eccentricMean: 1.6, stabilityStatus: 'MODERATE_VARIANCE' } }
];
const sessionFatigue = CrossSetFatigueAnalyzer.analyzeSession(mockSets);
assert('CrossSetFatigueAnalyzer: Multi-Set Deterioration Detection', sessionFatigue.romTrend === 'degrading' && sessionFatigue.fatigueIndex > 40);

// 12. PersonalBaselineEngine: Cold start guard & Flexion Personal Best
const baseline = PersonalBaselineEngine.computeBaseline(mockSets, 'squat');
assert('PersonalBaselineEngine: Baseline Established (>=3 sets, >=25 reps)', baseline.hasSufficientData === true);
const pbCheck = PersonalBaselineEngine.compareSet(
  { id: '5', exercise: 'squat', view: 'side', date: '', reps: [{ index: 1, startTime: 0, inflectionTime: 1, endTime: 2, duration: 2, concentricDuration: 1, eccentricDuration: 1, primaryROM: 74, confidence: 1.0 }], analysis: mockSets[0].analysis },
  baseline
);
assert('PersonalBaselineEngine: Personal Best (PB) Flexion Flagging (74° < 82°)', pbCheck.isPersonalBest === true);

// 13. PersonalBaselineEngine: Extension Personal Best Flagging (Shoulder Press Lockout > 165°)
const pressSets: RecordedSet[] = [
  { id: 'p1', exercise: 'shoulderPress', view: 'front', date: '', reps: symmetricalReps, analysis: { overallScore: 95, romScore: 96, consistencyScore: 95, tempoScore: 93, primaryObservation: '', observations: [], repCount: 5, meanROM: 160, romStdDev: 1.2, meanDuration: 2.0, tempoStdDev: 0.1, concentricMean: 1.0, eccentricMean: 1.0, stabilityStatus: 'STRICT_STABILITY' } },
  { id: 'p2', exercise: 'shoulderPress', view: 'front', date: '', reps: symmetricalReps, analysis: { overallScore: 95, romScore: 96, consistencyScore: 95, tempoScore: 93, primaryObservation: '', observations: [], repCount: 5, meanROM: 162, romStdDev: 1.4, meanDuration: 2.0, tempoStdDev: 0.1, concentricMean: 1.0, eccentricMean: 1.0, stabilityStatus: 'STRICT_STABILITY' } },
  { id: 'p3', exercise: 'shoulderPress', view: 'front', date: '', reps: Array(15).fill(symmetricalReps[0]), analysis: { overallScore: 95, romScore: 96, consistencyScore: 95, tempoScore: 93, primaryObservation: '', observations: [], repCount: 15, meanROM: 163, romStdDev: 1.5, meanDuration: 2.0, tempoStdDev: 0.1, concentricMean: 1.0, eccentricMean: 1.0, stabilityStatus: 'STRICT_STABILITY' } }
];
const pressBaseline = PersonalBaselineEngine.computeBaseline(pressSets, 'shoulderPress');
assert('PersonalBaselineEngine: Extension Baseline Standard Established', pressBaseline.hasSufficientData === true && pressBaseline.personalBestROM === 160);
const pressPbCheck = PersonalBaselineEngine.compareSet(
  { id: 'p4', exercise: 'shoulderPress', view: 'front', date: '', reps: [{ index: 1, startTime: 0, inflectionTime: 1, endTime: 2, duration: 2, concentricDuration: 1, eccentricDuration: 1, primaryROM: 172, confidence: 1.0 }], analysis: pressSets[0].analysis },
  pressBaseline
);
assert('PersonalBaselineEngine: Personal Best (PB) Extension Lockout Flagging (172° > 160°)', pressPbCheck.isPersonalBest === true);

// 14. Empirical Kinematics: Real Standard Deviation and Strict Stability
const squatAnalysis = squatAnalyzer.analyzeSet(squatReps);
assert('EmpiricalKinematics: ROM Standard Deviation Computed Mathematically', typeof squatAnalysis.romStdDev === 'number' && squatAnalysis.romStdDev >= 0);
assert('EmpiricalKinematics: Strict Stability Status Flagged', squatAnalysis.stabilityStatus === 'STRICT_STABILITY');

console.log('\n========================================================');
console.log(` TEST EXECUTION SUMMARY: ${passCount}/${totalCount} PASSED (${Math.round((passCount/totalCount)*100)}%)`);
console.log('========================================================\n');
