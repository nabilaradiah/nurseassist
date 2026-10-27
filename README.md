# NurseAssist – Mobile Wound Management Assistant

NurseAssist helps nurses assess wounds at the bedside. A nurse photographs a wound, an on-device AI model suggests the wound type, the nurse confirms it with a structured TIME(S) assessment, and the app shows the matching management plan from the Wound Care Quick Reference. Lecturers review the confirmed images before they are used to retrain the model.

Built as a Final Year Project with Flutter and Firebase. **This repository is the Android app.** The iOS version is kept in a separate repository.

> **Taking over this project?** Start with the [handover docs](docs/README.md): setup, architecture, data and security, the ML model, clinical content, operations, known issues and the decision log.

---

## Background

Nurses handle many patients a day, and wound management needs careful assessment and consistent monitoring. In busy wards, manual documentation and delayed assessments reduce care quality. Common problems:

* Identifying the wound type accurately
* Time-consuming manual documentation
* No standardised treatment suggestions
* Hard to track and compare healing over time

## Objectives

* **Classify wounds** from a photo using image recognition
* Give **instant management advice**: dressings, antibiotics, surgical steps
* Keep a **dated history** of each patient's wound assessments and vital signs
* Keep patient and wound records **secure**, with role-based access
* Build a **clinician-verified dataset** to keep improving the AI model

**Target users:** nurses, nursing students and healthcare assistants in hospital wards, clinics and home-care visits.

---

## Features

**Staff accounts**
* Log in with Staff ID and password; email verification required
* Self-registration (as a nurse) and password reset by Staff ID
* Roles: **nurse**, **supervisor / lecturer**, **admin**

**Patients**
* Patient profiles with allergies, current medications and chronic conditions
* Vital signs (BP, HR, SpO₂, temperature, blood sugar, pain) with dated history and out-of-range flags

**Wound assessment**
* Capture with the camera or pick from the gallery, after a privacy check (no names, wristbands or labels in the photo)
* **On-device AI** (EfficientNetB0, TensorFlow Lite) classifies the wound into **Types 1–8**. Photos are never sent to a cloud AI service.
* A skin-detection check and a "no wound detected" guard reject unsuitable photos
* **TIME(S) assessment** (Tissue, Infection, Moisture, Edges, Surrounding skin): the nurse's findings score the wound type and are compared with the AI
* Management plan for the confirmed type, with **allergy conflict warnings** (e.g. iodine dressings for an iodine allergy)
* Types 3, 4 and 6 require confirmation that a specialist was notified before saving

**Lecturer review**
* Approval queue for confirmed assessments, with nurse-vs-AI disagreements listed first
* Approve for training, reject, reassign the type, and leave feedback
* Nurses see the lecturer's feedback on their dashboard

---

## Tech stack

| Area | Technology |
|---|---|
| App | Flutter (Dart), Android |
| Login | Firebase Authentication |
| Database | Cloud Firestore, protected by role-based security rules (`firestore.rules`) |
| Photos | Cloud Storage for Firebase (`storage.rules`) |
| Server tasks | Cloud Functions (Node.js 22): copy approved images into the training set; delete a photo when its assessment is deleted |
| AI | TensorFlow Lite (EfficientNetB0) and Google ML Kit selfie segmentation, both on-device |

---

## Project structure

```
lib/
  main.dart             App start-up and Firebase set-up
  theme.dart            Colours, text styles and shared snackbars
  models/               Patient, staff, wound assessment, vital signs, wound-type data
  screens/              One file per screen (login, dashboard, capture, results, ...)
  services/             Firebase access, login, AI analysis, skin detection
  widgets/              Reusable UI pieces
assets/
  models/               The TFLite wound classifier
  images/               App icon
functions/              Cloud Functions
ml/                     Training notebook for the wound classifier
docs/                   Handover documentation
tools/
  firebase-emulator/    Local test Firebase: start script, test data, guide
  rules-tests/          Security-rules tests (npm run test:rules)
  migrate_staff_lookup.js  One-time admin migration (see Deployment)
test/                   Automated tests
android/                Android project
```

---

## Getting started

**You need:** the Flutter SDK (Dart 3.10 or newer), Android Studio with an emulator or an Android phone (Android 8.0+).

1. **Clone the repository**
   ```bash
   git clone https://github.com/nabilaradiah/nurseassist.git
   cd nurseassist
   ```
2. **Add the Firebase config file.** It is not in the repo. Download `google-services.json` from your Firebase project (Project settings → Your apps) and put it in `android/app/`. To create a project, see [docs/01-setup.md](docs/01-setup.md#4-create-your-own-firebase-project).
3. **Install packages and run**
   ```bash
   flutter pub get
   flutter run
   ```

### Testing with local test data (no real Firebase)

The Firebase Emulator Suite runs Auth, Firestore and Storage on your own computer with test accounts and patients, so you can try everything without touching real data or needing a paid plan. See [tools/firebase-emulator/README.md](tools/firebase-emulator/README.md). In short:

```bash
npm install
```
```bash
flutter run --dart-define=USE_FIREBASE_EMULATOR=true
```

The app shows an orange **TEST DATA** banner while it is using the emulators.

### Automated tests

```bash
flutter test
```
```bash
npm run test:rules
```

The second command tests the Firestore and Storage security rules against throwaway emulators. It needs Java, see [docs/01-setup.md](docs/01-setup.md#5-run-the-tests).

---

## Deployment (Firebase)

Run from the project folder, logged in with `firebase login`, after choosing your project with `firebase use --add`:

```bash
firebase deploy --only firestore
```
```bash
firebase deploy --only storage,functions
```

* **Cloud Functions and Cloud Storage need the Blaze (pay-as-you-go) plan.** Security rules, Firestore and Authentication work on the free Spark plan.
* Accounts created before the `staffLookup` change need a one-time migration, run before deploying the rules: `node tools/migrate_staff_lookup.js path/to/serviceAccountKey.json`. New registrations do this automatically, so a new project doesn't need it.
* More in [docs/06-operations.md](docs/06-operations.md).

**Never commit** `serviceAccountKey.json` or `google-services.json`. They are listed in `.gitignore`.

---

## Contributing

1. Update `main`: `git switch main`, then `git pull`
2. Create a branch for your change: `git switch -c my-change`
3. Commit, push the branch, and open a pull request into `main`
4. Merge after the group has reviewed it

Android-specific changes go in `android/` and features in `lib/`. iOS work happens in the separate iOS repository. A feature or fix in `lib/` has to be copied there too, or the two apps drift apart.
