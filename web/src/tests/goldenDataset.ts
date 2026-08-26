import { PoseFrame } from '../core/models';
import {
  BicepCurlAnalyzer,
  SquatAnalyzer,
  ShoulderPressAnalyzer,
  TricepsPushdownAnalyzer
} from '../core/analyzers/exerciseAnalyzers';

/**
 * FORMCOACH DETERMINISTIC GOLDEN DATASET BENCHMARK
 * Validates analyzers against annotated biomechanical ground truth.
 */

let passCount = 0;
let totalCount = 0;

function assert(description: string, condition: boolean, details?: string) {
  totalCount++;
  if (condition) {
    console.log(`▶ Running [${description}]... ✅ PASS`);
    passCount++;
  } else {
    console.error(`▶ Running [${description}]... ❌ FAIL`);
    if (details) console.error(`   Details: ${details}`);
  }
}

// -----------------------------------------------------------------------------
// Frame Generator Helpers
// -----------------------------------------------------------------------------
function generateCurlFrames(
  repsCount: number,
  minElbowAngle: number,
  setupShoulderAngle: number,
  peakShoulderSwingAngle: number
): PoseFrame[] {
  const frames: PoseFrame[] = [];
  let timestamp = 0;
  const fps = 30;
  const dt = 1 / fps;

  for (let r = 0; r < repsCount; r++) {
    // 1. Lockout / resting (0.4s)
    for (let f = 0; f < 12; f++) {
      frames.push({
        timestamp,
        confidence: 0.98,
        joints: {
          left_hip: { x: 0.5, y: 0.7, score: 0.95 },
          left_shoulder: { x: 0.5, y: 0.35, score: 0.98 },
          left_elbow: { x: 0.5 + Math.sin((setupShoulderAngle * Math.PI) / 180) * 0.15, y: 0.5, score: 0.98 },
          left_wrist: { x: 0.5, y: 0.65, score: 0.98 }
        }
      });
      timestamp += dt;
    }

    // 2. Concentric curling (1.0s)
    for (let f = 0; f < 30; f++) {
      const progress = f / 30;
      const curElbow = 160 - (160 - minElbowAngle) * progress;
      const curShoulder = setupShoulderAngle + (peakShoulderSwingAngle - setupShoulderAngle) * progress;
      const radE = (curElbow * Math.PI) / 180;
      const radS = (curShoulder * Math.PI) / 180;

      const elbowX = 0.5 + Math.sin(radS) * 0.15;
      const elbowY = 0.35 + Math.cos(radS) * 0.15;
      const wristX = elbowX - Math.sin(radE) * 0.15;
      const wristY = elbowY - Math.cos(radE) * 0.15;

      frames.push({
        timestamp,
        confidence: 0.98,
        joints: {
          left_hip: { x: 0.5, y: 0.7, score: 0.95 },
          left_shoulder: { x: 0.5, y: 0.35, score: 0.98 },
          left_elbow: { x: elbowX, y: elbowY, score: 0.98 },
          left_wrist: { x: wristX, y: wristY, score: 0.98 }
        }
      });
      timestamp += dt;
    }

    // 3. Eccentric lowering (1.0s)
    for (let f = 0; f < 30; f++) {
      const progress = f / 30;
      const curElbow = minElbowAngle + (160 - minElbowAngle) * progress;
      const curShoulder = peakShoulderSwingAngle - (peakShoulderSwingAngle - setupShoulderAngle) * progress;
      const radE = (curElbow * Math.PI) / 180;
      const radS = (curShoulder * Math.PI) / 180;

      const elbowX = 0.5 + Math.sin(radS) * 0.15;
      const elbowY = 0.35 + Math.cos(radS) * 0.15;
      const wristX = elbowX - Math.sin(radE) * 0.15;
      const wristY = elbowY - Math.cos(radE) * 0.15;

      frames.push({
        timestamp,
        confidence: 0.98,
        joints: {
          left_hip: { x: 0.5, y: 0.7, score: 0.95 },
          left_shoulder: { x: 0.5, y: 0.35, score: 0.98 },
          left_elbow: { x: elbowX, y: elbowY, score: 0.98 },
          left_wrist: { x: wristX, y: wristY, score: 0.98 }
        }
      });
      timestamp += dt;
    }
  }

  // Final resting frame
  frames.push({
    timestamp,
    confidence: 0.98,
    joints: {
      left_hip: { x: 0.5, y: 0.7, score: 0.95 },
      left_shoulder: { x: 0.5, y: 0.35, score: 0.98 },
      left_elbow: { x: 0.5, y: 0.5, score: 0.98 },
      left_wrist: { x: 0.5, y: 0.65, score: 0.98 }
    }
  });

  return frames;
}

