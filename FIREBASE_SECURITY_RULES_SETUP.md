# 🔐 **How to Set Up Firebase Security Rules - Step-by-Step Implementation Guide**

**For:** Hospital IT Administrators, Developers  
**Goal:** Ensure ONLY your staff can access patient data

---

## 📌 **Overview: What You're Setting Up**

Firebase Security Rules act like a **bouncer at a nightclub**:
- ✅ Show valid credentials (login token) → You get in
- ✅ Your credentials say you work at Hospital A → You see Hospital A patients
- ❌ Your credentials say you work at Hospital B → You can't see Hospital A patients
- ❌ No credentials → You're blocked immediately

---

## 🚀 **QUICK START: 5-Minute Setup**

### **Step 1: Go to Firebase Console**

```
1. Open: https://console.firebase.google.com/
2. Select your NurseAssist project
3. Left sidebar → Firestore Database
4. Click "Rules" tab
```

### **Step 2: Copy & Paste Basic Security Rule**

Replace everything in the Rules editor with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Only authenticated users
    match /patients/{patientId} {
      allow read, write: if request.auth != null;
    }
    
    match /wounds/{woundId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### **Step 3: Click "Publish"**

Done! Now only logged-in users can access data.

---

## 🏥 **STEP-BY-STEP IMPLEMENTATION**

### **Step 1: Access Firebase Console**

```
URL: https://console.firebase.google.com/
Login: Use your Google account associated with NurseAssist project
Select Project: "nurseassist"
```

**What you should see:**
```
Firebase Console
├─ Overview
├─ Authentication
├─ Firestore Database
│  ├─ Data
│  ├─ Indexes
│  ├─ Rules ← CLICK HERE
│  └─ Backups
├─ Storage
├─ Realtime Database
└─ Cloud Functions
```

---

### **Step 2: Navigate to Firestore Rules**

```
1. Click "Firestore Database" in left sidebar
2. Click "Rules" tab (top navigation)
3. You'll see a text editor with existing rules
```

**Current Default Rules (usually too permissive):**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

### **Step 3: Choose Your Security Rule Level**

Pick one based on your needs:

---

## 🔒 **SECURITY RULE OPTIONS**

### **OPTION 1: BASIC - "Only Logged-In Users"**

✅ **Use this if:** Your app is only for your hospital's staff  
❌ **Weakness:** Any staff can see any patient (no privacy between departments)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow any logged-in user to read/write any patient data
    match /patients/{patientId} {
      allow read, write: if request.auth != null;
    }
    
    match /wounds/{woundId} {
      allow read, write: if request.auth != null;
    }
    
    match /users/{userId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

**How to implement:**
1. Copy the code above
2. Paste into Firebase Rules editor
3. Click "Publish"
4. Test by trying to login

---

### **OPTION 2: RECOMMENDED - "Role-Based Access Control"**

✅ **Use this if:** You want staff to only see patients assigned to them  
✅ **Best for:** Medium-sized hospitals (50-200 bed)

**First, store user roles in Firestore:**

When a nurse logs in for the first time, create a user record:

```javascript
// Collection: users
// Document: {nurse_email}
{
  "email": "sarah@hospital.com",
  "role": "nurse",
  "ward": "ICU",
  "facility": "General Hospital",
  "department": "Wound Care",
  "permissions": ["view_patients", "edit_wounds", "view_reports"]
}
```

**Then, apply these Security Rules:**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Get user's role and facility
    function getUserRole() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role;
    }
    
    function getUserFacility() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.facility;
    }
    
    function getUserWard() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.ward;
    }
    
    // PATIENTS - Nurses can only see patients in their ward
    match /patients/{patientId} {
      allow read: if request.auth != null 
                  && resource.data.ward == getUserWard()
                  && resource.data.facility == getUserFacility();
      
      allow write: if request.auth != null 
                   && resource.data.ward == getUserWard()
                   && resource.data.facility == getUserFacility();
      
      // Admins can see everything
      allow read, write: if getUserRole() == "admin";
    }
    
    // WOUNDS - Only accessible with patient access
    match /wounds/{woundId} {
      allow read: if request.auth != null 
                  && exists(/databases/$(database)/documents/patients/$(resource.data.patientId))
                  && get(/databases/$(database)/documents/patients/$(resource.data.patientId)).data.ward == getUserWard();
      
      allow write: if request.auth != null 
                   && getUserRole() == "nurse"
                   && exists(/databases/$(database)/documents/patients/$(resource.data.patientId))
                   && get(/databases/$(database)/documents/patients/$(resource.data.patientId)).data.ward == getUserWard();
    }
    
    // USER PROFILES - Users can only edit their own profile
    match /users/{userId} {
      allow read: if request.auth.uid == userId;
      allow write: if request.auth.uid == userId 
                   || getUserRole() == "admin";
    }
  }
}
```

**What this does:**
```
Nurse Sarah (ICU Ward):
  ✅ Can see: ICU patients only
  ❌ Cannot see: Emergency Room patients
  ❌ Cannot see: other wards

