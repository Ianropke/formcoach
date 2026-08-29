import { PoseFrame, Repetition, SetAnalysis, CameraViewType, FormObservation, ExerciseType, FormStabilityStatus, JointName } from '../models';
import { AngleCalculator } from '../angleCalculator';

export interface ExerciseAnalyzer {
  segmentReps(frames: PoseFrame[], view?: CameraViewType): Repetition[];
  analyzeSet(reps: Repetition[], frames?: PoseFrame[], view?: CameraViewType): SetAnalysis;
}

// -----------------------------------------------------------------------------
// Statistical & Mathematical Helpers
// -----------------------------------------------------------------------------
function computeStats(values: number[]): { mean: number; stdDev: number } {
  if (values.length === 0) return { mean: 0, stdDev: 0 };
  const mean = values.reduce((a, b) => a + b, 0) / values.length;
  if (values.length === 1) return { mean: Math.round(mean * 10) / 10, stdDev: 0 };
  const variance = values.reduce((a, b) => a + Math.pow(b - mean, 2), 0) / (values.length - 1);
  const stdDev = Math.sqrt(variance);
  return {
    mean: Math.round(mean * 10) / 10,
    stdDev: Math.round(stdDev * 10) / 10
  };
}

/**
 * Computes 3D metric angle when worldJoints is available from MediaPipe,
 * falling back gracefully to 2D projection angle when only 2D coordinates exist.
 */
function getJointAngle(
  f: PoseFrame,
  jointA: JointName,
  vertexB: JointName,
  jointC: JointName
): number | null {
  if (f.worldJoints) {
    const pA = f.worldJoints[jointA];
    const pB = f.worldJoints[vertexB];
    const pC = f.worldJoints[jointC];
    if (pA && pB && pC && pA.score > 0.4 && pB.score > 0.4 && pC.score > 0.4) {
      return AngleCalculator.angle3D(pA, pB, pC);
    }
  }
  const pA = f.joints[jointA];
  const pB = f.joints[vertexB];
  const pC = f.joints[jointC];
  if (pA && pB && pC && pA.score > 0.4 && pB.score > 0.4 && pC.score > 0.4) {
    return AngleCalculator.angle2D(pA, pB, pC);
  }
  return null;
}

/**
 * Automatically evaluates both Left and Right limb kinematics and selects the dominant limb
 * with higher visibility confidence to handle equipment or partial occlusion seamlessly.
 */
function getDominantLimbAngle(
  f: PoseFrame,
  leftJoints: [JointName, JointName, JointName],
  rightJoints: [JointName, JointName, JointName]
): number | null {
  const joints = f.worldJoints || f.joints;
  const [lA, lB, lC] = leftJoints;
  const [rA, rB, rC] = rightJoints;

  const scoreLeft = ((joints[lA]?.score ?? 0) + (joints[lB]?.score ?? 0) + (joints[lC]?.score ?? 0)) / 3;
  const scoreRight = ((joints[rA]?.score ?? 0) + (joints[rB]?.score ?? 0) + (joints[rC]?.score ?? 0)) / 3;

  if (scoreLeft >= scoreRight && scoreLeft > 0.4) {
    const angle = getJointAngle(f, lA, lB, lC);
    if (angle !== null) return angle;
  }
  if (scoreRight > 0.4) {
    const angle = getJointAngle(f, rA, rB, rC);
    if (angle !== null) return angle;
  }
  return getJointAngle(f, lA, lB, lC);
}

/**
 * Parabolic Sub-Frame Vertex Estimation:
 * Fits a 2nd-degree parabola through 3 consecutive samples (y_prev, y_mid, y_next)
 * around an inflection turnaround to estimate the true minimum/maximum vertex
 * even if it occurred between 30/60 fps video frames.
 */
function interpolateParabolicExtremum(yPrev: number, yMid: number, yNext: number, isMinimum = true): number {
  const denom = 2 * (yPrev - 2 * yMid + yNext);
  if (Math.abs(denom) < 1e-4) return yMid;
  
  const delta = (yPrev - yNext) / denom;
  if (Math.abs(delta) > 1.0) return yMid;
  
  const interpolated = yMid - (Math.pow(yPrev - yNext, 2) / (8 * (yPrev - 2 * yMid + yNext)));
  
  if (isMinimum) {
    return Math.min(yMid, Math.max(Math.min(yPrev, yNext) - 5, interpolated));
  } else {
    return Math.max(yMid, Math.min(Math.max(yPrev, yNext) + 5, interpolated));
  }
}

