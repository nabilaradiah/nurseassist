# 1. Setup

From a fresh computer to the app running. Steps 1–3 need no Firebase account at all. You only need step 4 when you want a real backend.

## 1. Install the tools

| Tool | Version used at handover | Needed for |
|---|---|---|
| Flutter SDK | 3.44 (Dart 3.12); the project needs Dart 3.10 or newer | Building the app |
| Android Studio | Recent, with an Android emulator (API 26+) | Android builds, and its bundled Java runs the Firebase emulators |
| Node.js | 22 or newer (24 used) | Firebase CLI, emulator seed script, rules tests, Cloud Functions |
| Firebase CLI | 15 (`npm install -g firebase-tools`) | Emulators and deploying |
| Java | 17+ (Android Studio's bundled `jbr` works) | Firebase emulators |
| Git | Any | |

Check with `flutter doctor`. Everything it lists for Android should be green.

## 2. Get the code and install packages

```bash
git clone <your copy of the repository>
```
```bash
flutter pub get
```
```bash
npm install
```

`npm install` at the project root installs the packages the emulator seed script and the rules tests need. The Cloud Functions have their own packages in `functions/` (`cd functions && npm install`). You only need those to deploy functions.

## 3. Run the app on local test data (no Firebase project needed)

The Firebase Emulator Suite runs Auth, Firestore and Storage on your computer, with test accounts and patients. This is the normal way to develop. The full guide is in [tools/firebase-emulator/README.md](../tools/firebase-emulator/README.md). In short:

1. Start the emulators and leave the window open:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tools/firebase-emulator/start.ps1
   ```
2. In a second terminal, load the test data:
   ```bash
   node tools/firebase-emulator/seed.js
   ```
3. Run the app in emulator mode (in VS Code, choose **NurseAssist (local test Firebase)**):
   ```bash
   flutter run --dart-define=USE_FIREBASE_EMULATOR=true
   ```

The test logins are in the emulator README. An orange **TEST DATA** banner shows while the app is using the emulators.

> The app still needs a `google-services.json` to build, even in emulator mode, because the Android Gradle plugin requires one. Until you have your own Firebase project (step 4), ask the previous team for theirs, or create a free Firebase project only to download that file.

> On macOS or Linux, `start.ps1` won't run. Use the command it wraps instead: `firebase emulators:start --project nurseassist-b8242 --only auth,firestore,storage --import tools/firebase-emulator/data --export-on-exit tools/firebase-emulator/data`. The project ID only labels the local data. It doesn't touch any real project.

## 4. Create your own Firebase project

The handover is a copy, so your team runs its own Firebase project. Nothing in the code is tied to the original project (`nurseassist-b8242`), except the label the local emulator scripts use.

1. **Create the project.** In the [Firebase console](https://console.firebase.google.com), add a project (e.g. `nurseassist-2027`). Google Analytics is not needed.
2. **Authentication.** Build → Authentication → Get started → enable **Email/Password**.
3. **Firestore.** Build → Firestore Database → Create database. Pick **asia-southeast1 (Singapore)**, the same region the Cloud Functions use, and start in **production mode**. The rules are deployed in step 7.
4. **Plan.** Cloud Storage (wound photos) and Cloud Functions need the **Blaze** (pay-as-you-go) plan. Auth and Firestore work on the free Spark plan. See [Operations](06-operations.md#billing) for what that costs and how to cap it. Without Blaze, everything except photo upload works against the real project, and the emulator covers the rest.
5. **Storage** (once on Blaze). Build → Storage → Get started, same region.
6. **Register the Android app** (Project settings → Your apps → Android), package name `com.nurseassist.app` → download `google-services.json` → put it in `android/app/`. The app reads this file at start-up (`Firebase.initializeApp()` with no options), so there is no `firebase_options.dart` to generate. The iOS app, kept in its own repository, is registered in the same Firebase project as a separate iOS app.
7. **Point the CLI at your project and deploy the rules and indexes:**
   ```bash
   firebase login
   ```
   ```bash
   firebase use --add
   ```
   Pick your project, alias `default`. This writes `.firebaserc`, which is safe to commit. Then:
   ```bash
   firebase deploy --only firestore
   ```
   And once Storage exists:
   ```bash
   firebase deploy --only storage,functions
   ```
8. **Make the first admin.** Register in the app (Login → Register), click the verification email, then in the Firestore console set `role` to `admin` in **both** the `staff/{doc}` record and `roles/{uid}`. Why it's in two places is explained in [Data and security](03-data-and-security.md#roles). After that, promote lecturers the same way (`lecturer`).

**Don't** copy patient data or wound photos from the original project. Start empty.

## 5. Run the tests

```bash
flutter test
```

Model, scoring and widget tests run in seconds and need no emulator.

```bash
npm run test:rules
```

This tests `firestore.rules` and `storage.rules` against throwaway emulators (54 checks). It needs Java on the `PATH` (on Windows: `$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'; $env:PATH = "$env:JAVA_HOME\bin;$env:PATH"`). It uses ports 8080 and 9199, so stop `start.ps1` first if it's running.

## 6. Build a release

**Android**
```bash
flutter build apk --release
```

Release signing reads `android/key.properties`. The original team never set up a release keystore, so without it the build quietly falls back to the **debug** key. That's fine for demos, but not for any store or long-term install. To set one up:

1. Create a keystore: `keytool -genkey -v -keystore nurseassist-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias nurseassist`
2. Create `android/key.properties`:
   ```
   storePassword=...
   keyPassword=...
   keyAlias=nurseassist
   storeFile=/absolute/path/to/nurseassist-release.jks
   ```
3. Keep the `.jks` file and its passwords somewhere safe and **outside** git. Losing it means you can't ship updates to anyone who installed that build.

**iOS** builds are made from the separate iOS repository, not this one.

## Troubleshooting

| Symptom | Cause |
|---|---|
| "Firebase initialization timeout" in the log, app shows no data | `google-services.json` missing or for another package name |
| Emulator mode: app can't reach the emulators on a real phone | Run with `--dart-define=FIREBASE_EMULATOR_HOST=<your PC's IP>` (default is `10.0.2.2`, which only the Android emulator understands) |
| `start.ps1`: "Could not start … port taken" | An earlier emulator session is still running. Close it or end the `java`/`node` process |
| Login says "Staff ID not found" on a real project | The account was created before `staffLookup` existed. Run `tools/migrate_staff_lookup.js` (see [Operations](06-operations.md)) |
| Login says "Email not verified" | Click the link in the verification email (check spam), then log in again |
| Capture New Wound fails to save on a real project | Storage not set up, or the project isn't on Blaze |
