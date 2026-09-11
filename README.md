# FormCoach — Local-First Strength Form Coach

FormCoach is an iPhone-first Web PWA that measures observable strength-training movement locally in the browser.

**Live PWA:** https://formcoach-orpin.vercel.app

## Current stack

- React 19 + TypeScript + Vite
- MediaPipe Tasks Vision running locally in the browser
- deterministic kinematic analyzers
- IndexedDB structured workout history
- no paid cloud inference required per workout

## Supported exercise analyzers

- Biceps curl
- Triceps pushdown
- Squat
- Leg press
- Shoulder press

These analyzers are implemented and regression-tested. That is separate from measured accuracy on real camera recordings; current evidence status is in `docs/PROJECT_STATE.md`.

## Run locally

```bash
npm install
npm run dev
```

## Verify

```bash
npm run test
npm run build
cd web && npm run lint
```

## Documentation

- `PRODUCT.md` — product behavior and evidence semantics
- `ARCHITECTURE.md` — canonical Web PWA architecture
- `DATA_MODEL.md` — current data-model source of truth
- `ANALYSIS_ENGINE.md` — analysis principles and code routing
- `EXERCISE_ANALYZERS.md` — analyzer scope and semantics
- `PRIVACY.md` — current local-data architecture
- `docs/PROJECT_STATE.md` — current implementation/evidence state
- `ROADMAP.md` — future direction
- `AGENTS.md` — concise agent contract/router

The earlier native Swift/SwiftUI implementation and its M1–M5 reports are historical and are not the current runtime.
