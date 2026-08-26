import { RecordedSet, PersonalBaseline, ExerciseType } from './models';

export class PersonalBaselineEngine {
  public static computeBaseline(sets: RecordedSet[], exercise: ExerciseType): PersonalBaseline {
    const exerciseSets = sets.filter(s => s.exercise === exercise && s.reps.length > 0);
    const totalReps = exerciseSets.reduce((a, b) => a + b.reps.length, 0);

    // Statistical Cold-Start Guard: >= 3 recorded sessions and >= 25 reps
    if (exerciseSets.length < 3 || totalReps < 25) {
      const mean = exerciseSets.length > 0 
        ? exerciseSets.reduce((a, b) => a + b.analysis.meanROM, 0) / exerciseSets.length 
        : 85;
      const pb = exerciseSets.length > 0
        ? Math.min(...exerciseSets.map(s => Math.min(...s.reps.map(r => r.primaryROM))))
        : 80;

      return {
        exercise,
        totalSessions: exerciseSets.length,
        totalReps,
        baselineROMMean: Math.round(mean),
        baselineROMStdDev: 4.0,
        personalBestROM: Math.round(pb),
        hasSufficientData: false
      };
    }

    const allRepROMs = exerciseSets.flatMap(s => s.reps.map(r => r.primaryROM));
    const mean = allRepROMs.reduce((a, b) => a + b, 0) / allRepROMs.length;
    const variance = allRepROMs.reduce((a, b) => a + Math.pow(b - mean, 2), 0) / allRepROMs.length;
    const stdDev = Math.sqrt(variance);
    const pb = Math.min(...allRepROMs);

    return {
      exercise,
      totalSessions: exerciseSets.length,
      totalReps,
      baselineROMMean: Math.round(mean),
      baselineROMStdDev: Math.max(1.5, Math.round(stdDev * 10) / 10),
      personalBestROM: Math.round(pb),
      hasSufficientData: true
    };
  }

  public static compareSet(set: RecordedSet, baseline: PersonalBaseline): {
    isPersonalBest: boolean;
    isConsistent: boolean;
    insight: string;
  } {
    const setBestROM = Math.min(...set.reps.map(r => r.primaryROM));
    const isPB = setBestROM < baseline.personalBestROM;

    if (isPB) {
      return {
        isPersonalBest: true,
        isConsistent: true,
        insight: `🏆 New Personal Best! Achieved ${Math.round(setBestROM)}° depth (surpassed previous ${baseline.personalBestROM}° standard).`
      };
    }

    const diff = Math.abs(set.analysis.meanROM - baseline.baselineROMMean);
    const isConsistent = diff <= (baseline.baselineROMStdDev * 1.5);

    if (isConsistent) {
      return {
        isPersonalBest: false,
        isConsistent: true,
        insight: `✓ Consistent with your personal baseline (~${baseline.baselineROMMean}° ±${baseline.baselineROMStdDev}°).`
      };
    } else {
      return {
        isPersonalBest: false,
        isConsistent: false,
        insight: `Movement depth varied from your typical ~${baseline.baselineROMMean}° personal standard.`
      };
    }
  }
}
