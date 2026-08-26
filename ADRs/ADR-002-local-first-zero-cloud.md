# ADR-002: Local-First Zero-Cloud Execution

## Status
Accepted

## Context
Commercial gym environments (like PureGym) often suffer from spotty cellular/Wi-Fi connectivity. Cloud video inference entails latency (5-20s upload times), privacy concerns around recording in public gyms, and recurring server costs.

## Decision
All video capture, pose estimation, rep segmentation, and metric generation occur 100% locally on the device with zero network calls and 0 DKK recurring cost.

## Consequences
- **Pros**: Instant analysis (< 1.5s post-set), absolute user privacy, zero operating cost, works offline.
- **Cons**: Constrained to on-device computational budget (optimized via throttled frame rate and native Vision processing).