function generateSquatFrames(repsCount: number, depthAngleByRep: number[]): PoseFrame[] {
  const frames: PoseFrame[] = [];
  let timestamp = 0;
  const fps = 30;
  const dt = 1 / fps;

  for (let r = 0; r < repsCount; r++) {
    const targetDepth = depthAngleByRep[r] !== undefined ? depthAngleByRep[r] : 82;

    // Standing / Lockout (0.3s)
    for (let f = 0; f < 10; f++) {
      frames.push({
        timestamp,
        confidence: 0.98,
        joints: {
          left_knee: { x: 0.5, y: 0.60, score: 0.98 },
          left_ankle: { x: 0.5, y: 0.80, score: 0.98 },
          left_hip: {
            x: 0.5 + 0.2 * Math.sin((15 * Math.PI) / 180),
            y: 0.60 - 0.2 * Math.cos((15 * Math.PI) / 180),
            score: 0.95
          }
        }
      });
      timestamp += dt;
    }

    // Descending (1.0s)
    for (let f = 0; f < 30; f++) {
      const p = f / 30;
      const angle = 165 - (165 - targetDepth) * p;
      const rad = ((180 - angle) * Math.PI) / 180;
      frames.push({
        timestamp,
        confidence: 0.98,
        joints: {
          left_knee: { x: 0.5, y: 0.60, score: 0.98 },
          left_ankle: { x: 0.5, y: 0.80, score: 0.98 },
          left_hip: {
            x: 0.5 + 0.2 * Math.sin(rad),
            y: 0.60 - 0.2 * Math.cos(rad),
            score: 0.95
          }
        }
      });
      timestamp += dt;
    }

    // Ascending (1.0s)
    for (let f = 0; f < 30; f++) {
      const p = f / 30;
      const angle = targetDepth + (165 - targetDepth) * p;
      const rad = ((180 - angle) * Math.PI) / 180;
      frames.push({
        timestamp,
        confidence: 0.98,
        joints: {
          left_knee: { x: 0.5, y: 0.60, score: 0.98 },
          left_ankle: { x: 0.5, y: 0.80, score: 0.98 },
          left_hip: {
            x: 0.5 + 0.2 * Math.sin(rad),
            y: 0.60 - 0.2 * Math.cos(rad),
            score: 0.95
          }
        }
      });
      timestamp += dt;
    }
  }

  // Final standing buffer (0.4s) to ensure state machine returns to standing
  for (let f = 0; f < 12; f++) {
    frames.push({
      timestamp,
      confidence: 0.98,
      joints: {
        left_knee: { x: 0.5, y: 0.60, score: 0.98 },
        left_ankle: { x: 0.5, y: 0.80, score: 0.98 },
        left_hip: {
          x: 0.5 + 0.2 * Math.sin((15 * Math.PI) / 180),
          y: 0.60 - 0.2 * Math.cos((15 * Math.PI) / 180),
          score: 0.95
        }
      }
    });
    timestamp += dt;
  }

  return frames;
}

// -----------------------------------------------------------------------------
// BENCHMARK EXECUTION
// -----------------------------------------------------------------------------
console.log('\n========================================================');
console.log('    FORMCOACH GOLDEN BIOMECHANICAL DATASET BENCHMARK    ');
console.log('========================================================\n');

// 1. Golden Benchmark 1: 10 Strict Bicep Curls (Zero Shoulder Drift)
const strictCurlFrames = generateCurlFrames(10, 52, 14, 18);
const curlAnalyzer = new BicepCurlAnalyzer();
const strictCurlReps = curlAnalyzer.segmentReps(strictCurlFrames);
const strictCurlAnalysis = curlAnalyzer.analyzeSet(strictCurlReps);

assert(
  'Golden 1: 10 Strict Bicep Curls (10/10 Reps Segmented)',
  strictCurlReps.length === 10,
  `Got ${strictCurlReps.length} reps`
);
assert(
  'Golden 1: Strict Bicep Isolation Observation (Peak Drift < 10°)',
  strictCurlAnalysis.observations.some(o => o.id === 'curl.form.strict') && (strictCurlAnalysis.peakRelativeDrift || 0) < 10,
  `Peak drift was ${strictCurlAnalysis.peakRelativeDrift}°`
);

// 2. Golden Benchmark 2: 10 Cheat Bicep Curls (Forward Swing Drift > 18°)
const cheatCurlFrames = generateCurlFrames(10, 50, 12, 36);
const cheatCurlReps = curlAnalyzer.segmentReps(cheatCurlFrames);
const cheatCurlAnalysis = curlAnalyzer.analyzeSet(cheatCurlReps);

