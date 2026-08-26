import React, { useState, useEffect } from 'react';
import { RecordedSet, EXERCISES } from '../core/models';
import { Check, Plus, BarChart3, RotateCcw, AlertTriangle } from 'lucide-react';
import confetti from 'canvas-confetti';

interface Props {
  set: RecordedSet;
  activeSetsCount: number;
  onLogNextSet: () => void;
  onFinishWorkout: () => void;
  onDiscard: () => void;
}

export const ResultsView: React.FC<Props> = ({
  set,
  activeSetsCount,
  onLogNextSet,
  onFinishWorkout,
  onDiscard
}) => {
  const [selectedRepIndex, setSelectedRepIndex] = useState(1);
  const exerciseDef = EXERCISES[set.exercise];

  useEffect(() => {
    // Trigger confetti celebration on high quality set
    if (set.analysis.overallScore >= 90) {
      confetti({
        particleCount: 60,
        spread: 70,
        origin: { y: 0.6 }
      });
    }
  }, [set]);

  const selectedRep = set.reps.find(r => r.index === selectedRepIndex) || set.reps[0];

  return (
    <div className="flex flex-col h-full bg-black px-4 pt-3 pb-6 max-w-md mx-auto overflow-y-auto">
      {/* Top Bar */}
      <div className="flex items-center justify-between mb-3">
        <div>
          <div className="text-xl font-black uppercase text-white tracking-tight">
            {exerciseDef.name}
          </div>
          <div className="text-xs font-semibold text-neutral-400">
            {set.reps.length} reps detected • Set {activeSetsCount + 1}
          </div>
        </div>
        <div className="bg-[#00E676]/15 border border-[#00E676]/30 text-[#00E676] text-xs font-extrabold px-3 py-1 rounded-xl">
          98% TRACKING
        </div>
      </div>

      {/* Skeleton Visualizer Box */}
      <div className="relative w-full h-52 bg-neutral-950 rounded-2xl border border-white/10 overflow-hidden flex items-center justify-center mb-3">
        <svg viewBox="0 0 360 210" className="w-full h-full">
          {/* Floor / Bench */}
          <line x1="60" y1="160" x2="300" y2="160" stroke="#222" strokeWidth="4" />

          {/* Athlete Skeleton */}
          <circle cx="180" cy="65" r="14" fill="none" stroke="#00E676" strokeWidth="2.5" />
          <line x1="180" y1="79" x2="180" y2="140" stroke="#fff" strokeWidth="3.5" />

          {/* Limbs based on selected rep */}
          {set.exercise === 'squat' || set.exercise === 'legPress' ? (
            <>
              <line x1="180" y1="140" x2="155" y2="145" stroke="#00E676" strokeWidth="4" />
              <line x1="155" y1="145" x2="160" y2="185" stroke="#00E676" strokeWidth="4" />
              <circle cx="180" cy="140" r="5" fill="#00E676" />
              <circle cx="155" cy="145" r="6" fill="#FFEB3B" stroke="#000" strokeWidth="2" />
              <circle cx="160" cy="185" r="5" fill="#00E676" />
            </>
          ) : (
            <>
              <line x1="180" y1="90" x2="150" y2="95" stroke="#00E676" strokeWidth="4" />
              <line x1="150" y1="95" x2="175" y2="120" stroke="#00E676" strokeWidth="4" />
              <circle cx="180" cy="90" r="5" fill="#00E676" />
              <circle cx="150" cy="95" r="6" fill="#FFEB3B" stroke="#000" strokeWidth="2" />
              <circle cx="175" cy="120" r="5" fill="#00E676" />
            </>
          )}
        </svg>

        {/* Angle Badge */}
        <div className="absolute top-3 left-3 bg-[#00E676] text-black font-black text-xs px-2.5 py-1 rounded-lg">
          Angle: {Math.round(selectedRep.primaryROM)}°
        </div>
        <div className="absolute bottom-3 right-3 bg-black/70 font-mono text-[11px] text-neutral-300 px-2.5 py-1 rounded-lg border border-white/10">
          Rep {selectedRep.index} • {selectedRep.duration.toFixed(1)}s
        </div>
      </div>

      {/* Rep Timeline Scrubber */}
      <div className="flex gap-2 overflow-x-auto pb-2 scrollbar-none mb-3">
        {set.reps.map(rep => {
          const isSelected = rep.index === selectedRepIndex;
          return (
            <button
              key={rep.index}
              onClick={() => setSelectedRepIndex(rep.index)}
              className={`flex-shrink-0 px-3 py-2 rounded-xl text-left border transition-all ${
                isSelected
                  ? 'bg-neutral-900 border-[#00E676] shadow-md shadow-[#00E676]/10'
                  : 'bg-neutral-950/80 border-white/5'
              }`}
            >
              <div className="flex items-center justify-between gap-2 text-[10px] font-black">
                <span className="text-neutral-400">REP {rep.index}</span>
                <span className="text-[#00E676]">STRICT</span>
              </div>
              <div className="text-sm font-black text-white mt-0.5">
                {Math.round(rep.primaryROM)}° <span className="text-[10px] text-neutral-500 font-normal">{rep.duration.toFixed(1)}s</span>
              </div>
            </button>
          );
        })}
      </div>

      {/* Key Finding Card */}
      <div className="p-3.5 bg-neutral-950 rounded-2xl border border-[#00E676]/30 mb-3">
        <div className="flex items-center gap-1.5 text-[11px] font-black text-[#00E676] tracking-wider uppercase mb-1">
          <Check className="w-3.5 h-3.5" />
          <span>KEY FINDING</span>
        </div>
        <p className="text-xs font-semibold leading-relaxed text-neutral-200">
          {set.analysis.primaryObservation}
        </p>
      </div>

      {/* Metric Cards Grid */}
      <div className="grid grid-cols-2 gap-2.5 mb-4">
        <div className="p-3 bg-neutral-950 rounded-2xl border border-white/5">
          <div className="text-[10px] font-bold text-neutral-400 uppercase tracking-wider">Range of Motion</div>
          <div className="text-2xl font-black text-white mt-1">
            {set.analysis.romScore}<span className="text-xs text-neutral-500">/100</span>
          </div>
          <div className="text-[11px] text-neutral-400 mt-0.5">~{Math.round(set.analysis.meanROM)}° average</div>
        </div>

        <div className="p-3 bg-neutral-950 rounded-2xl border border-white/5">
          <div className="text-[10px] font-bold text-neutral-400 uppercase tracking-wider">Consistency</div>
          <div className="text-2xl font-black text-white mt-1">
            {set.analysis.consistencyScore}<span className="text-xs text-neutral-500">/100</span>
          </div>
          <div className="text-[11px] text-neutral-400 mt-0.5">Stable repetition path</div>
        </div>

        <div className="p-3 bg-neutral-950 rounded-2xl border border-white/5">
          <div className="text-[10px] font-bold text-neutral-400 uppercase tracking-wider">Tempo Control</div>
          <div className="text-2xl font-black text-white mt-1">
            {set.analysis.tempoScore}<span className="text-xs text-neutral-500">/100</span>
          </div>
          <div className="text-[11px] text-neutral-400 mt-0.5">{set.analysis.meanDuration.toFixed(1)}s per rep</div>
        </div>

        <div className="p-3 bg-neutral-950 rounded-2xl border border-white/5">
          <div className="text-[10px] font-bold text-neutral-400 uppercase tracking-wider">Form Stability</div>
          <div className="text-2xl font-black text-white mt-1">
            {set.analysis.overallScore}<span className="text-xs text-neutral-500">/100</span>
          </div>
          <div className="text-[11px] text-[#00E676] mt-0.5">Strict execution</div>
        </div>
      </div>

      {/* Multi-Set Actions */}
      <div className="space-y-2 mt-auto">
        <button
          onClick={onLogNextSet}
          className="w-full bg-[#00E676] hover:bg-[#00E676]/90 text-black font-extrabold text-base py-4 rounded-2xl flex items-center justify-center gap-2 shadow-lg shadow-[#00E676]/20 active:scale-[0.98] transition-transform"
        >
          <Plus className="w-5 h-5" />
          <span>LOG NEXT SET (SET {activeSetsCount + 2})</span>
        </button>

        <button
          onClick={onFinishWorkout}
          className="w-full bg-neutral-900 hover:bg-neutral-800 text-white font-bold text-sm py-3.5 rounded-2xl flex items-center justify-center gap-2 border border-white/10 active:scale-[0.98] transition-transform"
        >
          <BarChart3 className="w-4 h-4 text-[#00E676]" />
          <span>FINISH WORKOUT & VIEW SUMMARY</span>
        </button>
      </div>
    </div>
  );
};
