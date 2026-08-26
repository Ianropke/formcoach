import React, { useState, useEffect } from 'react';
import { ExerciseType, CameraViewType, RecordedSet } from './core/models';
import { LocalStorageManager } from './core/storage';
import { ExerciseSelector } from './components/ExerciseSelector';
import { CameraRecordingView } from './components/CameraRecordingView';
import { ResultsView } from './components/ResultsView';
import { WorkoutSummaryView } from './components/WorkoutSummaryView';
import { BaselinesView } from './components/BaselinesView';
import { Dumbbell, Activity } from 'lucide-react';

export default function App() {
  const [currentTab, setCurrentTab] = useState<'workout' | 'baselines'>('workout');
  const [activeFlow, setActiveFlow] = useState<'selector' | 'recording' | 'results' | 'summary'>('selector');

  const [selectedExercise, setSelectedExercise] = useState<ExerciseType>('bicepsCurl');
  const [selectedView, setSelectedView] = useState<CameraViewType>('side');

  const [activeSessionSets, setActiveSessionSets] = useState<RecordedSet[]>([]);
  const [currentResultSet, setCurrentResultSet] = useState<RecordedSet | null>(null);
  const [history, setHistory] = useState<RecordedSet[]>([]);

  useEffect(() => {
    setHistory(LocalStorageManager.getRecordedSets());
  }, []);

  const handleStartExercise = (exercise: ExerciseType, view: CameraViewType) => {
    setSelectedExercise(exercise);
    setSelectedView(view);
    setActiveFlow('recording');
  };

  // Preview result in-memory before persisting
  const handleFinishSet = (set: RecordedSet) => {
    setCurrentResultSet(set);
    setActiveFlow('results');
  };

  const handleSaveAndLogNext = () => {
    if (currentResultSet) {
      LocalStorageManager.saveSet(currentResultSet);
      setActiveSessionSets(prev => [...prev, currentResultSet]);
      setHistory(LocalStorageManager.getRecordedSets());
    }
    setActiveFlow('recording');
  };

  const handleSaveAndFinish = () => {
    if (currentResultSet) {
      LocalStorageManager.saveSet(currentResultSet);
      const updated = [...activeSessionSets, currentResultSet];
      setActiveSessionSets(updated);
      setHistory(LocalStorageManager.getRecordedSets());
    }
    setActiveFlow('summary');
  };

  const handleDiscard = () => {
    // Drop in-memory set completely without writing to storage
    setCurrentResultSet(null);
    setActiveFlow('selector');
  };

  const handleDoneSummary = () => {
    setActiveSessionSets([]);
    setCurrentResultSet(null);
    setActiveFlow('selector');
  };

  return (
    <div className="flex flex-col h-screen w-screen bg-black text-white select-none overflow-hidden">
      {/* Active Flow Views */}
      <div className="flex-1 overflow-hidden">
        {currentTab === 'baselines' ? (
          <BaselinesView history={history} onBack={() => setCurrentTab('workout')} />
        ) : (
          <>
            {activeFlow === 'selector' && (
              <ExerciseSelector onStartExercise={handleStartExercise} />
            )}

            {activeFlow === 'recording' && (
              <CameraRecordingView
                exercise={selectedExercise}
                view={selectedView}
                onBack={() => setActiveFlow('selector')}
                onFinishSet={handleFinishSet}
              />
            )}

            {activeFlow === 'results' && currentResultSet && (
              <ResultsView
                set={currentResultSet}
                activeSetsCount={activeSessionSets.length}
                onSaveAndLogNext={handleSaveAndLogNext}
                onSaveAndFinish={handleSaveAndFinish}
                onDiscard={handleDiscard}
              />
            )}

            {activeFlow === 'summary' && (
              <WorkoutSummaryView
                sets={activeSessionSets}
                allHistory={history}
                onDone={handleDoneSummary}
              />
            )}
          </>
        )}
      </div>

      {/* Bottom Nav Bar (Shown only in selector & baselines view) */}
      {activeFlow === 'selector' && (
        <div className="bg-black/95 border-t border-white/10 px-6 py-3 flex items-center justify-around z-20">
          <button
            onClick={() => setCurrentTab('workout')}
            className={`flex flex-col items-center gap-1 transition-colors ${
              currentTab === 'workout' ? 'text-[#00E676]' : 'text-neutral-500'
            }`}
          >
            <Dumbbell className="w-5 h-5" />
            <span className="text-[10px] font-bold uppercase tracking-wider">Routine</span>
          </button>

          <button
            onClick={() => setCurrentTab('baselines')}
            className={`flex flex-col items-center gap-1 transition-colors ${
              currentTab === 'baselines' ? 'text-[#00E676]' : 'text-neutral-500'
            }`}
          >
            <Activity className="w-5 h-5" />
            <span className="text-[10px] font-bold uppercase tracking-wider">Baselines</span>
          </button>
        </div>
      )}
    </div>
  );
}
