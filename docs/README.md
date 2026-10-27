# NurseAssist handover docs

These pages are for the team taking over NurseAssist. They describe the app as it was handed over in October 2026: how to get it running, how it works, and what is left to do.

This repository holds the **Android** app only. The iOS version lives in a separate repository, kept by the iOS developer. Both apps use the same Firebase project and the same Dart code in `lib/`, so a change to one should be copied to the other.

Start with the [main README](../README.md) for what the app does. Then read these in order:

| # | Page | Read it to learn |
|---|---|---|
| 1 | [Setup](01-setup.md) | Install the tools, create your own Firebase project, run the app and the tests |
| 2 | [Architecture](02-architecture.md) | How the code is organised, the screens, and the main user flows |
| 3 | [Data and security](03-data-and-security.md) | Firestore collections, Storage paths, security rules, Cloud Functions |
| 4 | [ML model](04-ml-model.md) | The wound classifier: dataset, training, how the app uses it, how to retrain |
| 5 | [Clinical content](05-clinical-content.md) | Wound types, TIME(S) scoring, management plans, and who signs off changes |
| 6 | [Operations](06-operations.md) | Deploying, billing, user accounts and roles |
| 7 | [Known issues and backlog](07-known-issues.md) | What is unfinished or wrong, most important first |
| 8 | [Decision log](08-decisions.md) | Why things are built the way they are, so you don't undo them by accident |

## Your first week

1. Follow [Setup](01-setup.md) until the app runs against the **local emulator** with test data. No Firebase project or billing is needed for this.
2. Log in as the test nurse, add a wound photo from the gallery, fill in the TIME(S) assessment and save it. Then log in as the test lecturer and approve it. You have now been through every main screen.
3. Run `flutter test` and `npm run test:rules`. Both should pass before you change anything.
4. Read [Known issues](07-known-issues.md) and agree with your supervisor which items to take on.
5. Create your own Firebase project when you need a real backend (see [Setup](01-setup.md#4-create-your-own-firebase-project)).

## Rules that keep the app safe

* **Never commit secrets.** `serviceAccountKey.json`, `google-services.json` and `android/key.properties` stay out of git (they are in `.gitignore`).
* **Never put real patient data or identifiable photos** in the emulator seed, the repo, test fixtures or screenshots. Use the test data in `tools/firebase-emulator/`.
* **Clinical text and wound-type rules change only with supervisor sign-off.** See [Clinical content](05-clinical-content.md).
* **Run the rules tests after any change to `firestore.rules` or `storage.rules`.**

## Where everything else is

* Diagrams (use case, ERD, DFD, sequence, architecture), planning notes, budget documents and progress reports were kept out of the repo. They are handed over separately as the `NurseAssist_documents` folder.
* The training dataset (wound photos) is **not** in the repo. See [ML model](04-ml-model.md#dataset) for how it is handed over.
