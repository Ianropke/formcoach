# FormCoach 🏋️‍♂️

> Native iOS Strength-Training Form Analysis using On-Device Computer Vision & Deterministic Biomechanics.

FormCoach runs 100% on-device on iPhone (optimized for iPhone 17 with iOS 17+). Put the iPhone down at the gym, record a set, and receive evidence-based analysis of repetitions, range of motion, tempo, symmetry, consistency, and observable form — with **0.00 DKK recurring cost** and zero cloud dependencies.

---

## Supported Exercises & Biomechanics

| Exercise | Kinematic Joint Chains | Camera Views | Evaluated Metrics | Explainable Form Rules |
|---|---|---|---|---|
| **Squat** | `Hip -> Knee -> Ankle` | `side`, `45° Front`, `front` | Knee Depth / ROM, Torso Incline, Rep Tempo | Depth decay warning, Incomplete lockout, High consistency |
| **Biceps Curl** | `Shoulder -> Elbow -> Wrist`<br>`Hip -> Shoulder -> Elbow` | `side`, `45° Front`, `front` | Peak Elbow Flexion, Lockout, Shoulder Drift | Shoulder momentum swing ($> 18^\circ$), Strict isolation ($< 10^\circ$) |
| **Shoulder Press** | `Shoulder -> Elbow -> Wrist`<br>`Hip -> Shoulder -> Wrist` | `front`, `45° Front`, `side` | Overhead Lockout ROM, Bilateral Press Symmetry | Bilateral asymmetry ($> 12^\circ$), Incomplete lockout ($< 155^\circ$) |

---

## Key Features

- **100% Local-First & Zero-Cloud**: Zero network requests, zero facial tracking, zero paid LLM/vision APIs.
- **Deterministic Biomechanics**: Vector geometry calculations and 5-state hysteresis state machines.
- **Multi-Set Intelligence (M3)**: Set-by-set progression tracking, depth decay analysis, and Session Fatigue Index ($[0 \dots 100]$).
- **Personal Baselines Engine (M4)**: Individualized empirical distributions ($\mu \pm \sigma$) with statistical cold-start guard ($\ge 3$ sets).
- **Gym-Ready UI**: Glanceable, high-contrast SwiftUI interface designed for noisy gym environments.

---

## Opening & Running in Xcode

### Option 1: Open Swift Package in Xcode
1. In Finder or Terminal, open the project directory:
   ```bash
   open Package.swift
   ```
2. Xcode will open the package natively with targets `FormCoachCore`, `FormCoachUI`, and `FormCoachTests`.
3. Select your iPhone simulator or connected physical iPhone 17 and click **Run** (⌘R) or **Test** (⌘U).

---

## Running Automated CLI Tests

Run all 20 automated unit, geometry, and synthetic golden tests from the command line:

```bash
swiftc -parse-as-library -emit-module -module-name FormCoachCore -target arm64-apple-macosx26.0 -sdk $(xcrun --show-sdk-path) $(find Sources/FormCoachCore -name "*.swift") -emit-library -o libFormCoachCore.dylib && \
swiftc -parse-as-library -emit-module -module-name FormCoachUI -I . -L . -lFormCoachCore -target arm64-apple-macosx26.0 -sdk $(xcrun --show-sdk-path) $(find Sources/FormCoachUI -name "*.swift") -emit-library -o libFormCoachUI.dylib && \
swiftc -parse-as-library -I . -L . -lFormCoachCore -target arm64-apple-macosx26.0 -sdk $(xcrun --show-sdk-path) Tests/FormCoachTests/Fixtures/SyntheticSquatGenerator.swift Tests/FormCoachTests/Fixtures/SyntheticCurlGenerator.swift Tests/FormCoachTests/Fixtures/SyntheticPressGenerator.swift Tests/FormCoachTests/main.swift -o FormCoachTestRunner && \
./FormCoachTestRunner
```

---

## Architecture Documentation

- [`PRODUCT.md`](PRODUCT.md): Product vision and gym user journey.
- [`ARCHITECTURE.md`](ARCHITECTURE.md): System architecture and data flow pipelines.
- [`DATA_MODEL.md`](DATA_MODEL.md): Domain schemas and coordinate standards.
- [`ANALYSIS_ENGINE.md`](ANALYSIS_ENGINE.md): Mathematical formulas and rep state machines.
- [`EXERCISE_ANALYZERS.md`](EXERCISE_ANALYZERS.md): Exercise analyzer contracts.
- [`PRIVACY.md`](PRIVACY.md): Zero-cloud privacy and local storage guarantees.
- [`TESTING.md`](TESTING.md): Multi-tier testing strategy and golden fixtures.
- [`ROADMAP.md`](ROADMAP.md): Milestones M0 through M5 roadmap.
- [`AGENTS.md`](AGENTS.md): Autonomous agent operating contract.
- [`M1_VALIDATION_REPORT.md`](M1_VALIDATION_REPORT.md) through [`M5_VALIDATION_REPORT.md`](M5_VALIDATION_REPORT.md): Milestone sign-offs.
