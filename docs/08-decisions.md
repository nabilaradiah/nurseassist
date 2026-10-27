# 8. Decision log

Why things are the way they are. If you want to reverse one of these, read the reason first and talk to your supervisor.

| Decision | Why | Date |
|---|---|---|
| **Flutter**, one codebase for Android and iOS | The team had one iOS developer with a Mac. Android is the main target | Early 2026 |
| **This repository is Android only. iOS lives in its own repository** | The iOS build is maintained separately by the teammate with the Mac. Keeping it out of here keeps this repo to what the Android team builds and tests. The cost: shared Dart code (`lib/`) exists in both repos, so features and fixes must be copied across | Oct 2026 |
| **Firebase** (Auth, Firestore, Storage, Functions) instead of our own server | No server to run or secure. There's a free tier, and the security rules give role-based access. The comparison is in `NurseAssist_documents/planning/CLOUD_SERVICES_COMPARISON.md` | Feb 2026 |
| **The AI runs fully on the device** (TFLite), no cloud AI | Patient photos never leave the hospital's own Firebase project. It works with poor ward Wi-Fi and costs nothing per prediction | 2026 |
| **EfficientNetB0** rather than a larger model or a ViT | With about 700 images, larger models overfit. The notebook notes EfficientNetV2-S reached only about 40 %. B0 is also small enough for phones | 2026 |
| **The nurse's TIME(S) score sets the recorded type, not the AI** | The AI is a suggestion. The TIME(S) algorithm is the ward's own standard, and keeping the nurse in charge is safer | 2026 |
| **The AI prediction is kept, never overwritten** (`modelPredictedType`) | Comparing model and clinician is the training signal for the next model, and part of the audit trail | 2026 |
| **No fallback guess when the model fails, no default to Type 1** | A silent "Type 1" is the least alarming advice and would hide a fault. The app says the AI is unavailable instead | Oct 2026 |
| **A lecturer approves every image before it is used for training** | Mislabelled images would teach the model the wrong thing. The lecturer is the clinical check | 2026 |
| **Login by Staff ID**, through a `staffLookup` collection | Nurses know their Staff ID, while emails vary. `staffLookup` lets the app turn an ID into an email before login without making the staff list public | Oct 2026 |
| **`roles/{uid}` as a separate collection** | Security rules can only read documents by path, not run queries. A document keyed by uid lets the rules check a role cheaply | 2026 |
| **Audit fields must use server time and the caller's own Staff ID** | So nobody can approve in someone else's name or back-date a decision | Oct 2026 |
| **Deleting photos runs in a Cloud Function** | Storage rules only let the uploader delete their own photo, but a lecturer deleting an assessment must remove its photo too | Oct 2026 |
| **Plain `StatefulWidget`, no state-management package** | The app is small enough. `provider` was in `pubspec.yaml` but never used, so it was removed | Oct 2026 |
| **The local emulator is the default for development and demos** | There's no billing on the original project, and it keeps test data away from anything real | Oct 2026 |
| **Non-code documents kept out of the repo** | They hold reports, budgets and drafts, and some had member details. The repo holds only what's needed to build and run the app. Diagrams and planning notes go with the handover separately | Oct 2026 |
| **The handover is a copy, with a new Firebase project for the next team** | Each cohort owns its own project and billing, and the previous team's data and accounts don't carry over | Oct 2026 |
