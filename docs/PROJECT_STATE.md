# FormCoach — current project state

Last reconciled: 2026-09-11.

## Canonical implementation

The active product is the Web PWA under `web/`:

- React + TypeScript + Vite
- MediaPipe Tasks Vision in the browser
- deterministic TypeScript analyzers
- IndexedDB structured history
- temporary in-memory replay video URLs

The older Swift/SwiftUI implementation and M1–M5 reports are historical.

## Implemented

The repository contains analyzers for biceps curl, triceps pushdown, squat, leg press, and shoulder press, plus setup checks, pose processing, session comparisons, personal baselines, local history, and deterministic tests.

## Evidence status

Implemented code and synthetic tests are not the same as measured performance on real recordings. Real-recording accuracy should be reported with an explicit protocol and error metrics.

## Documentation roles

- `AGENTS.md`: concise repository contract/router.
- `PRODUCT.md`: product behavior.
- `ARCHITECTURE.md`: current PWA architecture.
- `ROADMAP.md`: future direction.
- this file: current repository state.
