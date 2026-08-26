# ADR-001: Native SwiftUI Architecture

## Status
Accepted

## Context
FormCoach requires 60 FPS real-time skeleton rendering, low-latency video recording, high-contrast visual status displays in noisy gyms, and tight integration with Apple's AVFoundation and Vision frameworks.

## Decision
We choose native Swift and SwiftUI as the sole UI framework.

## Consequences
- **Pros**: Direct zero-overhead interoperability with AVFoundation, Vision, and SwiftData; native look, feel, and performance on iPhone 17; zero third-party UI framework dependencies.
- **Cons**: iOS-only (which aligns perfectly with the iPhone-first product principle).