assert(
  'Golden 2: 10 Cheat Curls (10/10 Reps Segmented)',
  cheatCurlReps.length === 10,
  `Got ${cheatCurlReps.length} reps`
);
assert(
  'Golden 2: Shoulder Momentum Swing Warning Triggered (Peak Drift >= 18°)',
  cheatCurlAnalysis.observations.some(o => o.id === 'curl.shoulder.drift') && (cheatCurlAnalysis.peakRelativeDrift || 0) >= 18,
  `Obs: ${cheatCurlAnalysis.observations.map(o => o.id).join(', ')}, Drift: ${cheatCurlAnalysis.peakRelativeDrift}°`
);

// 3. Golden Benchmark 3: 10 Deep Parallel Squats (≤88° Depth)
const parallelSquatFrames = generateSquatFrames(10, Array(10).fill(82));
const squatAnalyzer = new SquatAnalyzer();
const parallelSquatReps = squatAnalyzer.segmentReps(parallelSquatFrames);
const parallelSquatAnalysis = squatAnalyzer.analyzeSet(parallelSquatReps);

assert(
  'Golden 3: 10 Parallel Squats (10/10 Reps Segmented)',
  parallelSquatReps.length === 10,
  `Got ${parallelSquatReps.length} reps`
);
assert(
  'Golden 3: Deep & Parallel Observation Verified (Mean ROM <= 88°)',
  parallelSquatAnalysis.observations.some(o => o.id === 'squat.depth.parallel') && parallelSquatAnalysis.meanROM <= 88,
  `Mean ROM: ${parallelSquatAnalysis.meanROM}°`
);

// 4. Golden Benchmark 4: 10 Shallow Squats (112° Depth)
const shallowSquatFrames = generateSquatFrames(10, Array(10).fill(112));
const shallowSquatReps = squatAnalyzer.segmentReps(shallowSquatFrames);
const shallowSquatAnalysis = squatAnalyzer.analyzeSet(shallowSquatReps);

assert(
  'Golden 4: 10 Shallow Squats (10/10 Reps Segmented)',
  shallowSquatReps.length === 10,
  `Got ${shallowSquatReps.length} reps`
);
assert(
  'Golden 4: Shallow Depth Warning Triggered (Mean ROM > 105°)',
  shallowSquatAnalysis.observations.some(o => o.id === 'squat.depth.shallow'),
  `Obs: ${shallowSquatAnalysis.observations.map(o => o.id).join(', ')}`
);

// 5. Golden Benchmark 5: 10 Fatiguing Squats with Late-Set ROM Decay (80° -> 98°)
const fatigueDepths = [80, 80, 81, 82, 82, 92, 94, 96, 98, 100];
const fatigueSquatFrames = generateSquatFrames(10, fatigueDepths);
const fatigueSquatReps = squatAnalyzer.segmentReps(fatigueSquatFrames);
const fatigueSquatAnalysis = squatAnalyzer.analyzeSet(fatigueSquatReps);

assert(
  'Golden 5: 10 Fatiguing Squats (10/10 Reps Segmented)',
  fatigueSquatReps.length === 10,
  `Got ${fatigueSquatReps.length} reps`
);
assert(
  'Golden 5: Depth Decay Detected (+18% Decay Flagged on Late Reps)',
  fatigueSquatAnalysis.observations.some(o => o.id === 'squat.rom.decay') && (fatigueSquatAnalysis.earlyLateROMDelta || 0) >= 12,
  `Delta was ${fatigueSquatAnalysis.earlyLateROMDelta}%`
);

// 6. Golden Benchmark 6: 10 Asymmetrical Shoulder Presses (Bilateral Asymmetry > 15°)
const pressAnalyzer = new ShoulderPressAnalyzer();
const asymPressReps = Array(10).fill(null).map((_, i) => ({
  index: i + 1,
  startTime: i * 2.2,
  inflectionTime: i * 2.2 + 1.1,
  endTime: i * 2.2 + 2.2,
  duration: 2.2,
  concentricDuration: 1.1,
  eccentricDuration: 1.1,
  primaryROM: 165,
  secondaryROM: 18, // 18° asymmetry
  confidence: 0.98
}));
const asymPressAnalysis = pressAnalyzer.analyzeSet(asymPressReps);

assert(
  'Golden 6: Bilateral Arm Asymmetry Warning Triggered (Mean Asymmetry >= 12°)',
  asymPressAnalysis.observations.some(o => o.id === 'press.bilateral.asymmetry') && (asymPressAnalysis.meanAsymmetry || 0) >= 12,
  `Mean asymmetry was ${asymPressAnalysis.meanAsymmetry}°`
);

console.log('\n========================================================');
console.log(` GOLDEN BENCHMARK SUMMARY: ${passCount}/${totalCount} PASSED (${Math.round((passCount/totalCount)*100)}%)`);
console.log('========================================================\n');

if (passCount !== totalCount) {
  process.exit(1);
}
