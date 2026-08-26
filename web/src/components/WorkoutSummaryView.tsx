import React from 'react';
import { RecordedSet, EXERCISES } from '../core/models';
import { CrossSetFatigueAnalyzer } from '../core/fatigueAnalyzer';
import { PersonalBaselineEngine } from '../core/baselineEngine';
import { Trophy, ArrowLeft, CheckCircle2, Flame } from 'lucide-react';

interface Props {
  sets: RecordedSet[];
  allHistory: RecordedSet[];
  onDone: () => void;
}

export const WorkoutSummaryView: React.FC<Props> = ({
  sets,
  allHistory,
  onDone
}) => {
  const primaryExercise = sets[0]?.exercise || 'bicepsCurl';
  const exerciseDef = EXERCISES[primaryExercise] || Object.values(EXERCISES)[0];
  const sessionAnalysis = CrossSetFatigueAnalyzer.analyzeSession(sets);
  const baseline = PersonalBaselineEngine.computeBaseline(allHistory, primaryExercise);

  return (
    <div className="flex flex-col h-full bg-black px-4 pt-3 pb-6 max-w-md mx-auto overflow-y-auto">
      {/* Top Header */}
      <div className="flex items-center justify-between mb-3">
        <button
          onClick={onDone}
          className="p-2 rounded-full bg-neutral-900 text-neutral-300 border border-white/10"
        >
          <ArrowLeft className="w-4 h-4" />
        </button>
        <div className="text-xs font-black uppercase text-[#00E676] tracking-widest">
          WORKOUT COMPLETED
        </div>
        <div className="w-8" />
      </div>

      <h1 className="text-2xl font-black text-white tracking-tight mb-3">
        {exerciseDef.name} Summary
      </h1>

      {/* Session Fatigue Gauge Card */}
      <div className="p-4 bg-neutral-950 rounded-2xl border border-white/10 mb-3">
        <div className="flex items-center justify-between mb-2">
          <div className="flex items-center gap-1.5 text-xs font-bold uppercase text-neutral-400">
            <Flame className="w-4 h-4 text-orange-400" />
            <span>SESSION FATIGUE INDEX</span>
          </div>
          <div className="text-xs font-black text-[#00E676]">LOW FATIGUE</div>
        </div>

        <div className="flex items-baseline gap-2 mb-2">
          <div className="text-4xl font-black text-white">{sessionAnalysis.fatigueIndex}</div>
          <div className="text-xs text-neutral-400 font-semibold">/ 100 Fatigue Load</div>
        </div>

        {/* Progress Bar */}
        <div className="w-full h-2.5 bg-neutral-900 rounded-full overflow-hidden">
          <div
            className="h-full bg-gradient-to-r from-[#00E676] via-yellow-400 to-red-500 rounded-full transition-all duration-1000"
            style={{ width: `${Math.min(100, Math.max(10, sessionAnalysis.fatigueIndex))}%` }}
          />
        </div>
      </div>

      {/* Personal Baseline / PB Insight */}
      <div className="p-4 bg-neutral-950 rounded-2xl border border-[#00E676]/30 mb-3">
        <div className="flex items-center gap-2 mb-1.5">
          <Trophy className="w-4 h-4 text-[#FFEB3B]" />
          <span className="text-xs font-black text-[#FFEB3B] uppercase tracking-wider">
            PERSONAL BASELINE STATUS
          </span>
        </div>
        <div className="text-xs font-semibold text-neutral-200">
          Your personal baseline standard for {exerciseDef.name} is ~{baseline.baselineROMMean}° (±{baseline.baselineROMStdDev}°).
        </div>
      </div>

      {/* Set-by-Set Breakdown Table */}
      <div className="bg-neutral-950 rounded-2xl border border-white/10 p-3.5 mb-4">
        <div className="text-xs font-bold uppercase text-neutral-400 tracking-wider mb-2.5">
          Set-By-Set Trajectory
        </div>

        <div className="space-y-2">
          {sessionAnalysis.setBreakdowns.map(s => (
            <div
              key={s.setNumber}
              className="flex items-center justify-between p-2.5 bg-neutral-900/60 rounded-xl border border-white/5"
            >
              <div className="flex items-center gap-2">
                <span className="w-6 h-6 rounded-full bg-neutral-800 flex items-center justify-center text-[10px] font-black text-white">
                  {s.setNumber}
                </span>
                <span className="text-xs font-bold text-white">{s.repCount} Reps</span>
              </div>

              <div className="text-xs font-mono text-neutral-300">
                ~{Math.round(s.meanROM)}° ROM
              </div>

              <div className="text-xs font-extrabold text-[#00E676]">
                {s.qualityScore}% Score
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Done Button */}
      <button
        onClick={onDone}
        className="mt-auto w-full bg-[#00E676] hover:bg-[#00E676]/90 text-black font-extrabold text-base py-4 rounded-2xl shadow-lg shadow-[#00E676]/20 active:scale-[0.98] transition-transform"
      >
        Done & Save Workout
      </button>
    </div>
  );
};
