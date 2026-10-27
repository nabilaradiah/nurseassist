# 3. Data and security

## Firestore collections

```
roles/{uid}               role used by the security rules
staffLookup/{STAFF_ID}    Staff ID → email, readable before login
staff/{autoId}            staff profile shown in the app
patients/{patientId}      patient record, vitals history, list of assessment IDs
woundAssessments/{id}     one photo + AI result + nurse TIME(S) + lecturer review
```

There are no sub-collections. Assessments point to their patient with `patientId`, and the patient keeps `woundAssessmentIds`. The two are kept in step by batched writes in `FirestoreService`.

### `roles/{uid}`
| Field | Notes |
|---|---|
| `role` | `nurse` / `lecturer` / `supervisor` / `admin`. **The security rules read this** |
| `staffId` | e.g. `WRN-001`. The rules use it to check `...By` audit fields |

### `staffLookup/{STAFF_ID}`
| Field | Notes |
|---|---|
| `email`, `uid` | Nothing else is allowed. The document ID is the upper-cased Staff ID |

This is the only data readable before login: the login and password-reset screens turn a Staff ID into an email with it. It can be read one document at a time but not listed, so nobody can harvest the staff list. Updates are blocked, which also makes Staff IDs unique.

### `staff/{autoId}`
| Field | Notes |
|---|---|
| `staffId`, `name`, `department`, `email` | `email` is lower-case |
| `role` | **The app UI reads this** (dashboard, lecturer buttons) |
| `createdAt` | Server timestamp |

### `patients/{patientId}`
| Field | Notes |
|---|---|
| `mrn`, `name`, `age`, `gender`, `contact`, `phone`, `addressRoom` | Uniqueness of `mrn` is only checked by the app (see [known issues](07-known-issues.md)) |
| `allergies`, `medications` | Free text. "None", "Nil", "NKDA" etc. count as no allergies (`Patient.hasKnownAllergies`) |
| `chronicConditions` | List of maps |
| `vitalReadings` | List of dated readings, appended with `arrayUnion`. Grows forever |
| `woundAssessmentIds` | List of IDs |
| `staffIdAssignedTo`, `registeredDate`, `emergencyContact*` | |

### `woundAssessments/{id}`
Grouped by who writes them:

| Group | Fields | Written by |
|---|---|---|
| Capture | `patientId`, `imageUrl`, `assessmentDate`, `analysisResult` (type, confidence, all 8 probabilities, management plan snapshot), `modelPredictedType`, `modelConfidence`, `requiresSpecialistConfirmation` | Nurse, on capture |
| Nurse | `timeAssessment` (map), `clinicianCorrectedType`/`Name`, `correctedBy`/`correctedAt`, `vitals`, `specialistConfirmed`, `additionalNotes` | Nurse |
| Lecturer | `approvedForTraining`, `approvedBy`/`At`, `rejectedForTraining`, `rejectedBy`/`At`, `supervisorCorrectedType`/`Name`, `supervisorFeedback`, `supervisorFeedbackBy`/`At`, `hasSupervisorFeedback` | Lecturer/admin |
| Function | `trainingImagePath` | `copyApprovedWoundImage` only |

Dates are mostly ISO-8601 strings written by the app. The `...At` audit fields are Firestore server timestamps. `WoundAssessment.fromJson` accepts both.

### Indexes

`firestore.indexes.json` holds the two composite indexes the app needs:
* `approvedForTraining` + `clinicianCorrectedType`, for the approval queue
* `correctedBy` + `hasSupervisorFeedback`, for nurse feedback

`firebase deploy --only firestore` deploys them. A missing index shows up as a `failed-precondition` error with a console link that creates it.

## Cloud Storage

| Path | Who | Notes |
|---|---|---|
| `wound_images/{uid}/{file}.jpg` | Any signed-in user can read. Only `{uid}` can write or delete | Uploaded by `FirestoreService.uploadWoundImage` |
| `training-data/approved/type_{N}/{file}` | No app access at all | Written by the Cloud Function. This is the retraining set |

There are no size or content-type limits in `storage.rules` yet ([known issues](07-known-issues.md)).

## Security rules in plain words

`firestore.rules` is the real backend. What it enforces:

* **Being staff** means signed in, with a **verified email**, and a `roles/{uid}` document. A bare Auth account gets nothing.
* **Registration** may only create `role: 'nurse'` for the caller's own uid and email (`roles`, `staff`, `staffLookup`).
* **Roles** change only by admin. Nobody can delete a role document.
* **Patients**: staff can read, create and update. Only lecturer/admin can delete.
* **Wound assessments**:
  * A new one must start unreviewed: no correction, approval, rejection or feedback.
  * Nurses can't touch any approval, rejection, supervisor or `trainingImagePath` field.
  * Every `...By`/`...At` pair must be unchanged, cleared together, or set to **the caller's own Staff ID and the server's time**. Nobody can sign as someone else or back-date.
  * Only lecturer/admin can delete.

Tests for every one of these are in `tools/rules-tests/`. Run `npm run test:rules` after **any** rules change and add a test for the new behaviour.

### Roles

The role is stored twice: `staff.role` drives the UI, `roles/{uid}.role` drives the rules. They must match. When promoting someone, change both. This is a known wart ([known issues](07-known-issues.md)). The cleanest fix is for the app to read the role from `roles/{uid}`.

## Cloud Functions (`functions/index.js`)

Node.js 22, first-generation `firebase-functions` v5, region `asia-southeast1`. Both use the project's default Storage bucket.

| Function | Trigger | Does |
|---|---|---|
| `copyApprovedWoundImage` | `woundAssessments/{id}` updated, `approvedForTraining` false → true | Copies the photo to `training-data/approved/type_N/`, where N is the supervisor type, else the nurse type, else the AI type. Writes `trainingImagePath` back |
| `deleteWoundImageOnAssessmentDelete` | `woundAssessments/{id}` deleted (also when its patient is deleted) | Deletes the photo from `wound_images/`. Training copies are kept |

The client can't delete other people's photos (Storage rules), which is why the delete runs as a function. Neither function runs in the local emulator setup (`start.ps1` starts Auth, Firestore and Storage only).

## Privacy and ethics

* Wound photos and patient records are health data. Real patient use needs ethics approval (IREC at IIUM) and the hospital's agreement. Check the status with your supervisor before collecting real data.
* The app asks nurses to keep names, wristbands and paperwork out of the frame, but nothing checks the photo for them automatically.
* Never use real patient data in the emulator, tests, screenshots or the report.
