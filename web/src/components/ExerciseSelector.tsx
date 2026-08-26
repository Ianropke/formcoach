import React, { useState } from 'react';
import { ExerciseCategory, ExerciseType, EXERCISES, EXERCISE_CATEGORIES, CameraViewType } from '../core/models';
import { Camera, ChevronRight } from 'lucide-react';

interface Props {
  onStartExercise: (exercise: ExerciseType, view: CameraViewType) => void;
}

export const ExerciseSelector: React.FC<Props> = ({ onStartExercise }) => {
  const [selectedCategory, setSelectedCategory] = useState<ExerciseCategory | 'all'>('all');
  const [selectedExercise, setSelectedExercise] = useState<ExerciseType>('bicepsCurl');
  const [selectedView, setSelectedView] = useState<CameraViewType>('side');

  const exerciseList = Object.values(EXERCISES).filter(
    ex => selectedCategory === 'all' || ex.category === selectedCategory
  );

  const currentExerciseDef = EXERCISES[selectedExercise] || Object.values(EXERCISES)[0];

  const handleSelectExercise = (type: ExerciseType) => {
    setSelectedExercise(type);
    setSelectedView(EXERCISES[type].recommendedView);
  };

  return (
    <div className="flex flex-col h-full px-4 pt-3 pb-6 max-w-md mx-auto">
      {/* Brand Header */}
      <div className="mb-3">
        <div className="text-xs font-extrabold tracking-widest text-[#00E676] uppercase">FORMCOACH</div>
        <h1 className="text-2xl font-black tracking-tight text-white">My Gym Routine</h1>
      </div>

      {/* Category Pills */}
      <div className="flex gap-2 overflow-x-auto pb-2 scrollbar-none mb-3">
        <button
          onClick={() => setSelectedCategory('all')}
          className={`px-3 py-1.5 rounded-xl text-xs font-bold whitespace-nowrap transition-all ${
            selectedCategory === 'all' ? 'bg-[#00E676] text-black shadow-lg shadow-[#00E676]/20' : 'bg-neutral-900 text-neutral-300'
          }`}
        >
          All (5)
        </button>
        {EXERCISE_CATEGORIES.map(cat => (
          <button
            key={cat.id}
            onClick={() => setSelectedCategory(cat.id)}
            className={`flex items-center gap-1 px-3 py-1.5 rounded-xl text-xs font-bold whitespace-nowrap transition-all ${
              selectedCategory === cat.id ? 'bg-[#00E676] text-black shadow-lg shadow-[#00E676]/20' : 'bg-neutral-900 text-neutral-300'
            }`}
          >
            <span>{cat.icon}</span>
            <span>{cat.name}</span>
          </button>
        ))}
      </div>

      {/* Exercise Cards List */}
      <div className="flex-1 overflow-y-auto space-y-2.5 pr-0.5">
        {exerciseList.map(ex => {
          const isSelected = selectedExercise === ex.id;
          return (
            <div
              key={ex.id}
              onClick={() => handleSelectExercise(ex.id)}
              className={`p-3.5 rounded-2xl cursor-pointer transition-all border ${
                isSelected
                  ? 'bg-neutral-900 border-[#00E676] shadow-md shadow-[#00E676]/10'
                  : 'bg-neutral-950/80 border-white/5 hover:border-white/10'
              }`}
            >
              <div className="flex items-center justify-between">
                <div>
                  <div className="text-base font-extrabold text-white">{ex.name}</div>
                  <div className="text-xs font-medium text-neutral-400">{ex.subtitle}</div>
                </div>
                <div className="flex items-center gap-2">
                  <span className="bg-[#00E676] text-black text-[10px] font-black px-2 py-0.5 rounded-md">
                    VERIFIED
                  </span>
                  <ChevronRight className={`w-4 h-4 ${isSelected ? 'text-[#00E676]' : 'text-neutral-600'}`} />
                </div>
              </div>

              {/* Tags */}
              <div className="flex flex-wrap gap-1.5 mt-2.5">
                {ex.keyMetrics.map((m, i) => (
                  <span key={i} className="text-[10px] font-semibold px-2 py-0.5 rounded-md bg-white/5 text-neutral-300">
                    {m}
                  </span>
                ))}
              </div>
            </div>
          );
        })}
      </div>

      {/* Camera View Angle Selector */}
      <div className="mt-3 pt-3 border-t border-white/10">
        <div className="text-[11px] font-bold uppercase tracking-wider text-neutral-400 mb-2">
          Recommended Camera Angle
        </div>
        <div className="flex gap-2">
          {currentExerciseDef.supportedViews.map(view => (
            <button
              key={view}
              onClick={() => setSelectedView(view)}
              className={`flex-1 py-2 rounded-xl text-xs font-bold transition-all ${
                selectedView === view
                  ? 'bg-[#00E676] text-black'
                  : 'bg-neutral-900 text-neutral-300'
              }`}
            >
              {view === 'side' ? 'Side View' : view === 'front' ? 'Front View' : '45° Front'}
            </button>
          ))}
        </div>
      </div>

      {/* Start Button */}
      <button
        onClick={() => onStartExercise(selectedExercise, selectedView)}
        className="mt-4 w-full bg-[#00E676] hover:bg-[#00E676]/90 text-black font-extrabold text-base py-4 rounded-2xl flex items-center justify-center gap-2 shadow-lg shadow-[#00E676]/30 active:scale-[0.98] transition-transform"
      >
        <Camera className="w-5 h-5" />
        <span>Setup {currentExerciseDef.name} Camera</span>
      </button>
    </div>
  );
};