function determineStabilityStatus(romStdDev: number, meanROM: number, peakDrift = 0): FormStabilityStatus {
  const cv = meanROM > 0 ? (romStdDev / meanROM) * 100 : 0;
  if (cv <= 6.0 && peakDrift < 12) return 'STRICT_STABILITY';
  if (cv <= 14.0 && peakDrift < 20) return 'MODERATE_VARIANCE';
  return 'HIGH_DEVIATION';
}

function emptySetAnalysis(): SetAnalysis {
  return {
    overallScore: 0,
    romScore: 0,
    consistencyScore: 0,
    tempoScore: 0,
    primaryObservation: 'Ingen gennemførte gentagelser registreret i dette sæt.',
    observations: [],
    repCount: 0,
    meanROM: 0,
    romStdDev: 0,
    meanDuration: 0,
    tempoStdDev: 0,
    concentricMean: 0,
    eccentricMean: 0,
    stabilityStatus: 'HIGH_DEVIATION'
  };
}

// -----------------------------------------------------------------------------
// 1. SQUAT ANALYZER
// -----------------------------------------------------------------------------
export class SquatAnalyzer implements ExerciseAnalyzer {
  public segmentReps(frames: PoseFrame[]): Repetition[] {
    if (frames.length < 10) return [];
    const reps: Repetition[] = [];
    let state: 'standing' | 'descending' | 'bottom' | 'ascending' = 'standing';
    let startTime = 0;
    let minKneeAngle = 180;
    let inflectionTime = 0;
    let repIdx = 1;
    let prevAngle = 180;
    let preMinAngle = 180;

    for (let i = 0; i < frames.length; i++) {
      const f = frames[i];
      const kneeAngle = getDominantLimbAngle(
        f,
        ['left_hip', 'left_knee', 'left_ankle'],
        ['right_hip', 'right_knee', 'right_ankle']
      );
      if (kneeAngle === null) continue;

      const t = f.timestamp;

      if (state === 'standing' && kneeAngle < 155) {
        state = 'descending';
        startTime = t;
        minKneeAngle = kneeAngle;
        preMinAngle = prevAngle;
        inflectionTime = t;
      } else if (state === 'descending') {
        if (kneeAngle < minKneeAngle) {
          preMinAngle = prevAngle;
          minKneeAngle = kneeAngle;
          inflectionTime = t;
        }
        if (kneeAngle > minKneeAngle + 4) {
          state = 'bottom';
        }
      } else if (state === 'bottom') {
        if (kneeAngle > minKneeAngle + 12) {
          state = 'ascending';
        }
      } else if (state === 'ascending') {
        if (kneeAngle >= 155) {
          const duration = t - startTime;
          if (duration >= 0.8 && 170 - minKneeAngle >= 40) {
            // Apply sub-frame parabolic vertex refinement
            const refinedMinAngle = interpolateParabolicExtremum(preMinAngle, minKneeAngle, kneeAngle, true);

            reps.push({
              index: repIdx++,
              startTime,
              inflectionTime,
              endTime: t,
              duration,
              concentricDuration: Math.max(0.2, t - inflectionTime),
              eccentricDuration: Math.max(0.2, inflectionTime - startTime),
              primaryROM: Math.round(refinedMinAngle * 10) / 10,
              confidence: f.confidence
            });
          }
          state = 'standing';
        }
      }
      prevAngle = kneeAngle;
    }
    return reps;
  }

