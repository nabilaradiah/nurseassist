# NurseAssist — Authentication System

## Overview

NurseAssist uses **Firebase Authentication** (Email/Password) combined with a
**Firestore `staff` collection** to manage user accounts.

Login is done with a **Staff ID + Password** pair — the Staff ID is familiar to
nursing staff and acts as their visible identifier throughout the app, while
Firebase Auth handles the secure credential management behind the scenes.

---

## Firebase Setup Required

In the Firebase Console, ensure the following is enabled:

1. Go to **Authentication → Sign-in method**
2. Enable **Email/Password**
3. Click **Save**

Firebase's built-in email sending handles both verification emails and password
reset emails automatically — no additional configuration needed.

---

## Staff Document Structure (Firestore `staff` collection)

Each registered user has one document in the `staff` collection:

| Field        | Type      | Description                                              |
|--------------|-----------|----------------------------------------------------------|
| `staffId`    | `String`  | Unique staff ID (e.g. `WRN-001`). Used for login lookup. |
| `name`       | `String`  | Full name of the staff member.                           |
| `department` | `String`  | One of the 5 nursing departments.                        |
| `email`      | `String`  | Real email address — used for Firebase Auth login.       |
| `role`       | `String`  | `nurse` / `lecturer` / `admin`. Defaults to `nurse`.     |
| `createdAt`  | `Timestamp` | Server timestamp set at registration.                  |

### Role Permissions

| Role       | Can do                                                          |
|------------|-----------------------------------------------------------------|
| `nurse`    | View patients, capture wounds, correct wound types              |
| `lecturer` | All nurse permissions + approve images for model retraining     |
| `admin`    | Full access                                                     |

> **Note:** Role is set to `nurse` automatically at registration.
> To promote a user to `lecturer` or `admin`, manually update their
> `role` field in the Firebase Console → Firestore → `staff` collection.

---

## Registration Flow

**Screen:** `lib/screens/user_registration_screen.dart`

**Fields collected:**

| Field            | Validation                              |
|------------------|-----------------------------------------|
| Staff ID         | Required, alphanumeric + dash, uppercase|
| Full Name        | Required                                |
| Department       | Required, selected from dropdown        |
| Email Address    | Required, valid email format            |
| Password         | Required, minimum 8 characters          |
| Confirm Password | Must match Password                     |

**What happens on Register:**

1. Validates all fields client-side.
2. Checks Firestore — if Staff ID is already registered, throws an error.
3. Creates a Firebase Auth account using the **real email + password**.
4. Saves the staff profile to Firestore with `role: 'nurse'`.
5. Sends a **confirmation / verification email** to the registered email address
   automatically via Firebase (`sendEmailVerification()`).
6. Signs the user out — they must verify their email and then log in manually.
7. Shows a success dialog:
   > *"Registration Successful! A confirmation email has been sent to
   > your@email.com. Please verify your email before logging in."*

---

## Login Flow

**Screen:** `lib/screens/login_screen.dart`

**Fields:**

| Field    | Description                      |
|----------|----------------------------------|
| Staff ID | Used to look up the account      |
| Password | Firebase Auth password           |

**What happens on Login:**

1. Looks up the staff document in Firestore by `staffId`.
2. Retrieves the stored `email` from that document.
3. Calls `FirebaseAuth.signInWithEmailAndPassword(email, password)`.
4. On success, navigates to the Dashboard.
5. On failure, shows a specific error message:
   - Wrong password → *"Incorrect password. Please try again."*
   - Staff ID not found → *"Staff ID not found."*
   - Account disabled → *"This account has been disabled."*
   - Too many attempts → *"Too many failed attempts. Try again later."*

---

## Forgot Password Flow

**Trigger:** "Forgot password?" link on the Login screen.

**Steps:**

1. User enters their **Staff ID** in a dialog.
2. App looks up their registered email from Firestore.
3. Calls `FirebaseAuth.sendPasswordResetEmail(email)`.
4. Firebase sends a password reset link to their email.
5. User clicks the link in their email → sets a new password → logs in normally.

> The `sendPasswordReset()` method in `AuthService` also accepts a direct
> email address if the Staff ID is unknown.

---

## Email Verification

Firebase sends two types of emails automatically:

| When                  | Email type              | Purpose                              |
|-----------------------|-------------------------|--------------------------------------|
| After registration    | Verification email      | Confirms the email address is real   |
| After forgot password | Password reset email    | Allows the user to set a new password|

Both emails are sent from Firebase's default no-reply address. To customise
the sender name or template, go to:
**Firebase Console → Authentication → Templates**

---

## AuthService API (`lib/services/auth_service.dart`)

`AuthService` is a singleton — use `AuthService()` anywhere in the app.

### Methods

```dart
// Sign in with Staff ID + password
Future<Staff?> signInWithStaffId(String staffId, String password)

// Register a new staff account (role defaults to 'nurse')
Future<Staff> registerStaff({
  required String staffId,
  required String fullName,
  required String department,
  required String email,
  required String password,
})

// Send password reset — accepts Staff ID or email
Future<void> sendPasswordReset(String staffIdOrEmail)

// Get the currently logged-in staff profile
Future<Staff?> getCurrentStaff()

// Sign out
Future<void> signOut()
```

### Properties

```dart
User?         get currentUser     // Firebase Auth user (null if not logged in)
Staff?        get loggedInStaff   // Cached Staff model (null if not logged in)
Stream<User?> get authStateChanges // Stream for auth state changes
```

---

## Staff Model (`lib/models/staff.dart`)

```dart
class Staff {
  final String  id;           // Firestore document ID
  final String  staffId;      // e.g. 'WRN-001'
  final String  name;         // Full name
  final String  department;   // Nursing department
  final String? email;        // Registered email (nullable for legacy accounts)
  final String  role;         // 'nurse' | 'lecturer' | 'admin'

  bool get isLecturer => role == 'lecturer' || role == 'admin';
  bool get isAdmin    => role == 'admin';
}
```

---

## Legacy Account Compatibility

Accounts registered **before** this auth update used a generated email
(`staffid@nurseassist.app`) and a hardcoded password (`password123`).

These accounts **cannot log in** with the new system because:
- They have no `email` field in their Firestore document.
- They were created with a fake email, not a real one.

**Migration options:**

**Option A — Re-register (recommended for testing):**
Delete the old staff document in Firebase Console and register again
using the new registration screen.

**Option B — Manual patch in Firebase Console:**
1. Open Firestore → `staff` collection → find the document.
2. Add field `email` with their real email address.
3. In Firebase Console → Authentication → find the user with email
   `staffid@nurseassist.app` → update their email to the real one.
4. The user then uses "Forgot password?" to set a new password.

---

## Security Notes

- Passwords are **never stored** in Firestore — Firebase Auth handles them.
- The `staff` collection stores only the `email` for login lookup, not the password.
- Minimum password length: **8 characters** (enforced by both client validation
  and Firebase Auth).
- Role elevation (nurse → lecturer/admin) must be done manually in the
  Firebase Console — it cannot be self-assigned through the app.
- Firestore security rules require `request.auth != null` for all reads/writes,
  ensuring unauthenticated access is blocked.
