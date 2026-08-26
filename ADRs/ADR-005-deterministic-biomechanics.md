# ADR-005: Deterministic Biomechanics Over Generative AI

## Status
Accepted

## Context
Generative AI models and LLMs are non-deterministic, prone to hallucination, opaque in their reasoning, computationally expensive, and lack precise frame-level kinematic guarantees.

## Decision
All rep segmentation, joint angles, tempo, consistency, and rule evaluations are computed deterministically using standard vector mathematics, state machines with hysteresis, and explainable rule engines.

## Consequences
- **Pros**: 100% reproducible results, transparent evidence linked to exact frame timestamps, zero hallucinations, instant sub-second execution.
- **Cons**: Requires explicit calibration of biomechanical thresholds per exercise.
