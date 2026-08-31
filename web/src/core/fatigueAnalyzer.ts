import { PersonalBaselineEngine } from './baselineEngine';
import { RecordedSet, WorkoutSessionAnalysis, FormObservation } from './models';

export class CrossSetFatigueAnalyzer {
  public static analyzeSession(sets: RecordedSet[]): WorkoutSessionAnalysis {
    if (sets.length === 0) {
      return {
        totalSets: 0,
        totalReps: 0,
        fatigueIndex: null,
        romTrend: 'stable',
        tempoTrend: 'stable',
        sessionObservations: [],
        setBreakdowns: []
      };
    }

    const totalReps = sets.reduce((acc, s) => acc + s.reps.length, 0);
    const breakdowns = sets.map((s, idx) => ({
      setNumber: idx + 1,
      repCount: s.reps.length,
      meanROM: s.analysis.meanROM,
      meanDuration: s.analysis.meanDuration,
      qualityScore: s.analysis.secondaryMetricsAvailable === false ? null : s.analysis.overallScore
    }));

    if (sets.length === 1 || sets.some(s => s.exercise !== sets[0].exercise)) {
      return {
        totalSets: sets.length,
        totalReps,
        fatigueIndex: null,
        romTrend: 'stable',
        tempoTrend: 'stable',
        sessionObservations: [],
        setBreakdowns: breakdowns
      };
    }

    const firstROM = sets[0].analysis.meanROM;
    const lastROM = sets[sets.length - 1].analysis.meanROM;
    const romChangePct = firstROM > 0 ? ((lastROM - firstROM) / firstROM) * 100 * (PersonalBaselineEngine.isExtensionExercise(sets[0].exercise) ? -1 : 1) : 0;

    const firstTempo = sets[0].analysis.meanDuration;
    const lastTempo = sets[sets.length - 1].analysis.meanDuration;
    const tempoChangePct = firstTempo > 0 ? ((lastTempo - firstTempo) / firstTempo) * 100 : 0;

    let fatigueIndex = 0;
    let romTrend: 'stable' | 'degrading' | 'improving' = 'stable';
    let tempoTrend: 'stable' | 'slowing' | 'accelerating' = 'stable';
    const observations: FormObservation[] = [];

    // Evaluate ROM deterioration across sets
    if (romChangePct >= 10) {
      romTrend = 'degrading';
      fatigueIndex += Math.min(45, romChangePct * 2.2);
      observations.push({
        id: 'session.cross_set.rom_decay',
        title: 'Bevægelsesbanen aftog',
        detail: `Slutvinklen ændrede sig ~${Math.round(romChangePct)}% i retning af mindre bevægelsesbane fra sæt 1 til sæt ${sets.length}.`,
        evidence: `Set 1 achieved ${Math.round(firstROM)}° vs Set ${sets.length} reaching ${Math.round(lastROM)}°.`,
        severity: 'warning',
        affectedReps: []
      });
    }

    if (romChangePct <= -10) romTrend = 'improving';

    // Evaluate tempo slowdown
    if (tempoChangePct >= 18) {
      tempoTrend = 'slowing';
      fatigueIndex += 20;
      observations.push({
        id: 'session.cross_set.tempo_slowdown',
        title: 'Langsommere gentagelser',
        detail: `Gentagelsernes varighed steg ~${Math.round(tempoChangePct)}%. Årsagen kan ikke bestemmes ud fra vinkler og tid alene.`,
        evidence: `Average duration grew from ${firstTempo.toFixed(1)}s to ${lastTempo.toFixed(1)}s.`,
        severity: 'info',
        affectedReps: []
      });
    }

    if (romTrend === 'stable' && tempoTrend === 'stable' && sets.length >= 3 && sets.every(s => Math.abs(s.analysis.meanROM - firstROM) <= firstROM * 0.05 && Math.abs(s.analysis.meanDuration - firstTempo) <= firstTempo * 0.05)) {
      observations.push({
        id: 'session.cross_set.high_endurance',
        title: 'Ensartede sæt',
        detail: `Bevægelsesbane og tempo var ensartede på tværs af ${sets.length} sæt.`,
        evidence: `Alle sæt lå inden for 5% af første sæts vinkel og varighed.`,
        severity: 'positive',
        affectedReps: []
      });
    }

    return {
      totalSets: sets.length,
      totalReps,
      fatigueIndex: Math.min(100, Math.round(fatigueIndex)),
      romTrend,
      tempoTrend,
      sessionObservations: observations,
      setBreakdowns: breakdowns
    };
  }
}
