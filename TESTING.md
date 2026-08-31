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

## Web regression coverage — functional review (2026-08-31)

The canonical web runtime is tested from `web` with `npm test` and `npm run build`.
`src/tests/reviewRegression.test.tsx` covers the complete 3D smoothing/segmentation
path, aspect-correct 2D fallback, missing secondary measurements, extension-exercise
trends, insufficient baseline display, actual zoom settings, and IndexedDB history
beyond 50 sets including migration of the legacy localStorage cache. Storage tests
use fake-indexeddb; component checks render actual React components to HTML.

History writes are acknowledged only after the IndexedDB transaction commits.
The app keeps the result screen open on a failed save. Temporary video URLs are
never persisted. Legacy localStorage data is retained until migration commits.

The change index is a heuristic comparison of angle and duration across sets of
the same exercise, not a physiological fatigue measurement. A single set or mixed
exercises yields no index. Baseline dispersion is observed rather than floored;
UI baseline claims require at least 3 sets and 25 reps.

Camera zoom controls reflect track capabilities and observed settings; there is
no promise that Safari exposes an ultra-wide lens. Real iPhone/Safari capture,
AirPods, camera angles, video timing, thermal behavior and offline restart still
require field testing. Passing synthetic and DOM tests is not empirical proof.

A mounted jsdom/React test exercises the actual save buttons: duplicate clicks
make one write, rejection leaves the result available, and retry reaches summary.
When IndexedDB cannot open, the legacy cache remains readable, but is explicitly
marked incomplete: baseline screens hide their claims and provide a retry.