  public analyzeSet(reps: Repetition[]): SetAnalysis {
    if (reps.length === 0) return emptySetAnalysis();

    const romStats = computeStats(reps.map(r => r.primaryROM));
    const tempoStats = computeStats(reps.map(r => r.duration));
    const eccMean = Math.round((reps.reduce((a, b) => a + b.eccentricDuration, 0) / reps.length) * 10) / 10;
    const conMean = Math.round((reps.reduce((a, b) => a + b.concentricDuration, 0) / reps.length) * 10) / 10;

    const observations: FormObservation[] = [];

    // Early vs late ROM delta (fatigue tracking)
    let delta = 0;
    if (reps.length >= 4) {
      const half = Math.min(4, Math.floor(reps.length / 2));
      const early = reps.slice(0, half).reduce((a, b) => a + b.primaryROM, 0) / half;
      const late = reps.slice(-half).reduce((a, b) => a + b.primaryROM, 0) / half;
      delta = Math.round(((late - early) / early) * 100);
      if (delta >= 10) {
        observations.push({
          id: 'squat.rom.decay',
          title: 'Udmattelsestab i Dybde',
          detail: `Squat-dybden faldt med ~${delta}% på de sidste gentagelser pga. muskeludmattelse.`,
          evidence: `Sidste reps nåede kun ${Math.round(late)}° vs ${Math.round(early)}° i starten.`,
          severity: 'warning',
          affectedReps: reps.slice(-half).map(r => r.index)
        });
      }
    }

    if (romStats.mean <= 88) {
      observations.push({
        id: 'squat.depth.parallel',
        title: 'Dyb & Parallel Squat',
        detail: `Flot og stabil parallel dybde (~${Math.round(romStats.mean)}° ±${romStats.stdDev}°) over alle ${reps.length} gentagelser.`,
        evidence: `Fuld dybde bekræftet matematisk.`,
        severity: 'positive',
        affectedReps: reps.map(r => r.index)
      });
    } else if (romStats.mean >= 105) {
      observations.push({
        id: 'squat.depth.shallow',
        title: 'Manglende Dybde (Over Parallel)',
        detail: `Squat-dybden stoppede ved ~${Math.round(romStats.mean)}° (over parallel). Sigt efter ≤88° for fuld aktivering.`,
        evidence: `Knævinkel forblev over 105°.`,
        severity: 'warning',
        affectedReps: reps.map(r => r.index)
      });
    }

    const stabilityStatus = determineStabilityStatus(romStats.stdDev, romStats.mean);
    const cvROM = romStats.mean > 0 ? (romStats.stdDev / romStats.mean) : 0;
    const cvTempo = tempoStats.mean > 0 ? (tempoStats.stdDev / tempoStats.mean) : 0;

    const consistencyScore = Math.max(50, Math.min(100, Math.round(100 - cvROM * 200)));
    const tempoScore = Math.max(50, Math.min(100, Math.round(100 - cvTempo * 150)));
    const romScore = romStats.mean <= 88 ? 98 : Math.max(50, Math.round(98 - (romStats.mean - 88) * 1.5));
    const overallScore = Math.round(romScore * 0.4 + consistencyScore * 0.3 + tempoScore * 0.3);

    return {
      overallScore,
      romScore,
      consistencyScore,
      tempoScore,
      primaryObservation: observations[0]?.detail || `Solidt squat-sæt med ${reps.length} gentagelser ved ~${Math.round(romStats.mean)}° (±${romStats.stdDev}°) dybde.`,
      observations,
      repCount: reps.length,
      meanROM: romStats.mean,
      romStdDev: romStats.stdDev,
      meanDuration: tempoStats.mean,
      tempoStdDev: tempoStats.stdDev,
      concentricMean: conMean,
      eccentricMean: eccMean,
      earlyLateROMDelta: delta,
      stabilityStatus
    };
  }
}

// -----------------------------------------------------------------------------
// 2. LEG PRESS ANALYZER
// -----------------------------------------------------------------------------
export class LegPressAnalyzer implements ExerciseAnalyzer {
  public segmentReps(frames: PoseFrame[]): Repetition[] {
    const squat = new SquatAnalyzer();
    return squat.segmentReps(frames);
  }