Admin user:
  ✅ Can see: ALL patients
  ✅ Can manage: all staff
  ✅ Can delete: records (if authorized)
```

---

### **OPTION 3: ENTERPRISE - "Multi-Facility with Audit"**

✅ **Use this if:** Multiple hospitals sharing one app  
✅ **Best for:** Large health systems, multi-site networks

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper functions
    function getUserData() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
    }
    
    function getUserRole() {
      return getUserData().role;
    }
    
    function getUserFacility() {
      return getUserData().facility;
    }
    
    function getUserWard() {
      return getUserData().ward;
    }
    
    // PATIENTS - Strict facility & ward isolation
    match /facilities/{facilityId}/patients/{patientId} {
      allow read: if request.auth != null 
                  && getUserFacility() == facilityId
                  && getUserWard() == resource.data.ward;
      
      allow create: if request.auth != null 
                    && getUserRole() in ["nurse", "admin"]
                    && getUserFacility() == facilityId
                    && request.resource.data.facility == facilityId;
      
      allow update: if request.auth != null 
                    && getUserRole() in ["nurse", "admin"]
                    && getUserFacility() == facilityId
                    && resource.data.facility == facilityId;
      
      allow delete: if getUserRole() == "admin" 
                    && getUserFacility() == facilityId;
    }
    
    // WOUNDS with images
    match /facilities/{facilityId}/wounds/{woundId} {
      allow read: if request.auth != null 
                  && getUserFacility() == facilityId
                  && exists(/databases/$(database)/documents/facilities/$(facilityId)/patients/$(resource.data.patientId))
                  && get(/databases/$(database)/documents/facilities/$(facilityId)/patients/$(resource.data.patientId)).data.ward == getUserWard();
      
      allow create: if request.auth != null 
                    && getUserRole() == "nurse"
                    && getUserFacility() == facilityId
                    && request.resource.data.facility == facilityId;
      
      allow update: if request.auth != null 
                    && getUserRole() in ["nurse", "admin"]
                    && getUserFacility() == facilityId;
      
      allow delete: if getUserRole() == "admin";
    }
    
    // AUDIT LOGS - Append-only (no deletes/updates)
    match /facilities/{facilityId}/auditLogs/{logId} {
      allow read: if getUserRole() == "admin" 
                  && getUserFacility() == facilityId;
      
      allow create: if request.auth != null 
                    && getUserFacility() == facilityId;
      
      allow update, delete: if false; // Immutable logs
    }
    
    // USER MANAGEMENT
    match /facilities/{facilityId}/users/{userId} {
      allow read: if request.auth != null 
                  && getUserFacility() == facilityId;
      
      allow write: if getUserRole() == "admin" 
                   && getUserFacility() == facilityId;
    }
  }
}
```

---

## 🗄️ **FIREBASE STORAGE RULES (For Images)**

