# FormCoach — Analysis Engine

The canonical implementation is the TypeScript code under `web/src/core/`.

## Core principles

- Joint angles are computed with deterministic vector geometry.
- Exercise repetitions are segmented with deterministic state machines and hysteresis.
- Tracking gaps and smoothing are handled before exercise interpretation.
- Observations are derived from measured kinematic values and configured rules.

## Evidence semantics

Keep these separate:

1. measured values from pose data;
2. derived comparisons such as early-versus-late ROM change;
3. configured product thresholds;
4. results demonstrated on real recordings.

A change in ROM, tempo, or symmetry does not by itself establish the cause of that change.

## Source of truth

Exact current thresholds and state transitions live in the implementation and tests, especially:

- `web/src/core/analyzers/exerciseAnalyzers.ts`
- `web/src/core/jointAngles.ts`
- `web/src/core/qualityGate.ts`
- `web/src/core/fatigueAnalyzer.ts`
- `web/src/tests/`

Do not duplicate changing threshold values here unless the document is updated with the code in the same change.
