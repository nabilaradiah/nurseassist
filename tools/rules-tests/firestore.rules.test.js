/**
 * Tests for firestore.rules, run against the local Firestore emulator.
 *
 *   npm run test:rules
 *
 * Each test signs in as one kind of user (or none) and checks that a read or
 * write is allowed or refused. If you change firestore.rules, run these and
 * add a test for the new behaviour.
 */

const fs = require('fs');
const path = require('path');
const { test, before, beforeEach, after, describe } = require('node:test');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, getDocs, setDoc, updateDoc, deleteDoc, collection,
  serverTimestamp, Timestamp,
} = require('firebase/firestore');

let env;

// uid → token / roles document for each kind of user
const USERS = {
  nurse:      { email: 'nurse@test.local',    role: 'nurse',    staffId: 'WRN-001' },
  nurse2:     { email: 'nurse2@test.local',   role: 'nurse',    staffId: 'WRN-002' },
  lecturer:   { email: 'lecturer@test.local', role: 'lecturer', staffId: 'LEC-001' },
  admin:      { email: 'admin@test.local',    role: 'admin',    staffId: 'ADM-001' },
};

/** Firestore as a signed-in user. `verified: false` gives an unverified email. */
function db(uid, { verified = true } = {}) {
  const u = USERS[uid] ?? { email: `${uid}@test.local` };
  return env.authenticatedContext(uid, {
    email: u.email,
    email_verified: verified,
  }).firestore();
}

const anon = () => env.unauthenticatedContext().firestore();

// A fresh, unreviewed assessment as the app creates it
const NEW_ASSESSMENT = {
  patientId: 'p1',
  imageUrl: 'https://example.test/x.jpg',
  modelPredictedType: 2,
  approvedForTraining: false,
  rejectedForTraining: false,
  hasSupervisorFeedback: false,
};

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-nurseassist',
    firestore: {
      // Host and port come from FIRESTORE_EMULATOR_HOST, set by emulators:exec
      rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8'),
    },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const fs = ctx.firestore();
    for (const [uid, u] of Object.entries(USERS)) {
      await setDoc(doc(fs, 'roles', uid), { role: u.role, staffId: u.staffId });
    }
    await setDoc(doc(fs, 'staffLookup', 'WRN-001'), { email: USERS.nurse.email, uid: 'nurse' });
    await setDoc(doc(fs, 'staff', 's1'), { staffId: 'WRN-001', email: USERS.nurse.email, role: 'nurse' });
    await setDoc(doc(fs, 'patients', 'p1'), { name: 'Test Patient', mrn: 'MRN1' });
    await setDoc(doc(fs, 'woundAssessments', 'a1'), {
      ...NEW_ASSESSMENT,
      clinicianCorrectedType: 2,
      correctedBy: 'WRN-001',
    });
  });
});

after(async () => {
  await env?.cleanup();
});

// ── roles/ ──────────────────────────────────────────────────────────────────
describe('roles', () => {
  test('a user can read their own role', async () => {
    await assertSucceeds(getDoc(doc(db('nurse'), 'roles', 'nurse')));
  });
  test("a user cannot read someone else's role", async () => {
    await assertFails(getDoc(doc(db('nurse'), 'roles', 'lecturer')));
  });
  test('a new user can create their own nurse role', async () => {
    await assertSucceeds(setDoc(doc(db('newbie'), 'roles', 'newbie'), { role: 'nurse', staffId: 'WRN-009' }));
  });
  test('a new user cannot give themself a higher role', async () => {
    await assertFails(setDoc(doc(db('newbie'), 'roles', 'newbie'), { role: 'admin', staffId: 'WRN-009' }));
  });
  test('a nurse cannot promote themself', async () => {
    await assertFails(updateDoc(doc(db('nurse'), 'roles', 'nurse'), { role: 'lecturer' }));
  });
  test('an admin can change a role', async () => {
    await assertSucceeds(updateDoc(doc(db('admin'), 'roles', 'nurse'), { role: 'lecturer' }));
  });
  test('nobody can delete a role, not even admin', async () => {
    await assertFails(deleteDoc(doc(db('admin'), 'roles', 'nurse')));
  });
});

