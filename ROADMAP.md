# FormCoach — Product & Engineering Roadmap

This roadmap applies to the canonical Web PWA in `web/`. The old native implementation is historical.

## Current foundation

- React/TypeScript PWA.
- Local MediaPipe processing.
- Five implemented exercise analyzers.
- Setup-quality checks and primary-subject tracking.
- IndexedDB history.
- Personal baselines and across-set comparisons.
- Deterministic regression tests.

See `docs/PROJECT_STATE.md` for current implementation status.

## Next priorities

1. Compare outputs with manually annotated real recordings and publish measured error rates.
2. Keep measurements, configured targets, personal baselines, and externally verified findings distinct.
3. Improve Safari/PWA reliability and camera failure handling.
4. Measure robustness across camera views, distances, lighting, and occlusion.
5. Expand exercise coverage only with explicit measurement requirements and tests.

Automated tests and real-recording evidence remain separate gates.