### **Security Rules for Wound Images:**

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Patient images - stored by facility/patient
    match /facilities/{facilityId}/patients/{patientId}/wounds/{woundId}/images/{imageId} {
      // Only nurses from the same facility/ward can see images
      allow read: if request.auth != null 
                  && request.auth.token.facility == facilityId
                  && request.auth.token.ward == 
                     firestore.get(/databases/(default)/documents/facilities/$(facilityId)/patients/$(patientId)).data.ward;
      
      // Only nurses can upload
      allow write: if request.auth != null 
                   && request.auth.token.role == 'nurse'
                   && request.auth.token.facility == facilityId
                   && request.resource.size < 10 * 1024 * 1024; // Max 10MB
      
      // Admins can delete
      allow delete: if request.auth.token.role == 'admin';
    }
  }
}
```

---

## ✅ **STEP-BY-STEP: Actually Publishing the Rules**

### **In Firebase Console:**

```
1. Open: https://console.firebase.google.com/
2. Select Project: nurseassist
3. Left Menu: Firestore Database
4. Click: Rules tab
5. Clear existing rules (Ctrl+A, Delete)
6. Paste your chosen rule set (copy from above)
7. Review the rules (they'll highlight syntax errors in red)
8. Click: "Publish" button (blue, top right)
9. Wait: ~30 seconds for deployment
10. Check: Green notification "Rules updated successfully"
```

**Screenshot Guide:**
```
Firebase Console
├─ nurseassist project
│  ├─ Firestore Database (click)
│  │  ├─ Data tab
│  │  ├─ Rules tab ← CLICK HERE
│  │  ├─ Text Editor
│  │  │  ├─ Paste your rules here
│  │  │  └─ [Publish Button]
│  │  └─ Deploy notification
```

---

## 🧪 **Testing the Rules**

### **Method 1: Using Firebase Console Simulator**

```
1. In Rules tab, click "Test" button
2. Select rule to test
3. Enter test data:
   - Authentication: logged in as user@hospital.com
   - Path: /patients/patient123
   - Operation: read
4. Click "Run"
5. Result: "ALLOWED" or "DENIED"
```

### **Method 2: Test in Your App**

```dart
// In your Flutter app - try accessing data
void testSecurityRules() async {
  try {
    // This should work if authenticated
    var data = await FirebaseFirestore.instance
        .collection('patients')
        .doc('patient123')
        .get();
    print('✅ Access allowed: $data');
  } catch (e) {
    print('❌ Access denied: $e');
  }
}
```

### **Method 3: Automated Testing Script**

Create a test file `firebase_rules_test.js`:

```javascript
const firebase = require('@firebase/rules-unit-testing');
const fs = require('fs');

const projectId = 'nurseassist';
const rules = fs.readFileSync('./firestore.rules', 'utf8');

describe('Firestore Security Rules', () => {
  beforeAll(async () => {
    await firebase.loadFirestoreRules({ projectId, rules });
  });

  it('allows logged-in nurses to read their ward patients', async () => {
    const nurse = firebase.initializeTestApp({
      projectId,
      auth: { uid: 'nurse_123', facility: 'Hospital_A', ward: 'ICU' }
    });
    
    const db = nurse.firestore();
    await firebase.assertSucceeds(
      db.collection('patients').where('ward', '==', 'ICU').get()
    );
  });

  it('blocks nurses from reading other ward patients', async () => {
    const nurse = firebase.initializeTestApp({
      projectId,
      auth: { uid: 'nurse_123', facility: 'Hospital_A', ward: 'ICU' }
    });
    
    const db = nurse.firestore();
    await firebase.assertFails(
      db.collection('patients').doc('ER_patient_123').get()
    );
  });

  it('blocks unauthenticated users', async () => {
    const unauth = firebase.initializeTestApp({
      projectId,
      auth: undefined
    });
    
    const db = unauth.firestore();
    await firebase.assertFails(
      db.collection('patients').get()
    );
  });
});
```

Run tests:
```bash
npm test
```

---

## 🛠️ **Custom Rules for Your Specific Setup**

### **Rule 1: Department-Based Access**

Nurses can only see patients from their department:

```javascript
match /patients/{patientId} {
  allow read: if request.auth != null 
              && resource.data.department == getUserDepartment();
}
```

### **Rule 2: Time-Based Access**

Records locked after 30 days (read-only):

```javascript
match /wounds/{woundId} {
  allow read: if request.auth != null;
  
  allow write: if request.auth != null 
               && (now - resource.data.createdAt) < duration.value(30, 'd');
}
```

### **Rule 3: Shift-Based Access**

Nurses can only access during their shift:

```javascript
match /patients/{patientId} {
  allow read: if request.auth != null 
              && now.toMillis() > getUserShiftStart()
              && now.toMillis() < getUserShiftEnd();
}
```

### **Rule 4: Approval Chain**

Edits require approval from supervisor:

```javascript
match /wounds/{woundId} {
  allow update: if request.auth != null 
                && request.resource.data.status == "pending_approval";
}
```

---

## 📊 **Rule Documentation Template**

Save this as `FIRESTORE_RULES_DOCUMENTATION.md`:

```markdown
# Firebase Firestore Security Rules Documentation

## Facility: General Hospital
## Date: 2026-02-01

### Access Levels

| Role | Can See | Can Edit | Can Delete |
|------|---------|----------|-----------|
| Nurse | Own ward patients | Own ward wounds | ❌ No |
| Charge Nurse | All ward patients | All ward wounds | ❌ No |
| Admin | All patients | All records | ✅ Yes |
| Patient | Own records only | ❌ No | ❌ No |

### Data Structure

```
facilities/
  {facilityId}/
    patients/
      {patientId}/
        - name
        - ward: "ICU"
        - facility: "General_Hospital"
    wounds/
      {woundId}/
        - patientId
        - type
        - severity
    users/
      {userId}/
        - role: "nurse"
        - ward: "ICU"
    auditLogs/
      {logId}/
        - action: "viewed_patient"
        - timestamp
        - user
```

### Security Rules Applied

[Copy your rules here]

### Testing Results

- ✅ Nurses can view own ward patients
- ✅ Nurses cannot view other wards
- ✅ Admins can view all patients
- ✅ Unauthenticated users blocked
- ✅ Images encrypted in transit

### Audit Trail

- Last modified: 2026-02-01
- Modified by: IT-Admin
- Change: Initial setup
```

---

## ⚠️ **Common Mistakes to Avoid**

| ❌ Mistake | ✅ Fix |
|---|---|
| Rules too permissive (allow everyone) | Add authentication checks |
| Rules too restrictive (block all) | Add specific user role checks |
| Forgetting Storage rules | Set rules for images too |
| No audit logging | Add audit log collection |
| Hardcoded user IDs | Use request.auth.uid |
| Testing only success cases | Test both allow AND deny |
| Not backing up rules | Save rules to version control |
| Deploying without testing | Always test in simulator first |

---

## 🔄 **Updating Rules Later**

### **When to Update:**

- New staff role added
- Department restructured
- Security incident occurs
- Compliance requirements change

### **How to Update:**

```
1. Make changes in Firebase Console Rules tab
2. Test in Rules Simulator
3. Click "Publish"
4. Document change: Add comment with date
5. Backup old rules (save to file)
6. Monitor logs for 24 hours (unusual access)
```

### **Rollback if Needed:**

```
1. Copy previous rules from backup file
2. Paste into Firebase Console
3. Click "Publish"
4. Check logs for any blocked access
```

---

## 🔗 **Integration with NurseAssist App**

### **When Nurse Logs In (main.dart):**

```dart
Future<void> setupSecurityOnLogin(User user) async {
  // After Firebase auth, set custom claims
  final firestore = FirebaseFirestore.instance;
  
  await firestore.collection('users').doc(user.uid).set({
    'email': user.email,
    'role': 'nurse',
    'ward': 'ICU',  // From hospital database
    'facility': 'General Hospital',
    'lastLogin': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
  
  print('✅ User security profile set up');
}
```

### **When Accessing Patient Data:**

```dart
Future<List<Patient>> getPatientsByWard(String ward) async {
  final firestore = FirebaseFirestore.instance;
  
  try {
    final query = await firestore
        .collection('patients')
        .where('ward', isEqualTo: ward)
        .get();
    
    return query.docs
        .map((doc) => Patient.fromFirestore(doc))
        .toList();
  } on FirebaseException catch (e) {
    if (e.code == 'permission-denied') {
      print('❌ Access denied by security rules');
    }
    rethrow;
  }
}
```

---

## 📞 **Troubleshooting**

### **Issue: "Permission denied" error**

**Solution:**
```
1. Check user is logged in: Firebase Auth
2. Check user role in Firestore: collection/users
3. Test rules in Simulator
4. Check Security Rules console for errors
5. Look at Firestore Logs for detailed error
```

### **Issue: Rules deployed but still can't access**

**Solution:**
```
1. Wait 30-60 seconds (deployment delay)
2. Refresh app
3. Clear app cache and re-login
4. Check Firestore Logs (Rules tab)
```

### **Issue: Performance is slow**

**Solution:**
```
1. Reduce number of get() calls in rules
2. Use caching in your app
3. Create indexes for frequently queried fields
4. Batch read operations
```

---

## ✅ **Final Verification Checklist**

Before going live:

- [ ] Rules published to Firebase
- [ ] Tested in Rules Simulator (allow and deny cases)
- [ ] Tested in actual app with different user roles
- [ ] Audit logging enabled
- [ ] Documentation completed
- [ ] Backup of rules saved
- [ ] Staff trained on data access
- [ ] Compliance review completed
- [ ] Performance tested with realistic data volume
- [ ] Disaster recovery tested

---

**Your security is now configured! Only your authorized staff can access patient data.** 🔒

For help: Ask your Firebase support or IT team to review the rules before production launch.