// ── staffLookup/ ────────────────────────────────────────────────────────────
describe('staffLookup', () => {
  test('anyone can look up a single Staff ID before login', async () => {
    await assertSucceeds(getDoc(doc(anon(), 'staffLookup', 'WRN-001')));
  });
  test('nobody can list every Staff ID', async () => {
    await assertFails(getDocs(collection(anon(), 'staffLookup')));
    await assertFails(getDocs(collection(db('admin'), 'staffLookup')));
  });
  test('a user can register a lookup for their own uid and email', async () => {
    await assertSucceeds(setDoc(doc(db('newbie'), 'staffLookup', 'WRN-009'),
      { email: 'newbie@test.local', uid: 'newbie' }));
  });
  test("a user cannot register a lookup pointing at someone else's email", async () => {
    await assertFails(setDoc(doc(db('newbie'), 'staffLookup', 'WRN-009'),
      { email: USERS.lecturer.email, uid: 'newbie' }));
  });
  test('a lookup cannot carry extra fields', async () => {
    await assertFails(setDoc(doc(db('newbie'), 'staffLookup', 'WRN-009'),
      { email: 'newbie@test.local', uid: 'newbie', role: 'admin' }));
  });
  test('an existing Staff ID cannot be taken over', async () => {
    await assertFails(setDoc(doc(db('newbie'), 'staffLookup', 'WRN-001'),
      { email: 'newbie@test.local', uid: 'newbie' }));
  });
  test('only admin can delete a lookup', async () => {
    await assertFails(deleteDoc(doc(db('lecturer'), 'staffLookup', 'WRN-001')));
    await assertSucceeds(deleteDoc(doc(db('admin'), 'staffLookup', 'WRN-001')));
  });
});

// ── staff/ ──────────────────────────────────────────────────────────────────
describe('staff', () => {
  test('signed-out users cannot read staff profiles', async () => {
    await assertFails(getDoc(doc(anon(), 'staff', 's1')));
  });
  test('signed-in users can read staff profiles', async () => {
    await assertSucceeds(getDoc(doc(db('nurse2'), 'staff', 's1')));
  });
  test('self-registration creates a nurse profile for your own email', async () => {
    await assertSucceeds(setDoc(doc(db('newbie'), 'staff', 's9'),
      { staffId: 'WRN-009', email: 'newbie@test.local', role: 'nurse' }));
  });
  test('self-registration cannot create a lecturer profile', async () => {
    await assertFails(setDoc(doc(db('newbie'), 'staff', 's9'),
      { staffId: 'WRN-009', email: 'newbie@test.local', role: 'lecturer' }));
  });
  test("self-registration cannot use someone else's email", async () => {
    await assertFails(setDoc(doc(db('newbie'), 'staff', 's9'),
      { staffId: 'WRN-009', email: USERS.admin.email, role: 'nurse' }));
  });
  test('a nurse cannot edit a staff profile', async () => {
    await assertFails(updateDoc(doc(db('nurse'), 'staff', 's1'), { role: 'admin' }));
  });
  test('a lecturer can edit a staff profile', async () => {
    await assertSucceeds(updateDoc(doc(db('lecturer'), 'staff', 's1'), { department: 'ICU' }));
  });
});

// ── patients/ ───────────────────────────────────────────────────────────────
describe('patients', () => {
  test('signed-out users cannot read patients', async () => {
    await assertFails(getDoc(doc(anon(), 'patients', 'p1')));
  });
  test('an unverified email cannot read patients', async () => {
    await assertFails(getDoc(doc(db('nurse', { verified: false }), 'patients', 'p1')));
  });
  test('a signed-in account with no roles document cannot read patients', async () => {
    await assertFails(getDoc(doc(db('stranger'), 'patients', 'p1')));
  });
  test('a nurse can read, add and edit patients', async () => {
    const fs = db('nurse');
    await assertSucceeds(getDoc(doc(fs, 'patients', 'p1')));
    await assertSucceeds(setDoc(doc(fs, 'patients', 'p2'), { name: 'New', mrn: 'MRN2' }));
    await assertSucceeds(updateDoc(doc(fs, 'patients', 'p1'), { allergies: 'NKDA' }));
  });
  test('a nurse cannot delete a patient', async () => {
    await assertFails(deleteDoc(doc(db('nurse'), 'patients', 'p1')));
  });
  test('a lecturer can delete a patient', async () => {
    await assertSucceeds(deleteDoc(doc(db('lecturer'), 'patients', 'p1')));
  });
});

// ── woundAssessments/ ───────────────────────────────────────────────────────
describe('woundAssessments: create', () => {
  test('a nurse can create an unreviewed assessment', async () => {
    await assertSucceeds(setDoc(doc(db('nurse'), 'woundAssessments', 'a2'), NEW_ASSESSMENT));
  });
  test('a new assessment cannot arrive already approved', async () => {
    await assertFails(setDoc(doc(db('nurse'), 'woundAssessments', 'a2'),
      { ...NEW_ASSESSMENT, approvedForTraining: true }));
  });
  test('a new assessment cannot arrive with supervisor feedback', async () => {
    await assertFails(setDoc(doc(db('nurse'), 'woundAssessments', 'a2'),
      { ...NEW_ASSESSMENT, supervisorFeedback: 'Looks fine', hasSupervisorFeedback: true }));
  });
  test('a new assessment cannot arrive already corrected', async () => {
    await assertFails(setDoc(doc(db('nurse'), 'woundAssessments', 'a2'),
      { ...NEW_ASSESSMENT, correctedBy: 'WRN-001' }));
  });
  test('an unverified email cannot create an assessment', async () => {
    await assertFails(setDoc(doc(db('nurse', { verified: false }), 'woundAssessments', 'a2'), NEW_ASSESSMENT));
  });
});

