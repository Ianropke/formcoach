# FormCoach — Privacy Architecture & Security Guarantees

## 1. Zero Cloud Architecture

FormCoach is architected around **100% on-device local execution**.

- **No Remote Servers**: No API endpoints, no cloud databases (no Supabase, Firebase, AWS, GCP, etc.).
- **No Third-Party Analytics**: Zero SDKs that track user sessions, IP addresses, or behavior.
- **No Video Uploads**: Video files recorded during workout sessions never leave the local iOS application sandbox (`/Library/Application Support/` & `Documents/`).
- **No AI Model Telemetry**: All computer vision inference uses Apple Vision on the local Neural Engine / GPU.

---

## 2. Biometric Privacy by Design

- **No Facial Recognition**: The application tracks skeletal landmarks (joints) purely as anonymous spatial coordinates. No facial identification embeddings or facial meshes are stored.
- **Primary Subject Isolation**: In gym environments with multiple visible persons, the system isolates the primary athlete's bounding box and discards secondary person pose data.
- **No Identity Profiles**: Stored workouts are referenced by UUID and local timestamp only; no user accounts or personal profiles are created.

---

## 3. Data Lifecycle & User Control

Users have complete physical control over their recorded videos and analysis history:

1. **Storage Settings**:
   - Keep Videos Forever (default in M1)
   - Auto-delete after 30 days
   - Auto-delete after 7 days
   - Keep Analysis, Delete Video immediately after processing
2. **Cascade Deletion**: Tapping "Delete Set" or "Delete All Data" physically deletes both the SwiftData database records and the corresponding `.mp4` and `.pose.json` sandbox files from the iPhone's filesystem.

---

## 4. Legal & Medical Disclaimer

FormCoach provides kinematic analysis of visible human movement for physical fitness purposes. It is **not a medical device** and does not diagnose, treat, or prevent injuries, musculoskeletal pathology, or pain.
