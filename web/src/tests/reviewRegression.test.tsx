import test from 'node:test';
import assert from 'node:assert/strict';
import React from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { IDBFactory } from 'fake-indexeddb';
import { PoseSmoother } from '../core/poseSmoother';
import { getActiveAngle, getJointAngle } from '../core/jointAngles';
import { BicepCurlAnalyzer, TricepsPushdownAnalyzer, ShoulderPressAnalyzer } from '../core/analyzers/exerciseAnalyzers';
import { SyntheticCurlGenerator, SyntheticPressGenerator } from './syntheticGenerators';
import { CrossSetFatigueAnalyzer } from '../core/fatigueAnalyzer';
import { PersonalBaselineEngine } from '../core/baselineEngine';
import { LocalStorageManager } from '../core/storage';
import { readZoom, applyZoom } from '../core/cameraZoom';
import { ResultsView } from '../components/ResultsView';
import { WorkoutSummaryView } from '../components/WorkoutSummaryView';
import { BaselinesView } from '../components/BaselinesView';
import { PoseFrame, RecordedSet, ExerciseType } from '../core/models';

const curl = new BicepCurlAnalyzer();
const frames = SyntheticCurlGenerator.generateCurlSet(10);
const reps = curl.segmentReps(frames);
const makeSet = (exercise: ExerciseType, rom: number, id = '1'): RecordedSet => ({
  id, exercise, view: 'side', date: `2026-08-31T12:00:${id.padStart(2,'0')}.000Z`,
  reps: reps.map(r => ({ ...r, primaryROM: rom })),
  analysis: { ...curl.analyzeSet(reps), meanROM: rom, meanDuration: 3 }
});

test('3D stream survives smoothing and drives segmentation instead of its 2D projection', () => {
  const input = frames.map(f => ({ ...f, aspectRatio: 16 / 9,
    worldJoints: Object.fromEntries(Object.entries(f.joints).map(([key, p]) => [key, { ...p, z: 0 }])),
    joints: SyntheticCurlGenerator.createCurlFrame(f.timestamp, 165, 0).joints
  }));
  const before = structuredClone(input);
  const smoothed = new PoseSmoother().smooth(input);
  assert.equal(curl.segmentReps(smoothed).length, 10);
  assert.equal(smoothed[0].aspectRatio, 16 / 9);
  assert.ok(smoothed.every(f => f.worldJoints?.left_elbow));
  assert.deepEqual(input, before);
});

test('2D fallback corrects non-square normalized coordinates', () => {
  const frame: PoseFrame = { timestamp: 0, confidence: 1, aspectRatio: 2,
    joints: { left_shoulder: {x:0.5,y:1,score:1}, left_elbow:{x:0,y:0,score:1},left_wrist:{x:0.5,y:0,score:1} } };
  assert.ok(Math.abs(getActiveAngle(frame,'bicepsCurl')! - 45) < 0.001);
});

test('live angle selects visible right limb over occluded left', () => {
  const frame = structuredClone(frames[0]);
  frame.joints.right_shoulder = frame.joints.left_shoulder;
  frame.joints.right_elbow = frame.joints.left_elbow;
  frame.joints.right_wrist = frame.joints.left_wrist;
  frame.joints.left_wrist = {x:0,y:0,score:0};
  assert.equal(getActiveAngle(frame,'bicepsCurl'), getJointAngle(frame,'right_shoulder','right_elbow','right_wrist'));
});

function noHips(input: PoseFrame[]): PoseFrame[] {
  return input.map(f => ({ ...f, joints: Object.fromEntries(Object.entries(f.joints).filter(([key]) => !key.includes('hip'))) }));
}

test('missing hips preserve reps but never approve curl technique or show zero drift', () => {
  const missing = curl.segmentReps(new PoseSmoother().smooth(noHips(frames)));
  assert.equal(missing.length, 10);
  const analysis = curl.analyzeSet(missing);
  assert.equal(analysis.secondaryMetricsAvailable, false);
  assert.equal(analysis.peakRelativeDrift, undefined);
  assert.equal(analysis.stabilityStatus, 'INSUFFICIENT_DATA');
  assert.ok(!analysis.observations.some(o => o.severity === 'positive'));
  const html = renderToStaticMarkup(<ResultsView set={{...makeSet('bicepsCurl',55), reps:missing, analysis}} activeSetsCount={0} onSaveAndLogNext={()=>{}} onSaveAndFinish={()=>{}} onDiscard={()=>{}} />);
  assert.match(html, /Utilstrækkelige ledmålinger/);
  assert.doesNotMatch(html, /Δ0°|Δ6°|0% Fald/);
});

