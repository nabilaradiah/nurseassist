# 2. Architecture

## The big picture

```
 Android phone                                      Firebase project
┌──────────────────────────────────┐            ┌───────────────────────────────┐
│ Flutter app                      │            │ Authentication (email/pass)   │
│  screens/  ──►  services/  ──────┼── HTTPS ──►│ Cloud Firestore  (records)    │
│                  │               │            │ Cloud Storage    (photos)     │
│                  ▼               │            │ Cloud Functions  (2 triggers) │
│  On-device AI (no network):      │            └───────────────────────────────┘
│   ML Kit selfie segmentation     │
│   TFLite EfficientNetB0 (8 types)│
└──────────────────────────────────┘
```

* **No server of our own.** The app talks straight to Firebase. Access control is entirely in `firestore.rules` and `storage.rules`, so treat those files as the backend.
* **AI runs on the phone.** Photos are never sent to a cloud AI service. They are only uploaded to the project's own Storage bucket.
* **State management** is plain `StatefulWidget` + `setState`. There is no Provider, Riverpod or BLoC. Each screen loads what it needs through a service.

## Code layout

```
lib/
  main.dart            Firebase start-up, emulator switch, MaterialApp
  theme.dart           Colours (kPrimary, kWarning, ...), text styles, shared snackbars
  models/              Plain Dart classes with toJson/fromJson
    patient.dart              Patient + allergies/"no known allergies" detection
    staff.dart                Staff profile and role helpers (isLecturer, isAdmin)
    wound_assessment.dart     Assessment, TIME(S) assessment and scoring, AI result
    wound_types_database.dart Types 1–8: severity, characteristics, management plan
    vital_reading.dart        One dated set of vital signs + normal ranges
    chronic_condition*.dart   Chronic conditions list
  services/
    auth_service.dart         Login by Staff ID, registration, password reset (singleton)
    firestore_service.dart    Every Firestore/Storage read and write
    wound_analysis_service.dart  Runs skin check + TFLite model, builds the AI result
    skin_detection_service.dart  ML Kit selfie segmentation "is there skin?" gate
    ai_config.dart            Model path, input size, thresholds, on/off switches
  screens/             One file per screen (below)
  widgets/             Shared pieces: vital signs card/form, load-error view, avatar, ...
test/                  Unit and widget tests; helpers/fake_firestore_service.dart
functions/index.js     The two Cloud Functions
tools/                 Emulator scripts, rules tests, one-off migration
ml/                    Training notebook for the shipped model
android/               Android project (the only platform in this repository)
```

Conventions worth keeping:

