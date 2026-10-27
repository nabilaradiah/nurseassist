# 7. Known issues and backlog

From the full code review of October 2026. Most important first. None of these were started when the project was handed over.

## 1. Clinical (needs the supervisor first)

| Issue | Detail |
|---|---|
| Specialist confirmation for Types 7 and 8? | Only Types 3, 4 and 6 require it. Types 7 and 8 are the most severe. See [Clinical content](05-clinical-content.md#open-clinical-questions) |
| Management text not formally checked | It was copied by hand from the Quick Reference slide. Have the supervisor check it word for word and record the sign-off |

## 2. Security and accounts

| Issue | Where | Suggested fix |
|---|---|---|
| Anyone with a verifiable email can register as a nurse and then read every patient | `registerStaff`, `firestore.rules` | Agree on a policy: e.g. new accounts start as `pending` until a lecturer approves them, or only an institutional email domain can register |
| The role is stored twice (`staff.role` for the UI, `roles/{uid}.role` for the rules) and can drift apart | `auth_service.dart`, `firestore.rules` | Have the app read the role from `roles/{uid}`, and stop writing `staff.role` |
| `getCurrentStaff` has a legacy fallback: if no profile matches the email, it guesses a Staff ID from the email prefix, which can pick the wrong person | `AuthService.getCurrentStaff` | Look up `staffLookup`/`roles/{uid}.staffId` instead, and delete the fallback |
| `staff/` profiles are readable by any signed-in account, even unverified ones | `firestore.rules` | Use `isStaff()` for read |
| No size or type limits on photo uploads | `storage.rules` | e.g. `request.resource.size < 10 * 1024 * 1024 && request.resource.contentType.matches('image/.*')` |
| Release builds fall back to the debug signing key | `android/app/build.gradle.kts` | Create a release keystore ([Setup](01-setup.md#6-build-a-release)), and make release builds fail without one |
| Outdated storage permissions (`READ/WRITE_EXTERNAL_STORAGE`) in the manifest | `AndroidManifest.xml` | Remove them. The image picker uses the system photo picker on modern Android |

## 3. ML

See [ML model](04-ml-model.md#known-weaknesses) for details.

* The resize method differs from training (nearest-neighbour vs bilinear).
* No EXIF orientation fix.
* Skin detection runs twice per photo.
* Image decode and inference run on the UI thread, so the app stutters.
* The test split is per image, not per patient, and the reported accuracy uses TTA. Report an honest accuracy figure.
* Small dataset, especially Types 3 and 4.

## 4. Data and performance

| Issue | Detail |
|---|---|
| Dashboard reloads on every rebuild and makes one query per patient (N+1) | Slow and costs reads. Load once in `initState`, and use aggregate or batched queries |
| No pagination | The patient list and approval queue load everything |
| Vitals are an ever-growing array inside the patient document | Firestore documents are capped at 1 MiB. Move them to a `patients/{id}/vitals` sub-collection |
| MRN uniqueness is only checked by the app | Two nurses can create the same MRN at once. Use the MRN as the document ID, or keep an `mrnLookup` collection like `staffLookup` |
| Approve and reject can leave contradictory flags | e.g. approved then rejected, both `true`. Make each action clear the other |
| Training copies aren't removed when an approved image is re-labelled or un-approved | `training-data/` can hold a photo under the wrong type. Extend the Cloud Function |

## 5. Small

* The dashboard header shows "User" instead of the name when the profile fails to load.
* `print` is used for logging throughout. Use `debugPrint` or a logger, and strip it in release builds.
* `analysis_results_screen.dart` is about 3,400 lines. Split it into widgets (TIME form, management plan, vitals section) before adding to it.
* No CI. A GitHub Actions workflow running `flutter analyze`, `flutter test` and `npm run test:rules` on each pull request would catch regressions.

## Feature ideas (not started)

From the original objectives and the review. Discuss them with the supervisor before taking any on:

* A healing-progress view: one wound's type, size and TIME findings over time, side by side.
* Wound measurement (area) from the photo, e.g. building on the MedSAM3 segmentation experiment.
* An in-app admin screen for roles and account approval.
* Exporting an assessment as a PDF for the patient's notes.