describe('woundAssessments: nurse updates', () => {
  test('a nurse can save notes', async () => {
    await assertSucceeds(updateDoc(doc(db('nurse'), 'woundAssessments', 'a1'), { additionalNotes: 'Cleaned' }));
  });
  test('a nurse can save a TIME correction signed as themself, with server time', async () => {
    await assertSucceeds(updateDoc(doc(db('nurse'), 'woundAssessments', 'a1'), {
      clinicianCorrectedType: 4, correctedBy: 'WRN-001', correctedAt: serverTimestamp(),
    }));
  });
  test('a nurse cannot sign a correction as another nurse', async () => {
    await assertFails(updateDoc(doc(db('nurse'), 'woundAssessments', 'a1'), {
      clinicianCorrectedType: 4, correctedBy: 'WRN-002', correctedAt: serverTimestamp(),
    }));
  });
  test('a nurse cannot back-date a correction', async () => {
    await assertFails(updateDoc(doc(db('nurse'), 'woundAssessments', 'a1'), {
      clinicianCorrectedType: 4, correctedBy: 'WRN-001',
      correctedAt: Timestamp.fromDate(new Date('2020-01-01')),
    }));
  });
  test('a nurse cannot approve an image for training', async () => {
    await assertFails(updateDoc(doc(db('nurse'), 'woundAssessments', 'a1'), {
      approvedForTraining: true, approvedBy: 'WRN-001', approvedAt: serverTimestamp(),
    }));
  });
  test('a nurse cannot reject an image from training', async () => {
    await assertFails(updateDoc(doc(db('nurse'), 'woundAssessments', 'a1'), {
      rejectedForTraining: true, rejectedBy: 'WRN-001', rejectedAt: serverTimestamp(),
    }));
  });
  test('a nurse cannot write supervisor feedback', async () => {
    await assertFails(updateDoc(doc(db('nurse'), 'woundAssessments', 'a1'), { supervisorFeedback: 'Approved' }));
  });
  test('a nurse cannot reassign the supervisor type', async () => {
    await assertFails(updateDoc(doc(db('nurse'), 'woundAssessments', 'a1'), { supervisorCorrectedType: 1 }));
  });
  test('a nurse cannot set the training image path', async () => {
    await assertFails(updateDoc(doc(db('nurse'), 'woundAssessments', 'a1'),
      { trainingImagePath: 'training-data/approved/type_1/x.jpg' }));
  });
  test('a nurse cannot delete an assessment', async () => {
    await assertFails(deleteDoc(doc(db('nurse'), 'woundAssessments', 'a1')));
  });
});

describe('woundAssessments: lecturer and admin', () => {
  test('a lecturer can approve, signed as themself with server time', async () => {
    await assertSucceeds(updateDoc(doc(db('lecturer'), 'woundAssessments', 'a1'), {
      approvedForTraining: true, approvedBy: 'LEC-001', approvedAt: serverTimestamp(),
    }));
  });
  test('a lecturer cannot approve in another lecturer\'s name', async () => {
    await assertFails(updateDoc(doc(db('lecturer'), 'woundAssessments', 'a1'), {
      approvedForTraining: true, approvedBy: 'ADM-001', approvedAt: serverTimestamp(),
    }));
  });
  test('a lecturer can reject with feedback', async () => {
    await assertSucceeds(updateDoc(doc(db('lecturer'), 'woundAssessments', 'a1'), {
      rejectedForTraining: true, rejectedBy: 'LEC-001', rejectedAt: serverTimestamp(),
      supervisorFeedback: 'Blurry', supervisorFeedbackBy: 'LEC-001',
      supervisorFeedbackAt: serverTimestamp(), hasSupervisorFeedback: true,
    }));
  });
  test('a lecturer can delete an assessment', async () => {
    await assertSucceeds(deleteDoc(doc(db('lecturer'), 'woundAssessments', 'a1')));
  });
  test('an admin can delete an assessment', async () => {
    await assertSucceeds(deleteDoc(doc(db('admin'), 'woundAssessments', 'a1')));
  });
});