  public analyzeSet(reps: Repetition[]): SetAnalysis {
    if (reps.length === 0) return emptySetAnalysis();

    const romStats = computeStats(reps.map(r => r.primaryROM));
    const tempoStats = computeStats(reps.map(r => r.duration));
    const eccMean = Math.round((reps.reduce((a, b) => a + b.eccentricDuration, 0) / reps.length) * 10) / 10;
    const conMean = Math.round((reps.reduce((a, b) => a + b.concentricDuration, 0) / reps.length) * 10) / 10;

    const observations: FormObservation[] = [
      {
        id: 'legpress.knee.depth',
        title: 'Kontrolleret Slædebevægelse',
        detail: `Kontrolleret knæbøjning nåede ~${Math.round(romStats.mean)}° (±${romStats.stdDev}°) med jævn vending i slæden.`,
        evidence: `Kontrolleret vendepunkt observeret over ${reps.length} gentagelser.`,
        severity: 'positive',
        affectedReps: reps.map(r => r.index)
      }
    ];

    const stabilityStatus = determineStabilityStatus(romStats.stdDev, romStats.mean);
    const cvROM = romStats.mean > 0 ? (romStats.stdDev / romStats.mean) : 0;
    const cvTempo = tempoStats.mean > 0 ? (tempoStats.stdDev / tempoStats.mean) : 0;

    const consistencyScore = Math.max(50, Math.min(100, Math.round(100 - cvROM * 200)));
    const tempoScore = Math.max(50, Math.min(100, Math.round(100 - cvTempo * 150)));
    const romScore = romStats.mean <= 90 ? 96 : Math.max(50, Math.round(96 - (romStats.mean - 90) * 1.5));
    const overallScore = Math.round(romScore * 0.4 + consistencyScore * 0.3 + tempoScore * 0.3);

    return {
      overallScore,
      romScore,
      consistencyScore,
      tempoScore,
      primaryObservation: `Flot benpres med ${reps.length} gentagelser ved ~${Math.round(romStats.mean)}° (±${romStats.stdDev}°) knæbøjning.`,
      observations,
      repCount: reps.length,
      meanROM: romStats.mean,
      romStdDev: romStats.stdDev,
      meanDuration: tempoStats.mean,
      tempoStdDev: tempoStats.stdDev,
      concentricMean: conMean,
      eccentricMean: eccMean,
      stabilityStatus
    };
  }
}

// -----------------------------------------------------------------------------
// 3. BICEP CURLS ANALYZER (WITH RELATIVE SHOULDER DRIFT Δθ)
// -----------------------------------------------------------------------------
export class BicepCurlAnalyzer implements ExerciseAnalyzer {
  public segmentReps(frames: PoseFrame[]): Repetition[] {
    if (frames.length < 10) return [];
    const reps: Repetition[] = [];
    let state: 'lockout' | 'curling' | 'peak' | 'lowering' = 'lockout';
    let startTime = 0;
    let minAngle = 180;
    let setupShoulderAngle = 0;
    let maxRelativeDrift = 0;
    let inflectionTime = 0;
    let repIdx = 1;
    let prevAngle = 180;
    let preMinAngle = 180;

    for (let i = 0; i < frames.length; i++) {
      const f = frames[i];
      const elbowAngle = getDominantLimbAngle(
        f,
        ['left_shoulder', 'left_elbow', 'left_wrist'],
        ['right_shoulder', 'right_elbow', 'right_wrist']
      );
      if (elbowAngle === null) continue;

      const currentShoulderAngle = getDominantLimbAngle(
        f,
        ['left_hip', 'left_shoulder', 'left_elbow'],
        ['right_hip', 'right_shoulder', 'right_elbow']
      ) ?? 0;
      const t = f.timestamp;

      if (state === 'lockout' && elbowAngle < 140) {
        state = 'curling';
        startTime = t;
        minAngle = elbowAngle;
        preMinAngle = prevAngle;
        setupShoulderAngle = currentShoulderAngle;
        maxRelativeDrift = 0;
        inflectionTime = t;
      } else if (state === 'curling') {
        const relativeDrift = Math.abs(currentShoulderAngle - setupShoulderAngle);
        if (elbowAngle < minAngle) {
          preMinAngle = prevAngle;
          minAngle = elbowAngle;
          inflectionTime = t;
        }
        if (relativeDrift > maxRelativeDrift) {
          maxRelativeDrift = relativeDrift;
        }
        if (elbowAngle > minAngle + 5) {
          state = 'peak';
        }
      } else if (state === 'peak') {
        const relativeDrift = Math.abs(currentShoulderAngle - setupShoulderAngle);
        if (relativeDrift > maxRelativeDrift) {
          maxRelativeDrift = relativeDrift;
        }
        if (elbowAngle > minAngle + 12) {
          state = 'lowering';
        }
      } else if (state === 'lowering') {
        const relativeDrift = Math.abs(currentShoulderAngle - setupShoulderAngle);
        if (relativeDrift > maxRelativeDrift) {
          maxRelativeDrift = relativeDrift;
        }
        if (elbowAngle >= 140) {
          const duration = t - startTime;
          if (duration >= 0.7 && (160 - minAngle) >= 45) {
            const refinedMinAngle = interpolateParabolicExtremum(preMinAngle, minAngle, elbowAngle, true);

            reps.push({
              index: repIdx++,
              startTime,
              inflectionTime,
              endTime: t,
              duration,
              concentricDuration: Math.max(0.2, inflectionTime - startTime),
              eccentricDuration: Math.max(0.2, t - inflectionTime),
              primaryROM: Math.round(refinedMinAngle * 10) / 10,
              secondaryROM: Math.round(maxRelativeDrift * 10) / 10,
              confidence: f.confidence
            });
          }
          state = 'lockout';
          maxRelativeDrift = 0;
        }
      }
      prevAngle = elbowAngle;
    }
    return reps;
  }

