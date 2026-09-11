# FormCoach — Data Model

Current source of truth: `web/src/core/models.ts`.

- `PoseFrame`: timestamp, joints, optional world joints, aspect ratio, confidence.
- `Repetition`: timing, ROM, optional secondary measurement, confidence.
- `SetAnalysis`: summary measurements and observations.
- `RecordedSet`: exercise, view, date, repetitions and analysis.

Structured history is stored in IndexedDB by `web/src/core/storage.ts`. Temporary replay URLs are not part of durable history.

The previous SwiftData schema is historical and is not canonical for the Web PWA.