* **Screens never call Firebase directly.** They go through `FirestoreService` or `AuthService`, which keeps the queries in one place and lets tests swap in `FakeFirestoreService`.
* **Reads throw on failure** and screens show `LoadErrorView` with a retry. A failed read must never look like an empty list.
* **Multi-document writes use one batch**, so they all happen or none do (e.g. a new assessment and the patient's list of assessment IDs).
* **Who and when fields** (`correctedBy`/`correctedAt`, `approvedBy`/`approvedAt`, ...) use `FieldValue.serverTimestamp()`. The rules reject client clocks and other people's IDs.

## Screens and navigation

```
SplashScreen ──► LoginScreen ──► DashboardScreen
                    │               ├─► PatientListScreen ──► PatientProfileScreen
                    │               ├─► AddEditPatientScreen          │
                    │               ├─► LecturerApprovalScreen (lecturer/admin)
                    │               └─► NurseFeedbackScreen (nurse) ──┘
                    └─► UserRegistrationScreen
PatientProfileScreen ├─► AddEditPatientScreen (edit)
                     ├─► CaptureWoundScreen ──► AnalysisResultsScreen
                     └─► AnalysisResultsScreen (open a past assessment)
```

| Screen | What it does |
|---|---|
| Splash | Animated logo, then Login. There is no auto-login |
| Login | Staff ID + password, "forgot password", link to registration |
| User registration | Self-registration as a **nurse** (Staff ID, name, department, email, password) and sends the verification email |
| Dashboard | Greeting and role badge, patient counts and recent patients. Lecturers get the approval queue. Nurses get a badge for lecturer feedback |
| Patient list | Search and list patients, add a patient |
| Add/edit patient | Demographics, MRN, allergies, medications, chronic conditions, emergency contact |
| Patient profile | Details, vital-signs history, wound assessment history, start a new capture |
| Capture wound | Camera or gallery → privacy checklist → AI analysis → upload photo → create the assessment |
| Analysis results | The biggest screen (≈3,400 lines): AI result and confidence, TIME(S) form, nurse-vs-AI comparison, management plan with allergy warnings, vitals, specialist confirmation, notes |
| Lecturer approval | Queue of nurse-verified assessments, disagreements first. Approve, reject (with feedback), or reassign the type |
| Nurse feedback | The nurse's assessments that a lecturer reassigned or commented on |

## Main flows

### A nurse assesses a wound

1. Patient profile → **Capture New Wound**.
2. The nurse takes or picks a photo and ticks the privacy checklist: no names, wristbands or paperwork in the frame.
3. `WoundAnalysisService.analyzeWound` runs on the phone. First the skin gate (reject if under 4 % skin pixels), then the TFLite model, then the "no wound" guard (reject if top confidence is under 35 %). See [ML model](04-ml-model.md).
   * If the model can't run, the nurse continues without an AI result and the TIME(S) assessment sets the type. The app never guesses.
4. The photo is uploaded to `wound_images/{uid}/...` and a `woundAssessments` document is created, with the AI prediction stored separately in `modelPredictedType`/`modelConfidence`.
5. **Analysis results**: the nurse records the TIME(S) assessment. Its score *is* the wound type (see [Clinical content](05-clinical-content.md)). Saving it sets `clinicianCorrectedType`, which puts the assessment in the lecturer's queue.
6. The nurse records vitals, and for Types 3, 4 and 6 confirms a specialist was notified.

### A lecturer reviews it

1. Dashboard → **Approval queue**. It lists assessments with a `clinicianCorrectedType` that are neither approved nor rejected. Ones where the nurse and AI disagree come first.
2. **Approve** sets `approvedForTraining`. The `copyApprovedWoundImage` Cloud Function then copies the photo to `training-data/approved/type_N/`.
3. **Reject** needs feedback. Either action can **reassign** the type (`supervisorCorrectedType`) and leave feedback, which shows up on the nurse's dashboard.

Which type the app displays: supervisor reassignment, then the nurse's TIME(S) type, then the AI (`WoundAssessment.displayWoundType`).

## Roles

| Role | Can |
|---|---|
| `nurse` | Everything clinical: patients, vitals, captures, TIME(S). Can't delete, approve or reject |
| `lecturer` (or `supervisor`) | Nurse rights, plus the approval queue, deleting patients and assessments, and editing staff profiles |
| `admin` | Lecturer rights, plus changing roles and deleting staff lookups |

`supervisor` and `lecturer` are treated the same. `supervisor` is the older name, still accepted. There is no admin screen in the app. Admin tasks (promoting users, disabling accounts) are done in the Firebase console, see [Operations](06-operations.md#user-accounts-and-roles).

## Tests

| File | Covers |
|---|---|
| `test/time_assessment_test.dart` | TIME(S) scoring → wound type, and nurse-vs-AI differences |
| `test/models/wound_types_database_test.dart` | All 8 types have complete data, specialist flags, no silent fallback |
| `test/models/*`, `test/vital_reading_test.dart` | Model parsing, dates, allergies, vital-sign ranges |
| `test/screens_test.dart` | Key screens render and behave with `FakeFirestoreService` |
| `tools/rules-tests/` | Security rules (run with `npm run test:rules`) |

There are no integration tests that run the camera or the TFLite model. Check those by hand on a device.