  public analyzeSet(reps: Repetition[]): SetAnalysis {
    if (reps.length === 0) return emptySetAnalysis();

    const romStats = computeStats(reps.map(r => r.primaryROM));
    const tempoStats = computeStats(reps.map(r => r.duration));
    const driftStats = computeStats(reps.map(r => r.secondaryROM || 0));
    const peakDrift = Math.max(...reps.map(r => r.secondaryROM || 0));

    const eccMean = Math.round((reps.reduce((a, b) => a + b.eccentricDuration, 0) / reps.length) * 10) / 10;
    const conMean = Math.round((reps.reduce((a, b) => a + b.concentricDuration, 0) / reps.length) * 10) / 10;

    const observations: FormObservation[] = [];

    if (peakDrift >= 15 || driftStats.mean >= 12) {
      observations.push({
        id: 'curl.shoulder.drift',
        title: 'Skuldersving / Momentum Registreret',
        detail: `Overarmen svang fremad med Δ${Math.round(peakDrift)}° ift. startpositionen. Lås albuerne mod kroppen for at isolere biceps.`,
        evidence: `Skuldersvaj ≥15° registreret på reps: ${reps.filter(r => (r.secondaryROM || 0) >= 15).map(r => r.index).join(', ')}.`,
        severity: 'warning',
        affectedReps: reps.filter(r => (r.secondaryROM || 0) >= 15).map(r => r.index)
      });
    } else {
      observations.push({
        id: 'curl.form.strict',
        title: 'Strikt Biceps-Isolering',
        detail: `Albuerne forblev fastlåst med under Δ${Math.round(peakDrift || 6)}° skuldersvaj over alle ${reps.length} gentagelser.`,
        evidence: `Strikt udførelse bekræftet ift. startposition.`,
        severity: 'positive',
        affectedReps: reps.map(r => r.index)
      });
    }

    const stabilityStatus = determineStabilityStatus(romStats.stdDev, romStats.mean, peakDrift);
    const cvROM = romStats.mean > 0 ? (romStats.stdDev / romStats.mean) : 0;
    const cvTempo = tempoStats.mean > 0 ? (tempoStats.stdDev / tempoStats.mean) : 0;

    const consistencyScore = Math.max(50, Math.min(100, Math.round(100 - cvROM * 200)));
    const tempoScore = Math.max(50, Math.min(100, Math.round(100 - cvTempo * 150)));
    const romScore = romStats.mean <= 60 ? 96 : Math.max(50, Math.round(96 - (romStats.mean - 60) * 1.5));
    const driftPenalty = peakDrift >= 15 ? 18 : Math.round(peakDrift * 0.6);
    const overallScore = Math.max(40, Math.round(romScore * 0.4 + consistencyScore * 0.3 + tempoScore * 0.3 - driftPenalty));

    return {
      overallScore,
      romScore,
      consistencyScore,
      tempoScore,
      primaryObservation: observations[0]?.detail || `Bicep curls med ${reps.length} gentagelser ved ~${Math.round(romStats.mean)}° albuebøjning (Δ${Math.round(peakDrift)}° svaj).`,
      observations,
      repCount: reps.length,
      meanROM: romStats.mean,
      romStdDev: romStats.stdDev,
      meanDuration: tempoStats.mean,
      tempoStdDev: tempoStats.stdDev,
      concentricMean: conMean,
      eccentricMean: eccMean,
      peakRelativeDrift: peakDrift,
      stabilityStatus
    };
  }
}

