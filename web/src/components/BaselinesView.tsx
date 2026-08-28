import React from 'react';
import { EXERCISES, RecordedSet } from '../core/models';
import { PersonalBaselineEngine } from '../core/baselineEngine';
import { Trophy, Activity, ArrowLeft } from 'lucide-react';

interface Props {
  history: RecordedSet[];
  onBack: () => void;
}

export const BaselinesView: React.FC<Props> = ({ history, onBack }) => {
  const exercises = Object.values(EXERCISES);

  return (
    <div className="flex flex-col h-full bg-black px-4 pt-3 pb-6 max-w-md mx-auto overflow-y-auto">
      {/* Top Header */}
      <div className="flex items-center justify-between mb-3">
        <button
          onClick={onBack}
          className="p-2 rounded-full bg-neutral-900 text-neutral-300 border border-white/10"
        >
          <ArrowLeft className="w-4 h-4" />
        </button>
        <div className="text-xs font-black uppercase text-[#00E676] tracking-widest">
          PERSONLIGE BASELINES
        </div>
        <div className="w-8" />
      </div>

      <h1 className="text-2xl font-black text-white tracking-tight mb-3">
        Formkurve & Baselines
      </h1>

      {/* Cards List */}
      <div className="space-y-3 flex-1 overflow-y-auto">
        {exercises.map(ex => {
          const baseline = PersonalBaselineEngine.computeBaseline(history, ex.id);
          const setsCount = history.filter(s => s.exercise === ex.id).length;

          return (
            <div
              key={ex.id}
              className="p-4 bg-neutral-950 rounded-2xl border border-white/5 space-y-2.5"
            >
              <div className="flex items-center justify-between">
                <div>
                  <div className="text-sm font-extrabold text-white">{ex.name}</div>
                  <div className="text-[11px] text-neutral-400">{ex.subtitle}</div>
                </div>
                <div className="flex items-center gap-1 text-xs font-black text-[#FFEB3B] bg-[#FFEB3B]/10 px-2.5 py-1 rounded-lg border border-[#FFEB3B]/20">
                  <Trophy className="w-3.5 h-3.5" />
                  <span>PR {baseline.personalBestROM}°</span>
                </div>
              </div>

              {/* Stats Grid */}
              <div className="grid grid-cols-3 gap-2 pt-1 border-t border-white/5 text-center">
                <div className="p-2 bg-neutral-900/50 rounded-xl">
                  <div className="text-[10px] uppercase font-bold text-neutral-400">Total Sæt</div>
                  <div className="text-sm font-black text-white">{setsCount}</div>
                </div>
                <div className="p-2 bg-neutral-900/50 rounded-xl">
                  <div className="text-[10px] uppercase font-bold text-neutral-400">Gns. ROM</div>
                  <div className="text-sm font-black text-white">~{baseline.baselineROMMean}°</div>
                </div>
                <div className="p-2 bg-neutral-900/50 rounded-xl">
                  <div className="text-[10px] uppercase font-bold text-neutral-400">Spredning (σ)</div>
                  <div className="text-sm font-black text-[#00E676]">±{baseline.baselineROMStdDev}°</div>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};
