# FormCoach — Autonomous Agent Contract & Architectural Invariants

This document governs the engineering standards, architectural invariants, and constraints that **ALL AI agents and contributors MUST follow** when modifying the FormCoach codebase.

## 0. Working Mode

Default to `ONE BUILDER → IMPLEMENT → TARGETED TEST → RELEVANT BUILD/SUITE → STOP`. Use minimal reads and no subagent/full-repository review by default. Changes to pose analysis, privacy, storage, camera gating, or release behavior are high risk and receive deeper validation plus a separate skeptical gate. Stop when acceptance criteria and relevant checks pass.

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

Select gates by the changed surface. During development run the narrowest relevant test; at completion run the relevant build/suite. Run every gate only for broad changes, release work, or when the affected contract requires it:
1. **Unit & Mathematical Regression Testing:** `npm test` runs the deterministic biomechanics test suite (`src/tests/testSuite.ts` & `src/tests/goldenDataset.ts`) covering vector geometry, state machines, fatigue detection, and baselines on synthetic frames.
2. **Build Validation:** `npm run build` (`tsc -b && vite build`) passes with 0 type errors.
3. **Zero Console Errors:** Automated headless browser inspection must verify 0 console errors, 0 page errors, and valid PWA assets (192x192, 512x512 icons, manifest, service worker).
4. **Discards are Final:** Discarding a recorded set MUST immediately drop memory buffers and never write to persistent baseline storage.

---

## 3. Epistemic Hierarchy & "Builder vs. Skeptic" Governance

All contributors and AI agents must strictly adhere to the 3-Tier Evidence Hierarchy:

```
[Tier 1: Kodekorrekthed]
  ↳ Typecheck (tsc), Lint, Clean Builds, Zero Console Errors
      ↓
[Tier 2: Algoritmisk Validering]
  ↳ Syntetiske regressionstests (testSuite & synthetic benchmarks)
  ↳ Beviser at matematikken & state-machinen virker på perfekte data
      ↓
[Tier 3: Empirisk Feltvalidering]
  ↳ Reel person foran iPhone-kamera i fitnesscenter (støj, lys, vinkler, occlusion)
  ↳ Målt mod menneskelig ground-truth (MAE på reps, Sensitivity/Specificity på fejl)
```

### 3.1 The Builder vs. Skeptic Rule
- **Agent Role (Builder):** The agent builds, refactors, secures, and runs Tier 1 & Tier 2 checks.
- **Separate Gate:** Skeptical review and Tier 3 field validation happen after a coherent builder result when risk or acceptance requires them; they are not repeated inside the builder loop.
- **Language Prohibition:** Agents are **STRICTLY PROHIBITED** from using phrases such as *"validated"*, *"production-ready"*, *"works reliably in real life"*, or *"ingen kode-genveje tilbage"* solely on the basis of Tier 1 & Tier 2 tests.
- **Permitted Phrasing:** Agents MUST state precisely what was tested: e.g. *"17/17 deterministic regression tests pass on synthetic vector inputs. Real-world vision accuracy remains unvalidated pending Tier 3 field testing."*

### 3.2 Canonical PureGym Field Test Protocol (Tier 3 Baseline)
When field-testing in reality, execute these 6 standardized recording sets:

| Test Set | Physical Execution | Expected FormCoach Behavior |
|---|---|---|
| **1. Strict Curls** | 10 clean, controlled bicep curls | 9–10 reps, peak drift $< 10^\circ$, positive isolation observation |
| **2. Cheat Curls** | 10 curls with deliberate torso/shoulder swing | 9–10 reps, peak drift $\ge 15^\circ$, `Shoulder Momentum Swing Detected` warning |
| **3. Incomplete ROM Curls** | 10 half-reps (stopping at 90°) | Rep count tracked + shallow flexion score / observation |
| **4. Parallel Squats** | 10 deep squats to parallel ($\le 88^\circ$) | 9–10 reps, parallel depth observation |
| **5. Shallow Squats** | 10 deliberately high squats ($> 105^\circ$) | Shallow depth warning triggered (distinct from Test 4) |
| **6. Adverse Camera Setup** | Standing too close ($<1\text{m}$) or partially obscured | `CameraQualityGate` strictly blocks recording countdown |

Field metrics must report:
- **Rep Count Mean Absolute Error:** $\text{MAE} = \frac{1}{n}\sum |\text{FormCoach reps} - \text{actual reps}|$
- **Flaw Detection Sensitivity & Specificity** relative to self-annotated ground truth.
