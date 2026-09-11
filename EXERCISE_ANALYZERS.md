# FormCoach — Exercise Analyzers

Current source of truth: `web/src/core/analyzers/exerciseAnalyzers.ts` and its tests.

Implemented analyzers: biceps curl, triceps pushdown, squat, leg press, and shoulder press.

Each analyzer consumes pose frames, segments repetitions, calculates movement measurements, and produces a set analysis.

Configured angle and drift thresholds are product rules used for repeatable feedback and tests. Real-recording accuracy is a separate evidence question.

User-facing text should describe measured movement and comparisons. Avoid stating an unmeasured cause for a change in ROM, tempo, or symmetry.

Keep exact thresholds in code/tests rather than duplicating them here.