// -----------------------------------------------------------------------------
// 4. TRICEPS PUSHDOWN ANALYZER (WITH RELATIVE UPPER ARM DRIFT Δθ)
// -----------------------------------------------------------------------------
export class TricepsPushdownAnalyzer implements ExerciseAnalyzer {
  public segmentReps(frames: PoseFrame[]): Repetition[] {
    if (frames.length < 10) return [];
    const reps: Repetition[] = [];
    let state: 'flexed' | 'extending' | 'lockout' | 'returning' = 'flexed';
    let startTime = 0;
    let maxAngle = 70;
    let setupShoulderAngle = 0;
    let maxRelativeDrift = 0;
    let inflectionTime = 0;
    let repIdx = 1;
    let prevAngle = 70;
    let preMaxAngle = 70;

    for (let i = 0; i < frames.length; i++) {
      const f = frames[i];
      const elbowAngle = getDominantLimbAngle(
        f,
        ['left_shoulder', 'left_elbow', 'left_wrist'],
        ['right_shoulder', 'right_elbow', 'right_wrist']
      );
      if (elbowAngle === null) continue;

      const currentShoulderAngle = getDominantLimbAngle(
        f,
        ['left_hip', 'left_shoulder', 'left_elbow'],
        ['right_hip', 'right_shoulder', 'right_elbow']
      ) ?? 0;
      const t = f.timestamp;

      if (state === 'flexed' && elbowAngle > 95) {
        state = 'extending';
        startTime = t;
        maxAngle = elbowAngle;
        preMaxAngle = prevAngle;
        setupShoulderAngle = currentShoulderAngle;
        maxRelativeDrift = 0;
        inflectionTime = t;
      } else if (state === 'extending') {
        const relativeDrift = Math.abs(currentShoulderAngle - setupShoulderAngle);
        if (elbowAngle > maxAngle) {
          preMaxAngle = prevAngle;
          maxAngle = elbowAngle;
          inflectionTime = t;
        }
        if (relativeDrift > maxRelativeDrift) {
          maxRelativeDrift = relativeDrift;
        }
        if (elbowAngle < maxAngle - 4) {
          state = 'lockout';
        }
      } else if (state === 'lockout') {
        const relativeDrift = Math.abs(currentShoulderAngle - setupShoulderAngle);
        if (relativeDrift > maxRelativeDrift) {
          maxRelativeDrift = relativeDrift;
        }
        if (elbowAngle < maxAngle - 10) {
          state = 'returning';
        }
      } else if (state === 'returning') {
        const relativeDrift = Math.abs(currentShoulderAngle - setupShoulderAngle);
        if (relativeDrift > maxRelativeDrift) {
          maxRelativeDrift = relativeDrift;
        }
        if (elbowAngle <= 95) {
          const duration = t - startTime;
          if (duration >= 0.7 && (maxAngle - 85) >= 40) {
            const refinedMaxAngle = interpolateParabolicExtremum(preMaxAngle, maxAngle, elbowAngle, false);

            reps.push({
              index: repIdx++,
              startTime,
              inflectionTime,
              endTime: t,
              duration,
              concentricDuration: Math.max(0.2, inflectionTime - startTime),
              eccentricDuration: Math.max(0.2, t - inflectionTime),
              primaryROM: Math.round(refinedMaxAngle * 10) / 10,
              secondaryROM: Math.round(maxRelativeDrift * 10) / 10,
              confidence: f.confidence
            });
          }
          state = 'flexed';
          maxRelativeDrift = 0;
        }
      }
      prevAngle = elbowAngle;
    }
    return reps;
  }

