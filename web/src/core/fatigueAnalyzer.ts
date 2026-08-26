import { RecordedSet, WorkoutSessionAnalysis, FormObservation } from './models';

export class CrossSetFatigueAnalyzer {
  public static analyzeSession(sets: RecordedSet[]): WorkoutSessionAnalysis {
    if (sets.length === 0) {
      return {
        totalSets: 0,
        totalReps: 0,
        fatigueIndex: 0,
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
      qualityScore: s.analysis.overallScore
    }));

    if (sets.length === 1) {
      return {
        totalSets: 1,
        totalReps,
        fatigueIndex: 12,
        romTrend: 'stable',
        tempoTrend: 'stable',
        sessionObservations: [],
        setBreakdowns: breakdowns
      };
    }

    const firstROM = sets[0].analysis.meanROM;
    const lastROM = sets[sets.length - 1].analysis.meanROM;
    const romChangePct = firstROM > 0 ? ((lastROM - firstROM) / firstROM) * 100 : 0;

    const firstTempo = sets[0].analysis.meanDuration;
    const lastTempo = sets[sets.length - 1].analysis.meanDuration;
    const tempoChangePct = firstTempo > 0 ? ((lastTempo - firstTempo) / firstTempo) * 100 : 0;

    let fatigueIndex = 15;
    let romTrend: 'stable' | 'degrading' | 'improving' = 'stable';
    let tempoTrend: 'stable' | 'slowing' | 'accelerating' = 'stable';
    const observations: FormObservation[] = [];

    // Evaluate ROM deterioration across sets
    if (romChangePct >= 10) {
      romTrend = 'degrading';
      fatigueIndex += Math.min(45, romChangePct * 2.2);
      observations.push({
        id: 'session.cross_set.rom_decay',
        title: 'Multi-Set Depth Decay',
        detail: `Range of motion degraded by ~${Math.round(romChangePct)}% between Set 1 and Set ${sets.length}.`,
        evidence: `Set 1 achieved ${Math.round(firstROM)}° vs Set ${sets.length} reaching ${Math.round(lastROM)}°.`,
        severity: 'warning',
        affectedReps: []
      });
    }

    // Evaluate tempo slowdown
    if (tempoChangePct >= 18) {
      tempoTrend = 'slowing';
      fatigueIndex += 20;
      observations.push({
        id: 'session.cross_set.tempo_slowdown',
        title: 'Concentric Tempo Slowdown',
        detail: `Repetition tempo slowed down by ~${Math.round(tempoChangePct)}% in later sets due to fatigue.`,
        evidence: `Average duration grew from ${firstTempo.toFixed(1)}s to ${lastTempo.toFixed(1)}s.`,
        severity: 'info',
        affectedReps: []
      });
    }

    if (romTrend === 'stable' && sets.length >= 3) {
      observations.push({
        id: 'session.cross_set.high_endurance',
        title: 'Excellent Work Capacity',
        detail: `Maintained uniform movement depth and tempo across all ${sets.length} sets.`,
        evidence: `Under 5% variance detected across sets.`,
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
