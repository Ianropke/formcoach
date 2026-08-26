# FormCoach — Data Model & Schema Specification

## 1. Domain Entities & Schemas

The FormCoach data model is split into **Relational Session Metadata** (managed via SwiftData) and **High-Frequency Time-Series Storage** (managed via sandboxed JSON files).

---

## 2. High-Frequency Pose Schema (`.pose.json`)

Stored in `Documents/Sets/<set_id>.pose.json`.

```json
{
  "version": 1,
  "setId": "F7B4E2B1-4A82-4F1E-9C3D-123456789ABC",
  "fps": 30.0,
  "duration": 24.5,
  "frames": [
    {
      "timestamp": 0.0333,
      "confidence": 0.96,
      "joints": {
        "nose": {"x": 0.52, "y": 0.15, "z": 0.0, "confidence": 0.98},
        "leftShoulder": {"x": 0.46, "y": 0.28, "z": 0.05, "confidence": 0.95},
        "rightShoulder": {"x": 0.58, "y": 0.28, "z": -0.05, "confidence": 0.95},
        "leftElbow": {"x": 0.43, "y": 0.40, "z": 0.08, "confidence": 0.91},
        "rightElbow": {"x": 0.61, "y": 0.40, "z": -0.08, "confidence": 0.92},
        "leftWrist": {"x": 0.45, "y": 0.35, "z": 0.12, "confidence": 0.89},
        "rightWrist": {"x": 0.59, "y": 0.35, "z": -0.12, "confidence": 0.90},
        "leftHip": {"x": 0.47, "y": 0.52, "z": 0.02, "confidence": 0.97},
        "rightHip": {"x": 0.55, "y": 0.52, "z": -0.02, "confidence": 0.96},
        "leftKnee": {"x": 0.45, "y": 0.72, "z": 0.04, "confidence": 0.96},
        "rightKnee": {"x": 0.57, "y": 0.72, "z": -0.04, "confidence": 0.95},
        "leftAnkle": {"x": 0.44, "y": 0.92, "z": 0.01, "confidence": 0.94},
        "rightAnkle": {"x": 0.58, "y": 0.92, "z": -0.01, "confidence": 0.93}
      }
    }
  ]
}
```

---

## 3. SwiftData Schema

### 3.1 `WorkoutModel`
- `id: UUID` (Primary Key)
- `startedAt: Date`
- `endedAt: Date?`
- `notes: String?`
- `@Relationship(deleteRule: .cascade) var sets: [ExerciseSetModel]`

### 3.2 `ExerciseSetModel`
- `id: UUID` (Primary Key)
- `exerciseTypeRaw: String` (e.g. `"squat"`, `"bicepsCurl"`)
- `cameraViewRaw: String` (e.g. `"side"`, `"front"`, `"front45"`)
- `recordedAt: Date`
- `videoPath: String?` (Relative sandbox path to `.mp4`)
- `poseDataPath: String?` (Relative sandbox path to `.pose.json`)
- `repCount: Int`
- `trackingConfidence: Double` (0.0 to 1.0)
- `analyzerVersion: Int`
- `ruleVersion: Int`
- `@Relationship(deleteRule: .cascade) var reps: [RepModel]`
- `@Relationship(deleteRule: .cascade) var analysis: SetAnalysisModel?`

### 3.3 `RepModel`
- `id: UUID`
- `index: Int` (1-indexed repetition order)
- `startTime: Double` (seconds from set start)
- `inflectionTime: Double` (bottom or peak apex timestamp)
- `endTime: Double` (seconds from set start)
- `duration: Double` (seconds)
- `eccentricDuration: Double`
- `concentricDuration: Double`
- `pauseDuration: Double`
- `primaryROM: Double` (e.g. peak knee flexion in degrees)
- `secondaryROM: Double?` (e.g. hip angle in degrees)
- `torsoAngleMean: Double?`
- `confidence: Double` (0.0 to 1.0)
- `isComplete: Bool`

### 3.4 `SetAnalysisModel`
- `id: UUID`
- `overallQualityScore: Double` (0 to 100 heuristic index)
- `romScore: Double`
- `consistencyScore: Double`
- `tempoScore: Double`
- `symmetryScore: Double?`
- `primaryObservation: String`
- `observationsData: Data` (JSON array of `FormObservation`)
- `warningsData: Data` (JSON array of `TrackingWarning`)

---

## 4. Coordinate System Standard

- **Origin `(0.0, 0.0)`**: Top-Left of the camera frame.
- **Range `x`**: `[0.0, 1.0]` from left to right.
- **Range `y`**: `[0.0, 1.0]` from top to bottom.
- **Range `z`**: Optional depth relative to hip centroid (positive = closer to camera).
- **Transformation Pipeline**: Vision normalized points (bottom-left) $\rightarrow$ Invert Y-axis $\rightarrow$ Adjust for Device Orientation $\rightarrow$ Scaled Domain Coordinates.