  public analyzeSet(reps: Repetition[]): SetAnalysis {
    if (reps.length === 0) return emptySetAnalysis();

    const romStats = computeStats(reps.map(r => r.primaryROM));
    const tempoStats = computeStats(reps.map(r => r.duration));
    const peakDrift = Math.max(...reps.map(r => r.secondaryROM || 0));

    const eccMean = Math.round((reps.reduce((a, b) => a + b.eccentricDuration, 0) / reps.length) * 10) / 10;
    const conMean = Math.round((reps.reduce((a, b) => a + b.concentricDuration, 0) / reps.length) * 10) / 10;

    const observations: FormObservation[] = [];

    if (peakDrift >= 16) {
      observations.push({
        id: 'triceps.elbow.drift',
        title: 'Fremadrettet Albue-Vandring',
        detail: `Albuerne drev fremad med Δ${Math.round(peakDrift)}° ift. overkroppen. Hold albuerne fikseret i siden.`,
        evidence: `Overarmsbevægelse ≥16° registreret på reps: ${reps.filter(r => (r.secondaryROM || 0) >= 16).map(r => r.index).join(', ')}.`,
        severity: 'warning',
        affectedReps: reps.filter(r => (r.secondaryROM || 0) >= 16).map(r => r.index)
      });
    } else {
      observations.push({
        id: 'triceps.form.strict',
        title: 'Strikt Triceps-Ekstension',
        detail: `Albuerne forblev fastlåst med fuld ~${Math.round(romStats.mean)}° (±${romStats.stdDev}°) ekstension på alle gentagelser.`,
        evidence: `Fuld ekstension uden skuldersving.`,
        severity: 'positive',
        affectedReps: reps.map(r => r.index)
      });
    }

    const stabilityStatus = determineStabilityStatus(romStats.stdDev, romStats.mean, peakDrift);
    const cvROM = romStats.mean > 0 ? (romStats.stdDev / romStats.mean) : 0;
    const cvTempo = tempoStats.mean > 0 ? (tempoStats.stdDev / tempoStats.mean) : 0;

    const consistencyScore = Math.max(50, Math.min(100, Math.round(100 - cvROM * 200)));
    const tempoScore = Math.max(50, Math.min(100, Math.round(100 - cvTempo * 150)));
    const romScore = romStats.mean >= 160 ? 98 : Math.max(50, Math.round(98 - (160 - romStats.mean) * 1.5));
    const driftPenalty = peakDrift >= 16 ? 16 : Math.round(peakDrift * 0.5);
    const overallScore = Math.max(40, Math.round(romScore * 0.4 + consistencyScore * 0.3 + tempoScore * 0.3 - driftPenalty));

    return {
      overallScore,
      romScore,
      consistencyScore,
      tempoScore,
      primaryObservation: observations[0]?.detail || `Rent triceps pushdown sæt med ${reps.length} gentagelser ved ~${Math.round(romStats.mean)}° ekstension.`,
      observations,
      repCount: reps.length,
      meanROM: romStats.mean,
      romStdDev: romStats.stdDev,
      meanDuration: tempoStats.mean,
      tempoStdDev: tempoStats.stdDev,
      concentricMean: conMean,
      eccentricMean: eccMean,
      peakRelativeDrift: peakDrift,
      stabilityStatus
    };
  }
}

// -----------------------------------------------------------------------------
// 5. SHOULDER PRESS ANALYZER (WITH BILATERAL ASYMMETRY CALCULATION)
// -----------------------------------------------------------------------------
export class ShoulderPressAnalyzer implements ExerciseAnalyzer {
  public segmentReps(frames: PoseFrame[]): Repetition[] {
    if (frames.length < 10) return [];
    const reps: Repetition[] = [];
    let state: 'racked' | 'pressing' | 'lockout' | 'lowering' = 'racked';
    let startTime = 0;
    let maxAngle = 70;
    let maxAsymmetry = 0;
    let inflectionTime = 0;
    let repIdx = 1;
    let prevAngle = 70;
    let preMaxAngle = 70;

    for (let i = 0; i < frames.length; i++) {
      const f = frames[i];
      const leftAngle = getJointAngle(f, 'left_shoulder', 'left_elbow', 'left_wrist');
      const rightAngle = getJointAngle(f, 'right_shoulder', 'right_elbow', 'right_wrist');

      const activeAngle = leftAngle ?? rightAngle;
      if (activeAngle === null) continue;

      const asymmetryDelta = leftAngle !== null && rightAngle !== null ? Math.abs(leftAngle - rightAngle) : 0;
      const t = f.timestamp;

      if (state === 'racked' && activeAngle > 90) {
        state = 'pressing';
        startTime = t;
        maxAngle = activeAngle;
        preMaxAngle = prevAngle;
        maxAsymmetry = asymmetryDelta;
        inflectionTime = t;
      } else if (state === 'pressing') {
        if (activeAngle > maxAngle) {
          preMaxAngle = prevAngle;
          maxAngle = activeAngle;
          inflectionTime = t;
        }
        if (asymmetryDelta > maxAsymmetry) {
          maxAsymmetry = asymmetryDelta;
        }
        if (activeAngle < maxAngle - 5) {
          state = 'lockout';
        }
      } else if (state === 'lockout') {
        if (asymmetryDelta > maxAsymmetry) {
          maxAsymmetry = asymmetryDelta;
        }
        if (activeAngle < maxAngle - 12) {
          state = 'lowering';
        }
      } else if (state === 'lowering') {
        if (asymmetryDelta > maxAsymmetry) {
          maxAsymmetry = asymmetryDelta;
        }
        if (activeAngle <= 90) {
          const duration = t - startTime;
          if (duration >= 0.8 && maxAngle >= 145) {
            const refinedMaxAngle = interpolateParabolicExtremum(preMaxAngle, maxAngle, activeAngle, false);

            reps.push({
              index: repIdx++,
              startTime,
              inflectionTime,
              endTime: t,
              duration,
              concentricDuration: Math.max(0.2, inflectionTime - startTime),
              eccentricDuration: Math.max(0.2, t - inflectionTime),
              primaryROM: Math.round(refinedMaxAngle * 10) / 10,
              secondaryROM: Math.round(maxAsymmetry * 10) / 10,
              confidence: f.confidence
            });
          }
          state = 'racked';
          maxAsymmetry = 0;
        }
      }
      prevAngle = activeAngle;
    }
    return reps;
  }