test('triceps missing hip measurements never produce strict-extension praise', () => {
  const triceps = new TricepsPushdownAnalyzer();
  const measured = triceps.segmentReps(noHips(SyntheticPressGenerator.generatePressSet(5,30,80,165,165)));
  assert.ok(measured.length > 0);
  assert.equal(triceps.analyzeSet(measured).secondaryMetricsAvailable, false);
});

test('one-sided shoulder press does not claim bilateral symmetry', () => {
  const press = new ShoulderPressAnalyzer();
  const input = SyntheticPressGenerator.generatePressSet(5,30,80,165,165).map(f => ({...f,joints:Object.fromEntries(Object.entries(f.joints).filter(([k])=>!k.startsWith('right')))}));
  const measured = press.segmentReps(input);
  assert.equal(measured.length,5);
  const result = press.analyzeSet(measured);
  assert.equal(result.meanAsymmetry,undefined);
  assert.equal(result.symmetryScore,undefined);
  assert.equal(result.secondaryMetricsAvailable,false);
});

for (const exercise of ['shoulderPress','tricepsPushdown'] as const) {
  test(`${exercise}: worse lockout degrades, better lockout improves`, () => {
    const good = makeSet(exercise,170), bad = makeSet(exercise,140,'2');
    assert.equal(CrossSetFatigueAnalyzer.analyzeSession([good,bad]).romTrend,'degrading');
    assert.equal(CrossSetFatigueAnalyzer.analyzeSession([bad,good]).romTrend,'improving');
    assert.equal(CrossSetFatigueAnalyzer.analyzeSession([bad,good]).fatigueIndex,0);
  });
}

test('one set and mixed exercises have no fatigue estimate', () => {
  assert.equal(CrossSetFatigueAnalyzer.analyzeSession([makeSet('squat',85)]).fatigueIndex,null);
  const mixed = CrossSetFatigueAnalyzer.analyzeSession([makeSet('squat',85),makeSet('shoulderPress',170)]);
  assert.equal(mixed.fatigueIndex,null);
  assert.equal(mixed.totalSets,2);
});

test('baseline uses observed dispersion and UI gates insufficient sample size', () => {
  const set = makeSet('bicepsCurl',55);
  const baseline = PersonalBaselineEngine.computeBaseline([set],'bicepsCurl');
  assert.equal(baseline.baselineROMStdDev,0);
  assert.equal(baseline.hasSufficientData,false);
  assert.equal(PersonalBaselineEngine.compareSet(set,baseline).isConsistent,false);
  const summary = renderToStaticMarkup(<WorkoutSummaryView sets={[set]} allHistory={[set]} onDone={()=>{}} />);
  assert.match(summary,/UTILSTRÆKKELIGT GRUNDLAG/);
  assert.match(summary,/Etablerer baseline/);
  assert.doesNotMatch(summary,/±3°|Samlet belastning/);
  const form = renderToStaticMarkup(<BaselinesView history={[set]} onBack={()=>{}} />);
  assert.doesNotMatch(form,/±3°/);
  assert.match(form,/10\/25 reps/);
  assert.equal(PersonalBaselineEngine.computeBaseline([set,{...set,id:'2'},{...set,id:'3'}],'bicepsCurl').baselineROMStdDev,0);
});

test('zoom exposes only supported levels and reads actual post-constraint settings', async () => {
  let actual = 1;
  const track = { getCapabilities:()=>({zoom:{min:1,max:2}}),getSettings:()=>({zoom:actual}),applyConstraints:async()=>{actual=2;} };
  assert.deepEqual(readZoom(track).levels,[1,2]);
  await assert.rejects(applyZoom(track,0.5));
  assert.equal(await applyZoom(track,2),2);
  assert.deepEqual(readZoom({...track,getCapabilities:()=>({})}),{levels:[],current:null});
  assert.equal(await applyZoom({...track,applyConstraints:async()=>{}},1),2);
});

test('IndexedDB reads all history, migrates legacy data, strips blobs, and reports write failure', async () => {
  const factory = new IDBFactory();
  Object.defineProperty(globalThis,'indexedDB',{value:factory,configurable:true});
  const cache = new Map<string,string>();
  Object.defineProperty(globalThis,'localStorage',{value:{getItem:(k:string)=>cache.get(k)??null,setItem:(k:string,v:string)=>cache.set(k,v),removeItem:(k:string)=>cache.delete(k)},configurable:true});
  // Seed an archived set absent from the old last-50 cache.
  await LocalStorageManager.saveSet({...makeSet('bicepsCurl',40,'archived'),videoUrl:'blob:expired'});
  cache.set('formcoach_workout_history_v1',JSON.stringify([makeSet('bicepsCurl',55,'legacy')]));
  for(let i=0;i<51;i++) await LocalStorageManager.saveSet(makeSet('squat',85,String(i)));
  const all = await LocalStorageManager.getRecordedSets();
  assert.equal(all.length,53);
  assert.ok(all.some(s=>s.id==='archived'));
  assert.ok(all.every(s=>s.videoUrl===undefined));
  assert.equal(cache.size,0);
  assert.equal((await LocalStorageManager.getRecordedSets()).length,53);
  assert.equal((await LocalStorageManager.getSetsForExercise('bicepsCurl')).length,2);
  // A value IndexedDB cannot clone must reject, never signal a successful save.
  await assert.rejects(LocalStorageManager.saveSet({...makeSet('squat',85,'failure'), analysis:{...makeSet('squat',85).analysis, invalid:()=>{}}} as RecordedSet));
  assert.equal((await LocalStorageManager.getRecordedSets()).length,53);
});

