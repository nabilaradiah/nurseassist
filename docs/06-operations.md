# 6. Operations

## Deploying

Run these from the project folder after `firebase login` and `firebase use` (see [Setup](01-setup.md#4-create-your-own-firebase-project)).

| What changed | Command | Plan needed |
|---|---|---|
| `firestore.rules` or `firestore.indexes.json` | `firebase deploy --only firestore` | Spark (free) |
| `storage.rules` | `firebase deploy --only storage` | Blaze |
| `functions/` | `firebase deploy --only functions` | Blaze |
| The app | Build an APK/IPA and install it ([Setup](01-setup.md#6-build-a-release)) | |

Before deploying rules, run `npm run test:rules`. A rules mistake either locks everyone out or opens patient data, and it takes effect within about a minute.

**Rules and app versions have to match.** If you change a rule that older app builds rely on, everyone on an old build breaks. Deploy the rules and hand out the new build together.

## Billing

* **Spark (free)** covers Authentication, Firestore and security rules. That's enough for everything except photo upload, and the emulator covers development.
* **Blaze (pay-as-you-go)** is needed for Cloud Storage (photos) and Cloud Functions. Blaze still includes a monthly free allowance. A student project with a handful of users normally stays inside it, but that isn't guaranteed.
* **Whoever owns the billing account should be the supervisor or the faculty, not a student.** Students graduate, and the project shouldn't stop when their card is removed.
* **Set a budget alert** when you enable Blaze: Google Cloud console → Billing → Budgets & alerts, e.g. RM10/month with email alerts at 50 %, 90 % and 100 %. A budget alerts you but doesn't cap spending.
* Common surprise costs: a screen re-reading a whole collection on every rebuild (the dashboard does this today, see [known issues](07-known-issues.md)), and leftover photos in Storage.

## User accounts and roles

There's no admin screen. Use the Firebase console.

| Task | How |
|---|---|
| New nurse | They self-register in the app and verify their email |
| Make someone a lecturer/admin | Set `role` in **both** `staff/{doc}` and `roles/{uid}` to `lecturer` or `admin`. The uid is in Authentication → Users |
| Disable an account | Authentication → Users → ⋮ → Disable account. Firestore records stay for the audit trail |
| Remove an account completely | Delete the Auth user, then `roles/{uid}`, `staffLookup/{STAFF_ID}` and `staff/{doc}`. Assessments keep their `...By` Staff IDs |
| Someone can't log in: "Staff ID not found" | Their `staffLookup/{STAFF_ID}` document is missing (see the migration below) |
| Someone can't log in: "Email not verified" | They need to click the verification link. From the login screen, "forgot password" also sends an email if they've lost access |

Anyone with an email address can self-register as a nurse today. Agree with your supervisor whether that's acceptable before real use ([known issues](07-known-issues.md)).

## One-off tools

| Tool | When to use |
|---|---|
| `tools/migrate_staff_lookup.js <serviceAccountKey.json>` | Only for a project whose accounts were created **before** `staffLookup` existed (the original project). A new project doesn't need it: registration writes `staffLookup` itself. Safe to re-run |
| `tools/firebase-emulator/seed.js` | Resets the **local** emulator to known test data. It refuses to run against anything that isn't local |
| `npm run test:rules` | Security-rules tests |

**Service account keys** (`serviceAccountKey.json`) give full admin access to the project. Create one only when a tool needs it (Project settings → Service accounts → Generate new private key). Keep it outside the repo, and delete it in Google Cloud console → IAM → Service accounts → Keys when you're done.

## The original project (`nurseassist-b8242`)

This was the previous team's Firebase project. It isn't handed over: the next team works on its own copy. For the record, its state at handover (October 2026):

* The October 2026 security fixes (new rules, `staffLookup` login) are merged in the code, and the `staffLookup` migration has been run there. The new rules still had to be deployed to it.
* Billing was removed, so the project is on Spark. Cloud Functions and Storage don't work there until someone moves it to Blaze.
* Access to it, if ever needed, goes through the previous team or the supervisor.
