# FormCoach — Testing Strategy & Golden Fixtures

## 1. Multi-Tier Testing Strategy

Because biomechanical calculations must be mathematically reproducible, FormCoach employs a 3-tier testing strategy:

```
┌─────────────────────────────────────────────────────────────┐
│                 Tier 1: Unit & Vector Math                  │
│       AngleCalculator, Coordinate Transforms, Filters       │
├─────────────────────────────────────────────────────────────┤
│                 Tier 2: Synthetic Golden Fixtures           │
│   Clean 10-Rep Squats, Paused Squats, Degradation Series    │
├─────────────────────────────────────────────────────────────┤
│                 Tier 3: Real-Device Gym Validation          │
│       Physical iPhone 17 Camera, Latency, Occlusion         │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Unit Testing Suite

1. **`AngleCalculatorTests`**:
   - Orthogonal 90° angle (`(0, 1) -> (0, 0) -> (1, 0)`)
   - Straight line 180° angle (`(-1, 0) -> (0, 0) -> (1, 0)`)
   - Acute 45° angle
   - 3D Vector angle with z-depth variation
2. **`PoseSmootherTests`**:
   - Noise dampening without shifting peak local minima
   - Short-gap linear interpolation (1-3 missing frames)
3. **`SquatRepSegmenterTests`**:
   - Deterministic 5-state transitions
   - Rejection of sub-threshold micro-movements (< 35° ROM)
   - Rejection of ultra-fast artifacts (< 0.8s cycle)

---

## 3. Golden Synthetic Dataset Fixtures

Version-controlled synthetic time-series data ensuring deterministic regression coverage:

| Fixture Name | Description | Expected Output |
|---|---|---|
| `squat_clean_10_reps.json` | 10 perfect sinusoidal squats (3.0s tempo, 85° bottom) | `reps: 10`, `consistency: >90`, `degradation: false` |
| `squat_fatigue_degradation.json` | 12 squats where reps 9-12 have 15% shallower knee angle | `reps: 12`, `degradation: true`, observation triggered |
| `squat_occluded_frames.json` | 10 squats with 4-frame tracking dropouts | `reps: 10`, `gap_interpolated: true` |
| `squat_incomplete_final_rep.json` | 8 full reps + 1 aborted descent | `reps: 8`, incomplete rep discarded |

---

## 4. Real-Device Validation Checklist (iPhone 17)

- [ ] Camera preview 60 FPS in portrait orientation
- [ ] Framing setup guide responds dynamically to athlete distance
- [ ] 3-second countdown renders with clear visual feedback
- [ ] Post-set analysis completes in $< 2.0$ seconds for a 45-second recording
- [ ] Memory footprint remains $< 150\text{ MB}$ across 5 consecutive sets
- [ ] Zero thermal throttling warnings during a standard session
