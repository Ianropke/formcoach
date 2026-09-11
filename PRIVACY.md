# FormCoach — Privacy Architecture

The canonical runtime is the Web PWA in `web/`.

Exercise analysis runs in the browser. Structured workout history is stored locally through IndexedDB in `web/src/core/storage.ts`. Temporary replay video uses browser Blob/Object URLs and is not included in durable set records.

The PWA can be hosted and downloaded like a normal web application; that hosting layer is separate from the local exercise-analysis pipeline.

Older references to SwiftData, native iOS storage, or Apple Vision describe the historical implementation rather than the current PWA.
