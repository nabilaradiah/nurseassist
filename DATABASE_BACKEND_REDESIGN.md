# Database & Backend Redesign — NurseAssist (Kulliyyah of Nursing)

**Last updated:** 2026-05-06  
**Status:** Planning — not yet implemented

---

## Decision: Keep Firebase, Expand It

The app already uses Firebase (Firestore + Storage + Auth). No need to switch stacks.

| Layer | Tool | Status |
|---|---|---|
| Auth | Firebase Auth | Already wired in (needs role + stronger passwords) |
| Database | Cloud Firestore | Already working (needs new collections) |
| Image storage | Firebase Storage | Currently local-only — needs to move to Storage |
| Model distribution | Firebase Storage + Remote Config | New — push TFLite updates to all devices |

---

## Firestore Collection Structure

### `users/` — replaces current `staff/`
```
users/
  {userId}/
    staffId            : "22167"        ← for staff
    studentId          : "2210234"      ← for students
    fullName           : "Nur Aisyah"
    email              : String
    role               : "student" | "nurse" | "lecturer" | "admin"
    department         : "Medical Surgical Nursing"
    kulliyyah          : "Kulliyyah of Nursing"
    isActive           : true
    createdAt          : Timestamp
```

### `patients/` — existing, keep structure, minor updates
```
patients/
  {patientId}/
    mrn                : "MRN-00123"    ← anonymised, NO real IC number
    ageRange           : "40-50"        ← NOT exact DOB (PDPA compliance)
    gender             : "F"
    ward               : "Ward 3B"
    primaryNurseId     : {userId}
    createdAt          : Timestamp
```

### `woundCases/` — NEW
Groups multiple assessments for the same wound over time.
```
woundCases/
  {caseId}/
    patientId          : {patientId}
    bodyLocation       : "left heel"
    status             : "active" | "monitoring" | "healed" | "referred"
    openedBy           : {userId}
    openedAt           : Timestamp
    closedAt           : Timestamp | null
```

### `woundAssessments/` — existing, expanded
```
woundAssessments/
  {assessmentId}/
    caseId             : {caseId}
    patientId          : {patientId}
    assessedBy         : {userId}
    assessedAt         : Timestamp
    modelPrediction:
      woundType        : 3              ← int 1–8
      woundName        : "Type_3"
      confidence       : 0.72
      method           : "tflite"
    clinicianVerification:
      verifiedType     : 3              ← what nurse/lecturer says it actually is
      verifiedBy       : {userId}
      verifiedAt       : Timestamp
      notes            : "Confirmed infected wound"
    severity           : "Moderate"
    managementPlan     : { ... }
    followUpDate       : Timestamp
    imageIds           : ["id1", "id2"]
```

### `woundImages/` — NEW (key for ML pipeline)
```
woundImages/
  {imageId}/
    assessmentId       : {assessmentId}
    caseId             : {caseId}
    uploadedBy         : {userId}
    uploadedAt         : Timestamp
    storagePath        : "wound-images/{userId}/{assessmentId}/{imageId}.jpg"
    imageType          : "primary" | "followup"
    mlMetadata:
      modelLabel       : 3             ← model's prediction (int 1–8)
      modelConfidence  : 0.72
      clinicianLabel   : 3             ← verified correct type by clinician
      verifiedBy       : {userId}
      verifiedAt       : Timestamp
      approvedForTraining : false      ← lecturer/admin must flip this to true
      approvedBy       : {userId} | null
      usedInVersion    : null          ← set to "v3" after retraining
```

### `modelVersions/` — NEW
```
modelVersions/
  {versionId}/
    version            : "v3"
    trainedAt          : Timestamp
    accuracy           : 0.68
    trainingImageCount : 640
    classBreakdown     : { Type_1: 80, Type_2: 95, ... }
    tfliteStoragePath  : "models/v3/wound_classifier.tflite"
    isActive           : true
    releasedAt         : Timestamp
```

---

## Firebase Storage Folder Structure

```
wound-images/
  {userId}/
    {assessmentId}/
      {imageId}.jpg              ← full quality original

training-data/
  approved/
    type_1/
    type_2/
    type_3/
    type_4/
    type_5/
    type_6/
    type_7/
    type_8/
      {imageId}.jpg              ← copied here after lecturer approval

models/
  v1/
  v2/
  v3/
    wound_classifier.tflite
    wound_labels.txt
  latest/
    wound_classifier.tflite      ← app always checks here for updates
    wound_labels.txt
```

---

## ML Training Loop (How App Images Feed Back Into Model)

```
1. Nurse captures wound photo in app
           ↓
2. App runs TFLite on-device → shows e.g. "Type_3, 72% confidence"
           ↓
3. Nurse/Lecturer reviews → confirms or corrects the wound type
   (saved to woundImages.mlMetadata.clinicianLabel)
           ↓
4. Lecturer or Admin approves image for training
   (approvedForTraining = true, approvedBy = userId)
           ↓
5. Admin exports all approved images from Firebase Storage
   → downloads into Colab dataset folder grouped by type
   → re-runs wound_preprocess_expanded.ipynb
   → re-runs wound_efficientnetb0_training.ipynb
   → uploads new .tflite to models/latest/ in Firebase Storage
           ↓
6. App detects new model version on startup
   → downloads new wound_classifier.tflite (Wi-Fi only)
   → hot-swaps the local TFLite file
   → all users get improved accuracy automatically
```

