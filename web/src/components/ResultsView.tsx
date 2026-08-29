import React, { useState, useEffect, useRef } from 'react';
import { RecordedSet, EXERCISES, ExerciseType } from '../core/models';
import { Check, Plus, BarChart3, Trash2, Video, Eye, Play } from 'lucide-react';
import confetti from 'canvas-confetti';

interface Props {
  set: RecordedSet;
  activeSetsCount: number;
  onSaveAndLogNext: () => void;
  onSaveAndFinish: () => void;
  onDiscard: () => void;
}

export const ResultsView: React.FC<Props> = ({
  set,
  activeSetsCount,
  onSaveAndLogNext,
  onSaveAndFinish,
  onDiscard
}) => {
  const [selectedRepIndex, setSelectedRepIndex] = useState(1);
  const [displayMode, setDisplayMode] = useState<'skeleton' | 'video'>(set.videoUrl ? 'video' : 'skeleton');
  const videoPlaybackRef = useRef<HTMLVideoElement>(null);
  const exerciseDef = EXERCISES[set.exercise] || Object.values(EXERCISES)[0];

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

  // Automatically seek to selected rep in video replay mode
  useEffect(() => {
    if (displayMode === 'video' && videoPlaybackRef.current && selectedRep) {
      videoPlaybackRef.current.currentTime = Math.max(0, selectedRep.startTime - 0.2);
      videoPlaybackRef.current.playbackRate = 0.75;
      videoPlaybackRef.current.play().catch(() => {});
    }
  }, [selectedRepIndex, displayMode]);

  return (
    <div className="flex flex-col h-full bg-black px-4 pt-3 pb-6 max-w-md mx-auto overflow-y-auto">
      {/* Top Bar */}
      <div className="flex items-center justify-between mb-3">
        <div>
          <div className="text-xl font-black uppercase text-white tracking-tight">
            {exerciseDef.name}
          </div>
          <div className="text-xs font-semibold text-neutral-400">
            {set.reps.length} gentagelser målt • Sæt {activeSetsCount + 1}
          </div>
        </div>
        <button
          onClick={onDiscard}
          className="flex items-center gap-1 text-xs font-bold text-red-400 bg-red-950/40 border border-red-500/20 px-3 py-1.5 rounded-xl hover:bg-red-950/70 transition-colors"
        >
          <Trash2 className="w-3.5 h-3.5" />
          <span>Kassér</span>
        </button>
      </div>

      {/* Dynamic Biomechanical Visualizer Box (Video / Skeleton) */}
      <div className="relative w-full h-56 bg-neutral-950 rounded-2xl border border-white/10 overflow-hidden flex items-center justify-center mb-3">
        {displayMode === 'video' && set.videoUrl ? (
          <div className="relative w-full h-full bg-black flex items-center justify-center">
            <video
              ref={videoPlaybackRef}
              src={set.videoUrl}
              playsInline
              controls
              className="w-full h-full object-contain"
            />
          </div>
        ) : (
          <svg viewBox="0 0 360 210" className="w-full h-full">
            {renderDynamicSkeleton(set.exercise, selectedRep.primaryROM)}
          </svg>
        )}

        {/* View Switcher Tabs (Video vs Skeleton) */}
        {set.videoUrl && (
          <div className="absolute top-3 right-3 z-10 flex bg-black/80 backdrop-blur-md rounded-lg p-0.5 border border-white/10 shadow-lg">
            <button
              onClick={() => setDisplayMode('video')}
              className={`flex items-center gap-1 text-[10px] font-bold px-2 py-1 rounded-md transition-colors ${
                displayMode === 'video' ? 'bg-[#00E676] text-black' : 'text-neutral-400 hover:text-white'
              }`}
            >
              <Video className="w-3 h-3" />
              <span>Video</span>
            </button>
            <button
              onClick={() => setDisplayMode('skeleton')}
              className={`flex items-center gap-1 text-[10px] font-bold px-2 py-1 rounded-md transition-colors ${
                displayMode === 'skeleton' ? 'bg-[#00E676] text-black' : 'text-neutral-400 hover:text-white'
              }`}
            >
              <Eye className="w-3 h-3" />
              <span>Skelet</span>
            </button>
          </div>
        )}

        {/* Measured Angle Badge */}
        <div className="absolute top-3 left-3 bg-[#00E676] text-black font-black text-xs px-2.5 py-1 rounded-lg shadow-md shadow-[#00E676]/20">
          Målt: {Math.round(selectedRep.primaryROM)}°
        </div>
        <div className="absolute bottom-3 left-3 right-3 flex items-center justify-between pointer-events-none">
          <div className="bg-black/80 font-mono text-[10px] text-neutral-300 px-2.5 py-1 rounded-lg border border-white/10 backdrop-blur-xs">
            Rep {selectedRep.index} • {selectedRep.duration.toFixed(1)}s (Eks: {selectedRep.eccentricDuration.toFixed(1)}s / Kon: {selectedRep.concentricDuration.toFixed(1)}s)
          </div>
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
                <span className="text-[#00E676]">MÅLT</span>
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
          <span>VIGTIGSTE OBSERVARING</span>
        </div>
        <p className="text-xs font-semibold leading-relaxed text-neutral-200">
          {set.analysis.primaryObservation}
        </p>
      </div>

      {/* Empirical Kinematic Metrics Grid */}
      <div className="grid grid-cols-2 gap-2.5 mb-4">
        {/* Card 1: ROM & Dispersion */}
        <div className="p-3 bg-neutral-950 rounded-2xl border border-white/5">
          <div className="text-[10px] font-bold text-neutral-400 uppercase tracking-wider">Bevægelsesbane (ROM)</div>
          <div className="text-2xl font-black text-white mt-1">
            ~{Math.round(set.analysis.meanROM)}°
          </div>
          <div className="text-[11px] text-neutral-400 mt-0.5 font-mono">
            Spredning: ±{set.analysis.romStdDev || 0}°
          </div>
        </div>

        {/* Card 2: Tempo & Phase Breakdown */}
        <div className="p-3 bg-neutral-950 rounded-2xl border border-white/5">
          <div className="text-[10px] font-bold text-neutral-400 uppercase tracking-wider">Tempo & Faser</div>
          <div className="text-2xl font-black text-white mt-1">
            {set.analysis.meanDuration.toFixed(1)}s
          </div>
          <div className="text-[11px] text-neutral-400 mt-0.5 font-mono">
            Eks: {(set.analysis.eccentricMean || 1.2).toFixed(1)}s / Kon: {(set.analysis.concentricMean || 1.1).toFixed(1)}s
          </div>
        </div>

        {/* Card 3: Kinematic Stability / Relative Drift / Bilateral Asymmetry */}
        <div className="p-3 bg-neutral-950 rounded-2xl border border-white/5">
          <div className="text-[10px] font-bold text-neutral-400 uppercase tracking-wider">
            {set.exercise === 'shoulderPress' ? 'Bilateral Asymmetri' : 'Skuldersvaj (Δθ)'}
          </div>
          <div className="text-2xl font-black text-white mt-1">
            {set.exercise === 'shoulderPress'
              ? `~${Math.round(set.analysis.meanAsymmetry || 0)}°`
              : set.analysis.peakRelativeDrift !== undefined
              ? `Δ${Math.round(set.analysis.peakRelativeDrift)}°`
              : set.analysis.stabilityStatus === 'STRICT_STABILITY' ? 'Strikte' : 'Variabel'}
          </div>
          <div className="text-[11px] text-neutral-400 mt-0.5">
            {set.exercise === 'shoulderPress'
              ? '|Venstre - Højre| forskel'
              : set.analysis.peakRelativeDrift !== undefined
              ? 'Maksimal afvigelse'
              : 'Stabil bane'}
          </div>
        </div>

        {/* Card 4: Fatigue / Late-Set Decay */}
        <div className="p-3 bg-neutral-950 rounded-2xl border border-white/5">
          <div className="text-[10px] font-bold text-neutral-400 uppercase tracking-wider">Udmattelse / ROM-Fald</div>
          <div className={`text-2xl font-black mt-1 ${set.analysis.earlyLateROMDelta && set.analysis.earlyLateROMDelta >= 10 ? 'text-amber-400' : 'text-[#00E676]'}`}>
            {set.analysis.earlyLateROMDelta && set.analysis.earlyLateROMDelta > 0
              ? `+${Math.round(set.analysis.earlyLateROMDelta)}%`
              : '0% Fald'}
          </div>
          <div className="text-[11px] text-neutral-400 mt-0.5">
            {set.analysis.earlyLateROMDelta && set.analysis.earlyLateROMDelta >= 10
              ? 'Mindre dybde i slutningen'
              : 'Stabil dybde hele sættet'}
          </div>
        </div>
      </div>

      {/* Explicit Save Actions */}
      <div className="space-y-2 mt-auto">
        <button
          onClick={onSaveAndLogNext}
          className="w-full bg-[#00E676] hover:bg-[#00E676]/90 text-black font-extrabold text-base py-4 rounded-2xl flex items-center justify-center gap-2 shadow-lg shadow-[#00E676]/20 active:scale-[0.98] transition-transform"
        >
          <Plus className="w-5 h-5" />
          <span>GEM OG START NÆSTE SÆT (SÆT {activeSetsCount + 2})</span>
        </button>

        <button
          onClick={onSaveAndFinish}
          className="w-full bg-neutral-900 hover:bg-neutral-800 text-white font-bold text-sm py-3.5 rounded-2xl flex items-center justify-center gap-2 border border-white/10 active:scale-[0.98] transition-transform"
        >
          <BarChart3 className="w-4 h-4 text-[#00E676]" />
          <span>GEM OG SE TRÆNINGSOVERSIGT</span>
        </button>
      </div>
    </div>
  );
};

