# FormCoach — Autonomous Agent Contract

This document governs the engineering standards, architectural invariants, and constraints that **ALL AI agents and contributors MUST follow** when modifying the FormCoach codebase.

---

## 1. Non-Negotiable Invariants

1. **Local-First & Zero-Cloud**:
   - NEVER add network requests, backend endpoints, or cloud database SDKs for exercise analysis.
   - NEVER integrate OpenAI, Gemini, Anthropic, or paid cloud vision APIs.
   - Analysis recurring operational cost MUST remain **0 DKK**.
2. **Deterministic Kinematics Before AI**:
   - Biomechanical metrics (angles, ROM, tempo, consistency) MUST be computed mathematically using vector geometry.
   - NEVER use generative AI or probabilistic guessing for core rep counting and angles.
   - NEVER invent or synthesize fake pose coordinates when tracking fails; mark confidence as `INSUFFICIENT`.
3. **Strict Domain Decoupling**:
   - Vision frameworks (`Vision`, `AVFoundation`) MUST NOT contain exercise-specific logic.
   - Exercise Analyzers MUST consume normalized `PoseFrame` domain models.
4. **Zero Compromise on Privacy**:
   - NEVER collect, store, or transmit facial identification vectors or biometric identity profiles.
   - Secondary background persons MUST be discarded.
5. **No Medical Claims**:
   - Form feedback MUST be descriptive and kinematic (e.g. *"Knee flexion angle decreased"*).
   - NEVER claim injury diagnosis, pain causality, or joint safety pathology.
6. **Empirical Proof & Verification**:
   - Code is NOT complete merely because it compiles.
   - All algorithm changes MUST be backed by unit tests and synthetic golden datasets.
   - UI views MUST be visually inspected.