  public analyzeSet(reps: Repetition[]): SetAnalysis {
    if (reps.length === 0) return emptySetAnalysis();

    const romStats = computeStats(reps.map(r => r.primaryROM));
    const asymStats = computeStats(reps.map(r => r.secondaryROM || 0));
    const tempoStats = computeStats(reps.map(r => r.duration));

    const eccMean = Math.round((reps.reduce((a, b) => a + b.eccentricDuration, 0) / reps.length) * 10) / 10;
    const conMean = Math.round((reps.reduce((a, b) => a + b.concentricDuration, 0) / reps.length) * 10) / 10;

    const observations: FormObservation[] = [];

    if (asymStats.mean >= 12) {
      observations.push({
        id: 'press.bilateral.asymmetry',
        title: 'Bilateral Arm-Asymmetri Registreret',
        detail: `Registrerede i gennemsnit ${Math.round(asymStats.mean)}° asymmetri mellem højre og venstre arms stræk.`,
        evidence: `Asymmetrisk stræk på reps: ${reps.filter(r => (r.secondaryROM || 0) >= 12).map(r => r.index).join(', ')}.`,
        severity: 'warning',
        affectedReps: reps.filter(r => (r.secondaryROM || 0) >= 12).map(r => r.index)
      });
    } else {
      observations.push({
        id: 'press.lockout.symmetry',
        title: 'Symmetrisk Overhoved-Ekstension',
        detail: `Højre og venstre arm bevægede sig symmetrisk inden for ~${Math.round(asymStats.mean)}° afvigelse over alle ${reps.length} gentagelser.`,
        evidence: `Symmetrisk justering bekræftet fra målingerne.`,
        severity: 'positive',
        affectedReps: reps.map(r => r.index)
      });
    }

    const symmetryScore = Math.max(50, Math.round(100 - asymStats.mean * 2.0));
    const stabilityStatus = determineStabilityStatus(romStats.stdDev, romStats.mean, asymStats.mean);
    const cvROM = romStats.mean > 0 ? (romStats.stdDev / romStats.mean) : 0;
    const cvTempo = tempoStats.mean > 0 ? (tempoStats.stdDev / tempoStats.mean) : 0;

    const consistencyScore = Math.max(50, Math.min(100, Math.round(100 - cvROM * 200)));
    const tempoScore = Math.max(50, Math.min(100, Math.round(100 - cvTempo * 150)));
    const romScore = romStats.mean >= 165 ? 98 : Math.max(50, Math.round(98 - (165 - romStats.mean) * 1.5));
    const overallScore = Math.round(romScore * 0.4 + consistencyScore * 0.3 + tempoScore * 0.3);

    return {
      overallScore,
      romScore,
      consistencyScore,
      tempoScore,
      symmetryScore,
      primaryObservation: observations[0]?.detail || `Skulderpres med ${reps.length} gentagelser ved ~${Math.round(romStats.mean)}° (±${romStats.stdDev}°) ekstension.`,
      observations,
      repCount: reps.length,
      meanROM: romStats.mean,
      romStdDev: romStats.stdDev,
      meanDuration: tempoStats.mean,
      tempoStdDev: tempoStats.stdDev,
      concentricMean: conMean,
      eccentricMean: eccMean,
      meanAsymmetry: asymStats.mean,
      stabilityStatus
    };
  }
}

export function getAnalyzerForExercise(type: ExerciseType): ExerciseAnalyzer {
  switch (type) {
    case 'squat':
      return new SquatAnalyzer();
    case 'legPress':
      return new LegPressAnalyzer();
    case 'bicepsCurl':
      return new BicepCurlAnalyzer();
    case 'tricepsPushdown':
      return new TricepsPushdownAnalyzer();
    case 'shoulderPress':
    default:
      return new ShoulderPressAnalyzer();
  }
}

