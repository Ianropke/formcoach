# FormCoach — Exercise Analyzers Specification

## 1. Exercise Analyzer Architecture

All exercise analyzers conform to `ExerciseAnalyzerProtocol`:

```swift
public protocol ExerciseAnalyzerProtocol {
    var exerciseType: ExerciseType { get }
    var requiredJoints: Set<Joint> { get }
    var supportedViews: Set<CameraViewType> { get }
    
    func validateCameraSetup(frame: PoseFrame, view: CameraViewType) -> CameraSetupValidation
    func segmentReps(timeSeries: PoseTimeSeries) -> [Repetition]
    func calculateMetrics(reps: [Repetition], timeSeries: PoseTimeSeries, view: CameraViewType) -> SetAnalysis
}
```

---

## 2. Squat Analyzer (Reference Implementation — M1)

### 2.1 Configuration
- **Primary Joint Chain**: `Hip` $\rightarrow$ `Knee` $\rightarrow$ `Ankle` (Knee Flexion Angle)
- **Secondary Joint Chain**: `Shoulder` $\rightarrow$ `Hip` $\rightarrow$ `Knee` (Hip / Torso Angle)
- **Supported Camera Views**:
  - `side` (Primary: Best for ROM, depth, tempo, torso angle)
  - `front45` (Secondary: ROM + hip lateral shift)
  - `front` (Restricted: Symmetry & knee tracking only; ROM caveat applied)

### 2.2 Required Joints
- `nose` or `head`
- `leftHip`, `rightHip`
- `leftKnee`, `rightKnee`
- `leftAnkle`, `rightAnkle`

### 2.3 Squat Quality Rules
1. **ROM Target**: Valid deep squat reaches knee angle $\le 95^\circ$; parallel squat reaches $95^\circ - 110^\circ$; shallow squat $> 110^\circ$.
2. **Tempo Control**: Controlled eccentric phase $\ge 1.2\text{s}$; explosive or stable concentric phase $0.6 - 2.0\text{s}$.
3. **Torso Incline**: Excessive forward lean detected if torso angle relative to vertical exceeds $45^\circ$ during descent.
4. **Late-Set Fatigue**: Detects $\ge 10\%$ drop in depth comparing early reps vs late reps.

---

## 3. Biceps Curl Analyzer (M2 Architecture Preview)

### 3.1 Configuration
- **Primary Joint Chain**: `Shoulder` $\rightarrow$ `Elbow` $\rightarrow$ `Wrist` (Elbow Flexion Angle)
- **Secondary Joint Chain**: `Hip` $\rightarrow$ `Shoulder` $\rightarrow$ `Elbow` (Shoulder Drift / Swing)
- **Supported Views**: `front`, `side`, `front45`.

### 3.2 Key Biomechanical Rules
1. **Lockout & Peak ROM**: Extension at bottom $\ge 155^\circ$, Peak contraction at top $\le 60^\circ$.
2. **Shoulder Drift / Cheating**: Upper arm angle relative to torso should not deviate by $> 20^\circ$ (penalizes momentum swinging).