function renderDynamicSkeleton(exercise: ExerciseType, rom: number) {
  const headCx = 180;
  const headCy = 50;
  const neckY = 64;
  const spineEndY = 120;

  if (exercise === 'squat' || exercise === 'legPress') {
    const clampedAngle = Math.max(65, Math.min(175, rom));
    const rad = (clampedAngle * Math.PI) / 180;
    const hipY = 120 + ((180 - clampedAngle) / 180) * 25;
    const kneeX = 145 - ((180 - clampedAngle) / 180) * 15;
    const kneeY = hipY + Math.sin(rad / 2) * 40;
    const ankleX = 170;
    const ankleY = 185;

    return (
      <>
        <line x1="50" y1="185" x2="310" y2="185" stroke="#333" strokeWidth="3" />
        <line x1={headCx} y1={neckY} x2={headCx - 5} y2={hipY} stroke="#fff" strokeWidth="3.5" strokeLinecap="round" />
        <circle cx={headCx} cy={headCy} r="13" fill="#111" stroke="#00E676" strokeWidth="2.5" />
        <line x1={headCx - 5} y1={hipY} x2={kneeX} y2={kneeY} stroke="#00E676" strokeWidth="4" strokeLinecap="round" />
        <line x1={kneeX} y1={kneeY} x2={ankleX} y2={ankleY} stroke="#00E676" strokeWidth="4" strokeLinecap="round" />
        <line x1={headCx} y1={neckY + 10} x2={headCx - 35} y2={neckY + 25} stroke="#888" strokeWidth="3" strokeLinecap="round" />
        <circle cx={headCx - 5} cy={hipY} r="5" fill="#00E676" />
        <circle cx={kneeX} cy={kneeY} r="6" fill="#FFEB3B" stroke="#000" strokeWidth="2" />
        <circle cx={ankleX} cy={ankleY} r="5" fill="#00E676" />
      </>
    );
  } else if (exercise === 'bicepsCurl') {
    const clampedAngle = Math.max(35, Math.min(160, rom));
    const shoulderX = 175;
    const shoulderY = 80;
    const elbowX = 170;
    const elbowY = 125;
    const curlRad = ((180 - clampedAngle) * Math.PI) / 180;
    const wristX = elbowX - Math.sin(curlRad) * 40;
    const wristY = elbowY - Math.cos(curlRad) * 40;

    return (
      <>
        <line x1="50" y1="185" x2="310" y2="185" stroke="#222" strokeWidth="3" />
        <line x1={headCx} y1={neckY} x2={headCx} y2={spineEndY} stroke="#fff" strokeWidth="3.5" strokeLinecap="round" />
        <circle cx={headCx} cy={headCy} r="13" fill="#111" stroke="#00E676" strokeWidth="2.5" />
        <line x1={headCx} y1={spineEndY} x2={headCx} y2={185} stroke="#666" strokeWidth="3.5" strokeLinecap="round" />
        <line x1={shoulderX} y1={shoulderY} x2={elbowX} y2={elbowY} stroke="#fff" strokeWidth="4" strokeLinecap="round" />
        <line x1={elbowX} y1={elbowY} x2={wristX} y2={wristY} stroke="#00E676" strokeWidth="4.5" strokeLinecap="round" />
        <circle cx={wristX} cy={wristY} r="7" fill="#FFEB3B" stroke="#000" strokeWidth="2" />
        <circle cx={shoulderX} cy={shoulderY} r="5" fill="#00E676" />
        <circle cx={elbowX} cy={elbowY} r="6" fill="#FFEB3B" stroke="#000" strokeWidth="2" />
      </>
    );
  } else if (exercise === 'shoulderPress') {
    const clampedAngle = Math.max(80, Math.min(180, rom));
    const shoulderL = 155;
    const shoulderR = 205;
    const shoulderY = 85;
    const extRad = ((clampedAngle - 90) * Math.PI) / 180;
    const elbowLX = 135 - Math.cos(extRad) * 15;
    const elbowLY = 85 - Math.sin(extRad) * 25;
    const wristLX = elbowLX + Math.cos(extRad) * 15;
    const wristLY = elbowLY - Math.sin(extRad) * 35;

    const elbowRX = 225 + Math.cos(extRad) * 15;
    const elbowRY = 85 - Math.sin(extRad) * 25;
    const wristRX = elbowRX - Math.cos(extRad) * 15;
    const wristRY = elbowRY - Math.sin(extRad) * 35;

    return (
      <>
        <line x1="50" y1="185" x2="310" y2="185" stroke="#222" strokeWidth="3" />
        <line x1={headCx} y1={neckY} x2={headCx} y2={spineEndY} stroke="#fff" strokeWidth="3.5" strokeLinecap="round" />
        <circle cx={headCx} cy={headCy} r="13" fill="#111" stroke="#00E676" strokeWidth="2.5" />
        <line x1={headCx} y1={spineEndY} x2={165} y2={185} stroke="#666" strokeWidth="3.5" strokeLinecap="round" />
        <line x1={headCx} y1={spineEndY} x2={195} y2={185} stroke="#666" strokeWidth="3.5" strokeLinecap="round" />
        <line x1={shoulderL} y1={shoulderY} x2={elbowLX} y2={elbowLY} stroke="#00E676" strokeWidth="3.5" strokeLinecap="round" />
        <line x1={elbowLX} y1={elbowLY} x2={wristLX} y2={wristLY} stroke="#00E676" strokeWidth="3.5" strokeLinecap="round" />
        <line x1={shoulderR} y1={shoulderY} x2={elbowRX} y2={elbowRY} stroke="#00E676" strokeWidth="3.5" strokeLinecap="round" />
        <line x1={elbowRX} y1={elbowRY} x2={wristRX} y2={wristRY} stroke="#00E676" strokeWidth="3.5" strokeLinecap="round" />
        <line x1={wristLX - 15} y1={wristLY} x2={wristRX + 15} y2={wristRY} stroke="#FFEB3B" strokeWidth="4" strokeLinecap="round" />
        <circle cx={elbowLX} cy={elbowLY} r="5" fill="#00E676" />
        <circle cx={elbowRX} cy={elbowRY} r="5" fill="#00E676" />
        <circle cx={wristLX} cy={wristLY} r="5" fill="#FFEB3B" stroke="#000" strokeWidth="1.5" />
        <circle cx={wristRX} cy={wristRY} r="5" fill="#FFEB3B" stroke="#000" strokeWidth="1.5" />
      </>
    );
  } else {
    const clampedAngle = Math.max(70, Math.min(180, rom));
    const shoulderX = 175;
    const shoulderY = 80;
    const elbowX = 170;
    const elbowY = 120;
    const extRad = (clampedAngle * Math.PI) / 180;
    const wristX = elbowX + Math.sin(extRad - Math.PI/2) * 42;
    const wristY = elbowY + Math.cos(extRad - Math.PI/2) * 42;

    return (
      <>
        <line x1="50" y1="185" x2="310" y2="185" stroke="#222" strokeWidth="3" />
        <line x1={headCx} y1={neckY} x2={headCx} y2={spineEndY} stroke="#fff" strokeWidth="3.5" strokeLinecap="round" />
        <circle cx={headCx} cy={headCy} r="13" fill="#111" stroke="#00E676" strokeWidth="2.5" />
        <line x1={headCx} y1={spineEndY} x2={headCx} y2={185} stroke="#666" strokeWidth="3.5" strokeLinecap="round" />
        <line x1="210" y1="40" x2={wristX} y2={wristY} stroke="#555" strokeWidth="1.5" strokeDasharray="3 3" />
        <line x1={shoulderX} y1={shoulderY} x2={elbowX} y2={elbowY} stroke="#fff" strokeWidth="4" strokeLinecap="round" />
        <line x1={elbowX} y1={elbowY} x2={wristX} y2={wristY} stroke="#00E676" strokeWidth="4.5" strokeLinecap="round" />
        <circle cx={wristX} cy={wristY} r="6" fill="#FFEB3B" stroke="#000" strokeWidth="2" />
        <circle cx={elbowX} cy={elbowY} r="6" fill="#FFEB3B" stroke="#000" strokeWidth="2" />
      </>
    );
  }
}
