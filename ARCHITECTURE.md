# FormCoach — System Architecture

The canonical application is the Web PWA in `web/`.

- React 19 + TypeScript + Vite.
- MediaPipe Tasks Vision runs locally in the browser.
- Deterministic analysis lives under `web/src/core/`.
- Structured workout history is stored in IndexedDB.
- Temporary replay video uses in-memory Blob/Object URLs.

The earlier Swift/SwiftUI implementation is historical and is not the current runtime.

## Data flow

```text
browser camera
  -> PoseLandmarkerService
  -> PoseFrame
  -> smoothing / setup-quality heuristics
  -> exercise analyzer
  -> SetAnalysis
  -> results / session comparison / personal baseline
  -> IndexedDB structured history
```

## Boundaries

`web/src/vision/poseLandmarkerService.ts` owns pose inference, landmark mapping, primary-athlete selection, and inference telemetry.

`web/src/core/` owns geometry, state machines, setup-quality heuristics, baselines, comparisons, and exercise analysis.

`web/src/components/` owns user interaction and presentation.

`web/src/core/storage.ts` owns local structured history. Temporary video URLs are removed from durable records.

## Calibration semantics

Values inferred from pose landmarks are pose-geometry proxies. They must not be described as direct hardware-sensor measurements unless a hardware sensor is actually used.

## Verification

Automated tests establish implementation behavior on controlled inputs. Real-world camera performance is tracked separately in `docs/PROJECT_STATE.md`.
