# FormCoach — repository contract

FormCoach is a local-first strength-training form coach. The canonical runtime is the Web PWA in `web/`: React + TypeScript + MediaPipe Tasks Vision running on-device in the browser. The older Swift/SwiftUI implementation and milestone reports are historical unless a task explicitly targets them.

This file is a concise contract and router. Load deeper context only when the active task needs it.

## Context routing

- Product scope and user experience → `PRODUCT.md`.
- Current architecture and data flow → `ARCHITECTURE.md`.
- Pose/analysis math → `ANALYSIS_ENGINE.md` and the affected code under `web/src/core/`.
- Exercise-specific rules → `EXERCISE_ANALYZERS.md` plus the relevant analyzer implementation/tests.
- Privacy/local-storage behavior → `PRIVACY.md`, `web/src/core/storage.ts`, and `web/src/vision/`.
- Current implementation and evidence state → `docs/PROJECT_STATE.md`.
- Future direction → `ROADMAP.md`.
- Historical native-iOS milestone evidence → `docs/archive/native-ios/`.

Do not read every document before every edit. Inspect the implementation and tests for the affected surface.

## Durable invariants

### Local-first privacy and cost

- Camera frames, recorded workout video, and pose landmarks must not be uploaded for exercise analysis.
- Do not add paid/cloud AI inference to the core exercise-analysis path without an explicit owner decision.
- Do not add facial identification, biometric identity profiles, or user tracking.
- Preserve explicit cleanup of temporary video Object URLs and local-history integrity.

### Measurement before interpretation

FormCoach observes visible movement kinematics; it does not observe internal tissue load, pain, injury state, muscle activation, intent, exertion, or the cause of a movement change.

- Compute angles, ROM, timing, asymmetry, consistency, and other metrics from observed landmarks.
- Never fabricate landmarks, repetitions, scores, baselines, or fallback measurements when tracking is inadequate.
- Use an explicit insufficient-data state when the required signal is not present.
- Keep causal claims out of feedback unless the cause is directly measured. Prefer `ROM decreased late in the set` over `fatigue caused ROM loss`.
- Do not turn heuristic thresholds into universal medical, safety, or physiological claims.
- Personal/reference targets may be used when clearly labelled as product/coaching targets rather than biological truths.

### Evidence levels

Keep these separate:

1. **Code correctness** — typecheck/lint/build and deterministic tests.
2. **Algorithmic validation** — synthetic fixtures/regression tests show that math and state machines behave as specified on controlled inputs.
3. **Empirical field validation** — real people, real iPhone/Safari camera conditions, annotated ground truth, and measured error rates.

Tier 1–2 evidence must not be described as proving real-world accuracy, reliability, safety, or clinical validity. Exercise support in code is not the same as empirical field validation.

### Deterministic domain separation

- Pose estimation emits pose data; exercise analyzers interpret it.
- Keep exercise state machines and scoring deterministic and testable.
- Preserve primary-athlete selection and discard secondary-person pose data from analysis.
- Camera/setup heuristics are quality proxies, not physical sensor measurements unless backed by an actual sensor/reference.

### Medical boundary

Feedback may describe visible movement and compare it with a configured/personal target. It must not diagnose injury, explain pain causality, claim that a movement is medically safe/unsafe, or imply that a specific joint angle guarantees muscle activation or injury prevention.

## Working loop

Within the requested scope, inspect relevant files, implement, run focused checks, fix failures caused by the change, and rerun affected checks without asking for approval at each reversible step.

Use additional agents/review only when they add concrete value such as independent high-risk review, bounded parallel exploration, or context isolation. Neither a single-builder rule nor a swarm is mandatory.

Stop for a genuine owner decision or protected boundary: privacy regression, external transmission of workout data, paid-resource expansion, destructive/irreversible data changes, production-impacting changes, or a material unresolved product/architecture decision.

## Verification

Select checks by the affected surface. Common commands:

- `npm run test`
- `npm run build`
- `cd web && npm run lint`

Use focused tests during iteration and broader checks at meaningful boundaries. Do not claim a check passed unless it ran.

For coaching/biomechanics changes, verify both the numeric output and the wording: measured data must remain distinguishable from inference or interpretation.

## Completion

Do not stop at the first plausible implementation. Continue until the requested behavior exists, relevant checks pass, failures caused by the change are resolved, documentation matches the canonical PWA, and any remaining blocker genuinely requires field evidence, a human decision, or an unavailable capability.
