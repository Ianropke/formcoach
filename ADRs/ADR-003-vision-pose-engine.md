# ADR-003: Apple Vision Pose Engine with Domain Normalization

## Status
Accepted

## Context
Apple Vision provides hardware-accelerated 2D and 3D body pose detection on Apple Silicon Neural Engine / GPU. However, coupling domain logic directly to `VNRecognizedPoint` or Vision coordinate systems creates brittle code.

## Decision
We wrap Apple Vision behind a `PoseServiceProtocol` and normalize all outputs into standard `PoseFrame` domain objects with a top-left `[0, 1]` coordinate space.

## Consequences
- **Pros**: Hardware acceleration, zero external dependency, testable biomechanics without Vision mocks.
- **Cons**: Requires custom coordinate normalization handling device orientations.
