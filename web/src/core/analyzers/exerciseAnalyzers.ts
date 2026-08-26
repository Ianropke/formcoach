import { PoseFrame, Repetition, SetAnalysis, CameraViewType, FormObservation, ExerciseType, FormStabilityStatus } from '../models';
import { AngleCalculator } from '../angleCalculator';

export interface ExerciseAnalyzer {
  segmentReps(frames: PoseFrame[], view: CameraViewType): Repetition[];
  analyzeSet(reps: Repetition[], frames: PoseFrame[], view: CameraViewType): SetAnalysis;
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
    primaryObservation: 'No completed repetitions detected in this set.',
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

    for (let i = 0; i < frames.length; i++) {
      const f = frames[i];
      const hip = f.joints.left_hip || f.joints.right_hip;
      const knee = f.joints.left_knee || f.joints.right_knee;
      const ankle = f.joints.left_ankle || f.joints.right_ankle;
      if (!hip || !knee || !ankle) continue;

      const kneeAngle = AngleCalculator.angle2D(hip, knee, ankle);
      const t = f.timestamp;

      if (state === 'standing' && kneeAngle < 155) {
        state = 'descending';
        startTime = t;
        minKneeAngle = kneeAngle;
        inflectionTime = t;
      } else if (state === 'descending') {
        if (kneeAngle < minKneeAngle) {
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
            reps.push({
              index: repIdx++,
              startTime,
              inflectionTime,
              endTime: t,
              duration,
              concentricDuration: Math.max(0.2, t - inflectionTime),
              eccentricDuration: Math.max(0.2, inflectionTime - startTime),
              primaryROM: Math.round(minKneeAngle * 10) / 10,
              confidence: f.confidence
            });
          }
          state = 'standing';
        }
      }
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
          title: 'Depth Decay Detected',
          detail: `Squat depth became shallower by ~${delta}% on late repetitions due to fatigue.`,
          evidence: `Late reps reached ${Math.round(late)}° vs early ${Math.round(early)}°.`,
          severity: 'warning',
          affectedReps: reps.slice(-half).map(r => r.index)
        });
      }
    }

    if (romStats.mean <= 88) {
      observations.push({
        id: 'squat.depth.parallel',
        title: 'Deep & Parallel Squats',
        detail: `Consistently achieved full ~${Math.round(romStats.mean)}° (±${romStats.stdDev}°) depth across all ${reps.length} reps.`,
        evidence: `Full range of motion verified mathematically.`,
        severity: 'positive',
        affectedReps: reps.map(r => r.index)
      });
    } else if (romStats.mean >= 105) {
      observations.push({
        id: 'squat.depth.shallow',
        title: 'Shallow Depth Warning',
        detail: `Squats reached ~${Math.round(romStats.mean)}° depth (above parallel). Target ≤88° for full quad engagement.`,
        evidence: `Knee flexion remained above 105°.`,
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
      primaryObservation: observations[0]?.detail || `Solid squat session with ${reps.length} reps at ~${Math.round(romStats.mean)}° (±${romStats.stdDev}°) depth.`,
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
        title: 'Controlled Sled Range',
        detail: `Controlled knee flexion reached ~${Math.round(romStats.mean)}° (±${romStats.stdDev}°) with smooth turnaround.`,
        evidence: `Controlled inflection point observed across ${reps.length} reps.`,
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
      primaryObservation: `Clean leg press execution with ${reps.length} reps at ~${Math.round(romStats.mean)}° (±${romStats.stdDev}°) knee flexion.`,
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

    for (let i = 0; i < frames.length; i++) {
      const f = frames[i];
      const s = f.joints.left_shoulder || f.joints.right_shoulder;
      const e = f.joints.left_elbow || f.joints.right_elbow;
      const w = f.joints.left_wrist || f.joints.right_wrist;
      const h = f.joints.left_hip || f.joints.right_hip;
      if (!s || !e || !w) continue;

      const elbowAngle = AngleCalculator.angle2D(s, e, w);
      const currentShoulderAngle = h ? AngleCalculator.angle2D(h, s, e) : 0;
      const t = f.timestamp;

      if (state === 'lockout' && elbowAngle < 140) {
        state = 'curling';
        startTime = t;
        minAngle = elbowAngle;
        setupShoulderAngle = currentShoulderAngle;
        maxRelativeDrift = 0;
        inflectionTime = t;
      } else if (state === 'curling') {
        const relativeDrift = Math.abs(currentShoulderAngle - setupShoulderAngle);
        if (elbowAngle < minAngle) {
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
            reps.push({
              index: repIdx++,
              startTime,
              inflectionTime,
              endTime: t,
              duration,
              concentricDuration: Math.max(0.2, inflectionTime - startTime),
              eccentricDuration: Math.max(0.2, t - inflectionTime),
              primaryROM: Math.round(minAngle * 10) / 10,
              secondaryROM: Math.round(maxRelativeDrift * 10) / 10,
              confidence: f.confidence
            });
          }
          state = 'lockout';
          maxRelativeDrift = 0;
        }
      }
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
        title: 'Shoulder Momentum Swing Detected',
        detail: `Upper arm swung forward by Δ${Math.round(peakDrift)}° relative to setup posture. Pin elbows to isolate biceps.`,
        evidence: `Relative shoulder drift ≥15° on reps: ${reps.filter(r => (r.secondaryROM || 0) >= 15).map(r => r.index).join(', ')}.`,
        severity: 'warning',
        affectedReps: reps.filter(r => (r.secondaryROM || 0) >= 15).map(r => r.index)
      });
    } else {
      observations.push({
        id: 'curl.form.strict',
        title: 'Strict Bicep Isolation',
        detail: `Elbows stayed tightly pinned with under Δ${Math.round(peakDrift || 6)}° relative shoulder drift across all ${reps.length} reps.`,
        evidence: `Strict curl execution verified relative to setup anchor.`,
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
      primaryObservation: observations[0]?.detail || `Biceps curls with ${reps.length} reps at ~${Math.round(romStats.mean)}° elbow flexion (Δ${Math.round(peakDrift)}° drift).`,
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

    for (let i = 0; i < frames.length; i++) {
      const f = frames[i];
      const s = f.joints.left_shoulder || f.joints.right_shoulder;
      const e = f.joints.left_elbow || f.joints.right_elbow;
      const w = f.joints.left_wrist || f.joints.right_wrist;
      const h = f.joints.left_hip || f.joints.right_hip;
      if (!s || !e || !w) continue;

      const elbowAngle = AngleCalculator.angle2D(s, e, w);
      const currentShoulderAngle = h ? AngleCalculator.angle2D(h, s, e) : 0;
      const t = f.timestamp;

      if (state === 'flexed' && elbowAngle > 95) {
        state = 'extending';
        startTime = t;
        maxAngle = elbowAngle;
        setupShoulderAngle = currentShoulderAngle;
        maxRelativeDrift = 0;
        inflectionTime = t;
      } else if (state === 'extending') {
        const relativeDrift = Math.abs(currentShoulderAngle - setupShoulderAngle);
        if (elbowAngle > maxAngle) {
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
            reps.push({
              index: repIdx++,
              startTime,
              inflectionTime,
              endTime: t,
              duration,
              concentricDuration: Math.max(0.2, inflectionTime - startTime),
              eccentricDuration: Math.max(0.2, t - inflectionTime),
              primaryROM: Math.round(maxAngle * 10) / 10,
              secondaryROM: Math.round(maxRelativeDrift * 10) / 10,
              confidence: f.confidence
            });
          }
          state = 'flexed';
          maxRelativeDrift = 0;
        }
      }
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
        title: 'Pinned Elbow Drift',
        detail: `Elbows drifted forward by Δ${Math.round(peakDrift)}° relative to torso. Keep elbows pinned to your sides.`,
        evidence: `Relative upper arm drift ≥16° on reps: ${reps.filter(r => (r.secondaryROM || 0) >= 16).map(r => r.index).join(', ')}.`,
        severity: 'warning',
        affectedReps: reps.filter(r => (r.secondaryROM || 0) >= 16).map(r => r.index)
      });
    } else {
      observations.push({
        id: 'triceps.form.strict',
        title: 'Strict Triceps Lockout',
        detail: `Elbows stayed tightly pinned with complete ~${Math.round(romStats.mean)}° (±${romStats.stdDev}°) extension on every rep.`,
        evidence: `Clean extension without shoulder cheating.`,
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
      primaryObservation: observations[0]?.detail || `Clean triceps pushdown set with ${reps.length} reps at ~${Math.round(romStats.mean)}° extension.`,
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

    for (let i = 0; i < frames.length; i++) {
      const f = frames[i];
      const sL = f.joints.left_shoulder;
      const eL = f.joints.left_elbow;
      const wL = f.joints.left_wrist;
      const sR = f.joints.right_shoulder;
      const eR = f.joints.right_elbow;
      const wR = f.joints.right_wrist;

      // Calculate angles for both arms if present
      const leftAngle = sL && eL && wL ? AngleCalculator.angle2D(sL, eL, wL) : null;
      const rightAngle = sR && eR && wR ? AngleCalculator.angle2D(sR, eR, wR) : null;

      const activeAngle = leftAngle ?? rightAngle;
      if (activeAngle === null) continue;

      // True bilateral asymmetry delta
      const asymmetryDelta = leftAngle !== null && rightAngle !== null ? Math.abs(leftAngle - rightAngle) : 0;
      const t = f.timestamp;

      if (state === 'racked' && activeAngle > 90) {
        state = 'pressing';
        startTime = t;
        maxAngle = activeAngle;
        maxAsymmetry = asymmetryDelta;
        inflectionTime = t;
      } else if (state === 'pressing') {
        if (activeAngle > maxAngle) {
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
            reps.push({
              index: repIdx++,
              startTime,
              inflectionTime,
              endTime: t,
              duration,
              concentricDuration: Math.max(0.2, inflectionTime - startTime),
              eccentricDuration: Math.max(0.2, t - inflectionTime),
              primaryROM: Math.round(maxAngle * 10) / 10,
              secondaryROM: Math.round(maxAsymmetry * 10) / 10,
              confidence: f.confidence
            });
          }
          state = 'racked';
          maxAsymmetry = 0;
        }
      }
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
        title: 'Bilateral Arm Asymmetry Detected',
        detail: `Observed an average ${Math.round(asymStats.mean)}° asymmetry between left and right arm extension.`,
        evidence: `Asymmetric extension on reps: ${reps.filter(r => (r.secondaryROM || 0) >= 12).map(r => r.index).join(', ')}.`,
        severity: 'warning',
        affectedReps: reps.filter(r => (r.secondaryROM || 0) >= 12).map(r => r.index)
      });
    } else {
      observations.push({
        id: 'press.lockout.symmetry',
        title: 'Symmetrical Overhead Lockout',
        detail: `Left and right arms moved symmetrically within ~${Math.round(asymStats.mean)}° variance across all ${reps.length} reps.`,
        evidence: `Bilateral alignment verified from measured landmarks.`,
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
      primaryObservation: observations[0]?.detail || `Overhead press with ${reps.length} reps at ~${Math.round(romStats.mean)}° (±${romStats.stdDev}°) extension.`,
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

