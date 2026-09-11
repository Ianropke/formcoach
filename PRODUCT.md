# FormCoach — Product Specification

FormCoach is an iPhone-first Web PWA for strength-training form analysis. The canonical runtime is the React/TypeScript application in `web/`, using MediaPipe Tasks Vision locally in the browser.

## Core promise

Record a set and receive immediate feedback on observable movement: repetitions, range of motion, tempo, symmetry, consistency, and changes across the set, without sending workout video to a cloud analysis service.

## Product principles

1. Web PWA, iPhone first.
2. Local-first pose estimation and deterministic analysis.
3. No paid AI inference required per workout.
4. No account requirement or facial identification.
5. Core metrics come from landmark geometry, timing, and deterministic state machines.
6. The app reports visible movement and must not infer unmeasured internal states from camera data alone.
7. Measurements, product heuristics, personal baselines, and field-validated claims remain distinguishable.
8. Gym-ready controls and fast, glanceable feedback.

## Coaching semantics

FormCoach separates four kinds of information:

- **Observed measurement** — joint angles, repetition count, timing, asymmetry, consistency.
- **Derived comparison** — change within a set or relative to a personal baseline.
- **Product heuristic/target** — a configured reference used to classify or coach an exercise.
- **Empirically field-validated claim** — reserved for findings supported by real recordings and measured error rates.

A heuristic threshold may trigger feedback, but it must be presented as a product/coaching target rather than a universal biological rule.

Prefer wording such as: `ROM decreased by 11% in the final repetitions; the cause cannot be determined from pose data alone.`

## Current exercise scope

The PWA currently implements biceps curl, triceps pushdown, squat, leg press, and shoulder press. Implementation support is not the same as field validation. Current evidence state is tracked in `docs/PROJECT_STATE.md`.

## Product success criteria

FormCoach should help answer:

- Did it detect the repetitions actually performed?
- What ROM, tempo, symmetry, and consistency did the camera capture?
- Did those measurements change within the set or across recent sets?
- Was signal quality adequate for the displayed measurement?
- Which feedback is directly measured, which is heuristic, and which remains unvalidated in real-world conditions?
