# FormCoach — Product & Engineering Roadmap

## Milestone Overview

```
M0: Technical Foundation (Done)
 └── M1: Squat Biomechanics Engine (Active Focus)
      └── M2: Generalize Analyzer & Biceps Curl
           └── M3: Multi-Set Intelligence & Degradation Trends
                └── M4: Longitudinal History & Personal Baseline
                     └── M5: Catalog Expansion & Core ML Augmentation
```

---

## Milestone Details

### M0 — Technical Foundation
- Native Swift Package & Xcode structure
- AVFoundation CameraService & VideoRecorder
- Apple Vision Pose extraction & coordinate normalization
- Pose smoothing & gap interpolation
- SwiftData models & local file persistence
- Comprehensive testing harness

### M1 — Squat Biomechanics & Analysis (Reference Implementation)
- Squat-specific camera framing guide
- Deterministic 5-state Squat rep segmenter
- Kinematic metrics: Knee ROM, Rep Tempo, Torso incline, Consistency score
- Early vs Late set fatigue / ROM degradation detection
- Results screen with synchronized video + skeleton replay
- Scrubbable repetition timeline

### M2 — Generalize Architecture & Biceps Curl
- Prove `ExerciseAnalyzerProtocol` modularity on upper-body mechanics
- Biceps curl segmenter & elbow ROM metrics
- Shoulder swing / momentum cheat detection

### M3 — Multi-Set Intelligence
- Workout session aggregation (e.g. Set 1 vs Set 2 vs Set 3)
- Multi-set fatigue trajectory analysis

### M4 — Longitudinal History & Personal Baselines
- Long-term movement consistency trends over weeks/months
- Personalized baselines instead of arbitrary population norms

### M5 — Catalog Expansion & Optional Core ML
- Shoulder Press, Romanian Deadlift, Lunge
- Learned movement quality embeddings (if high-quality labeled datasets exist)
