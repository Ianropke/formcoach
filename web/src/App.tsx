import React, { useState, useEffect, useRef } from 'react';
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

  const [storageError, setStorageError] = useState<string | null>(null);
  const [historyLoaded, setHistoryLoaded] = useState(false);
  const [historyComplete, setHistoryComplete] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const savingRef = useRef(false);

  const loadHistory = async () => {
    try {
      const result = await LocalStorageManager.getHistory();
      setHistory(result.sets);
      setHistoryComplete(result.complete);
      setStorageError(result.complete ? null : 'Historikarkivet er utilgængeligt. Kun en eventuel ældre cache er læst; baselines er derfor skjult. Prøv igen.');
      setHistoryLoaded(true);
    } catch {
      setStorageError('Historikken kunne ikke læses. Eksisterende data er bevaret. Prøv igen.');
    }
  };

  useEffect(() => {
    void loadHistory();

    // Allow automated testing harness to preview flows
    const handleTestFlow = (e: any) => {
      const detail = e.detail;
      if (detail?.flow) {
        if (detail.set) setCurrentResultSet(detail.set);
        if (detail.sessionSets) setActiveSessionSets(detail.sessionSets);
        setActiveFlow(detail.flow);
        setCurrentTab('workout');
      }
    };
    window.addEventListener('formcoach_test_flow' as any, handleTestFlow);
    return () => window.removeEventListener('formcoach_test_flow' as any, handleTestFlow);
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

  const saveResult = async (next: 'recording' | 'summary', finalSet?: RecordedSet) => {
    const setToSave = finalSet || currentResultSet;
    if (!setToSave || savingRef.current) return;
    savingRef.current = true;
    setIsSaving(true);
    if (historyComplete) setStorageError(null);
    try {
      await LocalStorageManager.saveSet(setToSave);
      setActiveSessionSets(prev => [...prev.filter(s => s.id !== setToSave.id), setToSave]);
      setHistory(prev => [setToSave, ...prev.filter(s => s.id !== setToSave.id)]);
      setActiveFlow(next);
    } catch {
      setStorageError('Sættet blev ikke gemt. Det ligger stadig her, så du kan prøve igen.');
    } finally {
      savingRef.current = false;
      setIsSaving(false);
    }
  };
  const handleSaveAndLogNext = (set?: RecordedSet) => { void saveResult('recording', set); };
  const handleSaveAndFinish = (set?: RecordedSet) => { void saveResult('summary', set); };

  const handleDiscard = () => {
    // Drop in-memory set completely and revoke temporary video blob URL without writing to storage
    if (currentResultSet?.videoUrl) {
      try {
        URL.revokeObjectURL(currentResultSet.videoUrl);
      } catch (e) {}
    }
    setCurrentResultSet(null);
    setActiveFlow('selector');
  };

  const handleDoneSummary = () => {
    // Clean up any remaining in-memory video blobs
    activeSessionSets.forEach(s => {
      if (s.videoUrl) {
        try {
          URL.revokeObjectURL(s.videoUrl);
        } catch (e) {}
      }
    });
    setActiveSessionSets([]);
    setCurrentResultSet(null);
    setActiveFlow('selector');
  };

  return (
    <div className="flex flex-col h-screen w-screen bg-black text-white select-none overflow-hidden">
      {storageError && <div role="alert" className="p-3 text-sm bg-red-950 text-red-100">
        {storageError}
        {!historyComplete && <button className="ml-3 underline" onClick={() => void loadHistory()}>Prøv igen</button>}
      </div>}
      {/* Active Flow Views */}
      <div className="flex-1 overflow-hidden">
        {!historyLoaded ? <p className="p-6">{storageError ? 'Historik er ikke tilgængelig.' : 'Indlæser historik…'}</p> : currentTab === 'baselines' ? (
          historyComplete ? <BaselinesView history={history} onBack={() => setCurrentTab('workout')} /> : <p className="p-6">Baselines kræver adgang til hele historikken. {history.length} sæt findes i den tilgængelige cache.</p>
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
                isSaving={isSaving}
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
                historyComplete={historyComplete}
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
            <span className="text-[10px] font-bold uppercase tracking-wider">Træning</span>
          </button>

          <button
            onClick={() => setCurrentTab('baselines')}
            className={`flex flex-col items-center gap-1 transition-colors ${
              currentTab === 'baselines' ? 'text-[#00E676]' : 'text-neutral-500'
            }`}
          >
            <Activity className="w-5 h-5" />
            <span className="text-[10px] font-bold uppercase tracking-wider">Formkurve</span>
          </button>
        </div>
      )}
    </div>
  );
}
