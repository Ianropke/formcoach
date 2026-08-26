# FormCoach — Autonomous Agent Contract & Architectural Invariants

This document governs the engineering standards, architectural invariants, and constraints that **ALL AI agents and contributors MUST follow** when modifying the FormCoach codebase.

---

## 1. Absolute Epistemic & Architectural Invariants (Non-Negotiable)

### 1.1 Local-First & Zero-Cloud Inference
- **Canonical Runtime:** Web PWA (React 19 + TypeScript + `@mediapipe/tasks-vision` WASM/WebGL running 100% on-device).
- **Zero Cloud Vision:** Video frames, camera streams, and pose landmarks MUST NEVER leave the user's device.
- **Zero Cost:** Recurring operational cost for vision and kinematic analysis MUST remain **0 DKK**.
- **No Paid AI APIs:** NEVER add network requests, backend endpoints, or cloud SDKs (OpenAI, Gemini, Anthropic) for exercise analysis.

### 1.2 Deterministic Kinematics & Zero Fabricated Data ("Anti-Mocking Rule")
- **Pure Vector Geometry:** Biomechanical metrics (joint angles, ROM, tempo, consistency, bilateral asymmetry $| \theta_L - \theta_R |$) MUST be computed mathematically from observed 3D/2D landmark vectors.
- **Zero Fabricated Tracking:** NEVER synthesize fake coordinates, synthetic timers, or fallback 90+ scores when tracking fails or when no user is in frame.
- **Explicit Insufficient Data State:** If tracking confidence or joint visibility is inadequate, mark status explicitly as `Insufficient Data / Repetitions Not Detected`.

### 1.3 Dynamic Camera Quality Gate Invariant
- **Pre-Flight Framing Check:** The workout recording countdown MUST NEVER start until the `CameraQualityGate` dynamically validates that the athlete is properly positioned in frame:
  - Full-body joint visibility $> 0.65$.
  - Landmark tracking confidence $> 0.65$.
  - Athlete vertical scale within optimal framing bounds ($0.45 \le \text{scale} \le 0.90$).

### 1.4 Strict Domain Decoupling
- **Vision Layer:** `PoseLandmarkerService` MUST be completely decoupled from exercise logic. It emits raw `PoseFrame` streams with normalized timestamps.
- **Analyzer Layer:** Exercise Analyzers (e.g. `SquatAnalyzer`, `BicepCurlAnalyzer`, `ShoulderPressAnalyzer`) consume domain `PoseFrame` models and implement pure state machines.

### 1.5 Zero Privacy & Identity Compromise
- **No Biometric Identification:** NEVER collect, store, or transmit facial identification vectors or biometric identity profiles.
- **Multi-Person Discard:** Secondary background persons in the frame MUST be discarded; only the primary foreground athlete is analyzed.

### 1.6 Descriptive Feedback & No Medical Claims
- **Kinematic Descriptions Only:** Form feedback MUST be descriptive and biomechanical (e.g. *"Knee flexion angle decreased by 12°"* or *"Shoulder drift detected"*).
- **Zero Pathology Claims:** NEVER claim injury diagnosis, pain causality, joint safety pathology, or medical guarantees.

---

## 2. Engineering Quality & Verification Gates

Every code change must pass the following quality gates before submission:
1. **Unit Testing:** `npm test` runs the 13/13 deterministic biomechanics test suite (`src/tests/testSuite.ts`) covering vector geometry, state machines, fatigue detection, and baselines.
2. **Build Validation:** `npm run build` (`tsc -b && vite build`) passes with 0 type errors.
3. **Zero Console Errors:** Automated headless browser inspection must verify 0 console errors, 0 page errors, and valid PWA assets (192x192, 512x512 icons, manifest, service worker).
4. **Discards are Final:** Discarding a recorded set MUST immediately drop memory buffers and never write to persistent baseline storage.
