import test from 'node:test';
import assert from 'node:assert/strict';
import { SquatAnalyzer, BicepCurlAnalyzer } from '../core/analyzers/exerciseAnalyzers';
import { Repetition } from '../core/models';

function rep(index: number, primaryROM: number, secondaryROM?: number): Repetition {
  return {
    index,
    startTime: index * 3,
    inflectionTime: index * 3 + 1.5,
    endTime: index * 3 + 3,
    duration: 3,
    concentricDuration: 1.5,
    eccentricDuration: 1.5,
    primaryROM,
    secondaryROM,
    confidence: 1
  };
}

test('late squat ROM change is described without assigning a physiological cause', () => {
  const analyzer = new SquatAnalyzer();
  const reps = [80, 80, 80, 80, 100, 100, 100, 100].map((rom, i) => rep(i + 1, rom));
  const result = analyzer.analyzeSet(reps);
  const text = [result.primaryObservation, ...result.observations.flatMap(o => [o.title, o.detail, o.evidence])].join(' ');

  assert.match(text, /Årsagen kan ikke bestemmes/);
  assert.doesNotMatch(text, /muskeludmattelse|pga\.\s*udmattelse/i);
});

test('squat depth reference is not described as muscle activation', () => {
  const analyzer = new SquatAnalyzer();
  const result = analyzer.analyzeSet([1, 2, 3, 4, 5, 6].map(i => rep(i, 110)));
  const text = [result.primaryObservation, ...result.observations.flatMap(o => [o.title, o.detail, o.evidence])].join(' ');

  assert.match(text, /coachingreference/);
  assert.doesNotMatch(text, /fuld aktivering|muskelaktivering som mål/i);
});

test('curl shoulder drift is reported as measured movement rather than momentum causality', () => {
  const analyzer = new BicepCurlAnalyzer();
  const result = analyzer.analyzeSet([1, 2, 3, 4, 5].map(i => rep(i, 55, 18)));
  const text = [result.primaryObservation, ...result.observations.flatMap(o => [o.title, o.detail, o.evidence])].join(' ');

  assert.match(text, /Relativ Skulderbevægelse/);
  assert.doesNotMatch(text, /Momentum Registreret|cheat/i);
});
