# FormCoach — System Architecture

## 1. Architectural Philosophy

FormCoach is structured around strict layer decoupling, absolute local execution, and domain-first abstractions.

### Key Rules:
1. **Vision is Decoupled from Biomechanics**: The Vision layer only answers *"Where are the joints?"*. The Exercise Analyzer layer answers *"What does this movement mean?"*.
2. **Deterministic Kinematics**: No LLMs, probabilistic guessing, or generative models for core biomechanics.
3. **Normalized Domain Models**: All pose calculations operate on normalized domain coordinates (`PoseFrame`), independent of raw Apple Vision data structures or sensor orientations.

---

## 2. High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         SwiftUI UI                          │
│   HomeView ── ExerciseSelectionView ── CameraSetupView      │
│   RecordingView ── AnalyzingView ── ResultsView ── History   │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                 WorkoutSessionCoordinator                   │
└──────────────┬──────────────────────────────┬───────────────┘
               │                              │
               ▼                              ▼
┌─────────────────────────────┐  ┌────────────────────────────┐
│        CameraService        │  │     LocalVideoStorage      │
│  (AVFoundation, VideoOutput)│  │ (Sandboxed MP4 & .pose)    │
└──────────────┬──────────────┘  └────────────────────────────┘
               │
               ▼
┌─────────────────────────────┐
│      VisionPoseService      │
│ (2D/3D Body Pose Detection) │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────┐
│                     PoseTimeSeries                          │
│   Confidence Filter ── Gap Interpolation ── PoseSmoother    │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│               ExerciseAnalyzer (e.g. Squat)                 │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ RepSegmenter (State Machine: Standing/Desc/Bottom/Asc)│  │
│  │ AngleCalculator (Vector geometry: ABC joints)         │  │
│  │ ROMAnalyzer, TempoAnalyzer, ConsistencyAnalyzer       │  │
│  │ FormRuleEngine (Explainable Heuristic Rules)          │  │
│  │ ConfidenceEngine (Camera framing & Visibility)        │  │
│  └───────────────────────────────────────────────────────┘  │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                   SwiftData Persistence                     │
│       Workout ── ExerciseSet ── Rep ── SetAnalysis          │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Subsystem Breakdown

### 3.1 Camera & Video Layer (`FormCoachCore/Camera`)
- `CameraService`: Manages `AVCaptureSession`, camera device selection (prefers rear wide camera), orientation calibration, and `AVCaptureVideoDataOutputSampleBufferDelegate`.
- `VideoRecorder`: Encodes H.264/HEVC video to a sandboxed `.mp4` file while capturing frame-accurate PTS (Presentation Time Stamp) references.
- `LocalVideoStorage`: Manages app sandbox directories (`Documents/Sets/` and `Documents/Videos/`), managing local file cleanup and disk space budgets.

### 3.2 Computer Vision Layer (`FormCoachCore/Pose`)
- `VisionPoseService`: Wraps Apple's `VNDetectHumanBodyPoseRequest` (2D) and optional 3D pose requests. Processes raw `CMSampleBuffer` or `CVPixelBuffer` frames.
- `CoordinateNormalizer`: Maps Vision's bottom-left normalized coordinate system to a standard top-left `[0, 1]` domain space, accounting for device orientation and video aspect ratios.
- `PoseSmoother`: Applies an Exponential Moving Average (EMA) and low-pass filter to joint positions without blunting true dynamic movement peaks. Interpolates micro-gaps (<= 3 frames).
- `PoseFrame`: Domain representation containing timestamp and 17 standardized landmarks with 2D `(x, y)`, optional 3D `z`, and confidence `[0, 1]`.

### 3.3 Biomechanics Core (`FormCoachCore/Analysis`)
- `AngleCalculator`: Vector arithmetic (`v1 = A - B`, `v2 = C - B`, `angle = acos((v1 · v2) / (|v1| * |v2|))`) to calculate joint angles in degrees.
- `RepSegmenterProtocol`: Pluggable state machine interface for identifying repetition start, bottom/inflection, and completion timestamps.
- `ConfidenceEngine`: Evaluates whether the required joints for an exercise were tracked with sufficient confidence throughout the set.
- `FormRuleEngine`: Deterministic rules matching observed metrics against configured thresholds to output transparent, non-medical observations.

### 3.4 Persistence Layer (`FormCoachCore/Persistence`)
- **SwiftData**: Stores structured session records (`WorkoutModel`, `ExerciseSetModel`, `RepModel`, `SetAnalysisModel`).
- **Pose File Store**: Saves complete `PoseFrame[]` time-series as compact JSON/binary (`<set_id>.pose.json`) referenced by SwiftData to prevent database bloat.