---

## Role-Based Permissions

| Action | Student | Nurse | Lecturer | Admin |
|---|---|---|---|---|
| View patients | ✅ | ✅ | ✅ | ✅ |
| Add / edit patients | ❌ | ✅ | ✅ | ✅ |
| Run wound analysis | ✅ | ✅ | ✅ | ✅ |
| Verify wound type (clinician label) | ❌ | ✅ | ✅ | ✅ |
| **Approve image for ML training** | ❌ | ❌ | ✅ | ✅ |
| Export training data | ❌ | ❌ | ❌ | ✅ |
| Push new model version | ❌ | ❌ | ❌ | ✅ |

---

## Constraints & Concerns

### 🔴 Blockers — must resolve BEFORE building

#### 1. IIUM Research Ethics Committee (IREC) approval
Using real patient wound photos to train an AI model requires ethics approval.
This is **not optional**. Without it the entire ML training pipeline cannot be used.
- Apply to IREC early — approval takes weeks to months
- Approval must specifically cover: digital storage of wound images, use for AI model training

#### 2. Patient consent form
Every patient photographed must sign a consent form stating:
- Their wound image will be stored digitally
- It may be used **anonymously** to improve an AI diagnostic system
- They can withdraw consent and request deletion

Existing patients who did not sign such a form **cannot** have their images used for training.

#### 3. PDPA Malaysia 2010 (Personal Data Protection Act)
Wound images are **sensitive personal data** under PDPA. Requirements:
- Do not store real names linked to wound images (use MRN only)
- Do not store exact date of birth — use age range
- Define and enforce a data retention period (e.g., 5 years then delete)
- Patients can request deletion of their data
- Must declare the purpose of data collection

---

### 🟡 Technical concerns

#### 4. Firebase data residency
Firebase default region may store data outside Malaysia. For a university healthcare app:
- Set Firestore and Storage region to **`asia-southeast1` (Singapore)**
- This is the closest region and acceptable under most Malaysian university IT policies
- Must be set **at project creation** — cannot change later

#### 5. Image quality gate
Different phones produce inconsistent images (blur, bad lighting, wrong angle).
Before an image is accepted for training, check:
- Minimum resolution (e.g., 640×480)
- Blur detection score
- Image is not mostly black / overexposed
Reject poor-quality images — they hurt model accuracy more than no image at all.

#### 6. Inter-rater disagreement
Two nurses looking at the same wound may classify it differently.
For training data: **require at least one lecturer to verify** before `approvedForTraining = true`.
This prevents noisy labels from degrading model performance.

#### 7. Offline-first capability
Nurses work in wards with poor connectivity.
- Keep local image capture and TFLite inference working fully offline
- Queue image uploads and sync to Firebase Storage when connectivity returns
- Never block the clinical workflow on internet access

#### 8. Model update file size
Each new TFLite model is ~10–20 MB.
- Only check for / download updates on **Wi-Fi**
- Show a non-blocking notification: "New model available — tap to update"
- Keep the old model working until the new one finishes downloading

#### 9. Current password is `password123`
The current `auth_service.dart` sets every staff password to `password123`.
This must be replaced before any real patient data is stored.
Options:
- Proper Firebase Auth email/password with enforced strong passwords
- IIUM SSO/OAuth if the university exposes one

---

### 🟢 Already flagged code issues (pending fixes)

#### 10. WoundTypesDatabase name mismatch
Current database maps Roboflow names (Abrasion, Burn, Laceration, etc.).
TFLite model outputs Type_1 through Type_8.
The results screen will show wrong clinical information until this is updated.
**This is a pending code fix — must be done before the app can use the TFLite model.**

#### 11. No Firestore Security Rules for roles
Currently all staff see all patients with no permission boundaries.
Firestore Security Rules need to enforce the role table above.

---

## Suggested Build Order

| # | Task | Priority | Dependency |
|---|---|---|---|
| 1 | Apply for IREC ethics approval | 🔴 Immediate | None — start paperwork now |
| 2 | Draft patient consent form | 🔴 Immediate | Ethics approval |
| 3 | Add `role` field to `users` collection | 🟡 High | None |
| 4 | Fix `WoundTypesDatabase` (Type_1–8 names) | 🟡 High | None |
| 5 | Fix `_analyzeWithTFLite()` stub in wound_analysis_service.dart | 🟡 High | None |
| 6 | Move image storage from local → Firebase Storage | 🟡 High | None |
| 7 | Add `woundImages` collection with `mlMetadata` | 🟡 High | Step 6 |
| 8 | Add `woundCases` collection | 🟠 Medium | None |
| 9 | Lecturer approval UI for training images | 🟠 Medium | Steps 3, 7 |
| 10 | App auto-update for new TFLite model | 🟠 Medium | Steps 6, 7 |
| 11 | Firestore Security Rules for RBAC | 🟠 Medium | Step 3 |
| 12 | Fix `password123` auth | 🔴 Before going live | None |

---

## ML Notebooks (already generated — in `ml/` folder)

| File | Purpose | Run order |
|---|---|---|
| `wound_preprocess_expanded.ipynb` | MedSAM3 wound crop + copy-paste aug for 5 minority types | 1st |
| `wound_efficientnetb0_training.ipynb` | Train EfficientNetB0 on preprocessed dataset | 2nd |

When new approved images are exported from Firebase → add to dataset → re-run both notebooks → upload new `.tflite` to `models/latest/`.