test('mounted save flow prevents duplicate clicks, retains failed result, and retries successfully', async () => {
  const { JSDOM } = await import('jsdom');
  const { act } = await import('react');
  const { createRoot } = await import('react-dom/client');
  const { default: App } = await import('../App');
  const dom = new JSDOM('<div id="root"></div>', {url:'http://localhost'});
  const oldWindow = Object.getOwnPropertyDescriptor(globalThis,'window');
  const oldDocument = Object.getOwnPropertyDescriptor(globalThis,'document');
  Object.defineProperty(globalThis,'window',{value:dom.window,configurable:true});
  Object.defineProperty(globalThis,'document',{value:dom.window.document,configurable:true});
  (globalThis as any).IS_REACT_ACT_ENVIRONMENT = true;
  const getHistory = LocalStorageManager.getHistory;
  const save = LocalStorageManager.saveSet;
  LocalStorageManager.getHistory = async () => ({sets:[],complete:true});
  let calls = 0;
  let rejectSave!: (error: Error) => void;
  let resolveSave!: () => void;
  LocalStorageManager.saveSet = () => {
    calls++;
    return new Promise<void>((resolve,reject) => { resolveSave=resolve; rejectSave=reject; });
  };
  const root = createRoot(dom.window.document.getElementById('root')!);
  const button = (text:string) => [...dom.window.document.querySelectorAll('button')].find(b=>b.textContent?.includes(text))!;
  try {
    await act(async () => { root.render(<App />); });
    const fixture = makeSet('bicepsCurl',55);
    fixture.analysis.overallScore = 70; // Avoid unrelated celebration/canvas animation.
    await act(async () => { dom.window.dispatchEvent(new dom.window.CustomEvent('formcoach_test_flow',{detail:{flow:'results',set:fixture}})); });
    await act(async () => {
      button('GEM OG SE').click();
      button('GEM OG SE').click();
    });
    assert.equal(calls,1);
    assert.equal(button('Kassér').disabled,true);
    await act(async () => { rejectSave(new Error('quota')); });
    assert.match(dom.window.document.body.textContent!,/Sættet blev ikke gemt/);
    assert.ok(button('GEM OG SE'));
    assert.equal(button('GEM OG SE').disabled,false);
    await act(async () => { button('GEM OG SE').click(); });
    await act(async () => { resolveSave(); });
    assert.equal(calls,2);
    assert.match(dom.window.document.body.textContent!,/TRÆNING GENNEMFØRT/);
    assert.doesNotMatch(dom.window.document.body.textContent!,/Sættet blev ikke gemt/);
  } finally {
    await act(async () => { root.unmount(); });
    LocalStorageManager.getHistory = getHistory;
    LocalStorageManager.saveSet = save;
    dom.window.close();
    if(oldWindow) Object.defineProperty(globalThis,'window',oldWindow); else delete (globalThis as any).window;
    if(oldDocument) Object.defineProperty(globalThis,'document',oldDocument); else delete (globalThis as any).document;
    delete (globalThis as any).IS_REACT_ACT_ENVIRONMENT;
  }
});


test('unavailable IndexedDB preserves legacy history and explicitly marks it incomplete', async () => {
  const previous = globalThis.indexedDB;
  (LocalStorageManager as any).dbPromise = null;
  const legacy = makeSet('bicepsCurl',55,'fallback');
  localStorage.setItem('formcoach_workout_history_v1',JSON.stringify([legacy]));
  Object.defineProperty(globalThis,'indexedDB',{value:{open:()=>{throw new Error('unavailable');}},configurable:true});
  try {
    const result = await LocalStorageManager.getHistory();
    assert.equal(result.complete,false);
    assert.equal(result.sets[0].id,'fallback');
    assert.ok(localStorage.getItem('formcoach_workout_history_v1'));
    await assert.rejects(LocalStorageManager.saveSet(legacy));
  } finally {
    Object.defineProperty(globalThis,'indexedDB',{value:previous,configurable:true});
    (LocalStorageManager as any).dbPromise = null;
  }
});
