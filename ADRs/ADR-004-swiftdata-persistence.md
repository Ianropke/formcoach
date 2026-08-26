# ADR-004: SwiftData Metadata & Sandboxed File Storage Split

## Status
Accepted

## Context
A 45-second set recorded at 30 FPS generates 1,350 `PoseFrame`s with 17 joints each (~23,000 coordinate tuples). Storing individual high-frequency frame models in a relational database causes bloat, slow queries, and high memory overhead.

## Decision
Split data persistence into:
1. **SwiftData**: Relational records (`Workout`, `ExerciseSet`, `Rep`, `SetAnalysis`).
2. **Local Sandboxed File Storage**: Raw/normalized pose time-series stored in compressed JSON (`<set_id>.pose.json`) and `.mp4` video files.

## Consequences
- **Pros**: Lightning-fast database queries, lightweight schema migrations, scalable time-series storage.
- **Cons**: Requires explicit cascade deletion to keep filesystem and database synchronized.
