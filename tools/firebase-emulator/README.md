# Local test Firebase (Emulator Suite)

Runs Firebase Auth, Firestore and Storage on this computer so the app can be
tested end to end without touching the real NurseAssist project or its
billing. Everything here is local test data only.

## 1. Start the emulators

```powershell
powershell -ExecutionPolicy Bypass -File tools/firebase-emulator/start.ps1
```

Leave that window open. The Emulator UI (to browse the test data) is at
http://127.0.0.1:4000. Data is saved to `tools/firebase-emulator/data/` when
you stop the emulators with Ctrl+C (that folder is git-ignored).

## 2. Load the test data

In a second terminal:

```powershell
node tools/firebase-emulator/seed.js
```

This wipes the local data and loads a fresh set. Re-run it any time to reset.

## 3. Run the app in test mode

In VS Code, pick **NurseAssist (local test Firebase)** in the Run and Debug
panel and press F5. Or from a terminal:

```powershell
flutter run --dart-define=USE_FIREBASE_EMULATOR=true
```

The app shows an orange **TEST DATA** banner in the corner while it is using
the local emulators. Normal runs and release builds always use real Firebase.

## Test logins (local emulator only)

| Role | Staff ID | Password |
|---|---|---|
| Nurse | `WRN-T01` | `NurseAssist-Test-2026` |
| Lecturer | `LEC-T01` | `NurseAssist-Test-2026` |

These accounts exist only inside the emulator.

## What the test data covers

| Patient / assessment | Use it to check |
|---|---|
| **Test Patient A**, allergy "Povidone-iodine", vitals from 2 h ago | Allergy row on profile, vitals card, "Use these" for recent vitals |
| A1: AI Type 8, no TIME yet | AI suggestions, TIME assessment form, iodine dressing flagged |
| A2: AI Type 6, nurse TIME Type 8, fever 38.4 °C | Disagreement banner, lecturer queue (listed first), vitals on the card |
| **Test Patient B**, allergy "NKDA", no vitals | "No known allergies" (no red warning), recording new vitals |
| B1: AI Type 2, nurse TIME Type 2 | "TIME assessment confirms Type 2", lecturer queue |

Notes:
- The sample wound image is the app icon. For the real AI model, add a wound
  photo through **Capture New Wound → gallery** (drag a photo onto the
  emulator window to put it in its gallery).
- The Cloud Function `copyApprovedWoundImage` is not emulated, so approving
  an image for training does not copy it anywhere.
- Images are served to the Android emulator at `10.0.2.2`. For a physical
  phone on the same Wi-Fi, run the app with
  `--dart-define=FIREBASE_EMULATOR_HOST=<your PC's IP>` and seed with
  `SEED_DEVICE_HOST=<your PC's IP>`.
