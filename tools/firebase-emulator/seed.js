/**
 * Seeds the LOCAL Firebase Emulator Suite with test accounts and patients.
 *
 *   node tools/firebase-emulator/seed.js
 *
 * Run it while the emulators are running (see README.md). It wipes the
 * emulators' data first, then loads a known set of test data, so it can be
 * re-run any time to get back to a clean state.
 *
 * Safety: this script only ever talks to the local emulators. It sets the
 * emulator environment variables itself and refuses to run if they point
 * anywhere other than this computer, so it can never write to the real
 * NurseAssist project.
 */

const PROJECT_ID = 'nurseassist-b8242';
const BUCKET = 'nurseassist-b8242.firebasestorage.app';
const LOCAL = '127.0.0.1';

process.env.FIRESTORE_EMULATOR_HOST = `${LOCAL}:8080`;
process.env.FIREBASE_AUTH_EMULATOR_HOST = `${LOCAL}:9099`;
process.env.FIREBASE_STORAGE_EMULATOR_HOST = `${LOCAL}:9199`;
process.env.GCLOUD_PROJECT = PROJECT_ID;

for (const key of [
  'FIRESTORE_EMULATOR_HOST',
  'FIREBASE_AUTH_EMULATOR_HOST',
  'FIREBASE_STORAGE_EMULATOR_HOST',
]) {
  if (!process.env[key].startsWith(`${LOCAL}:`)) {
    console.error(`Refusing to run: ${key} is not local.`);
    process.exit(1);
  }
}

const path = require('path');
const crypto = require('crypto');
const admin = require('firebase-admin');

admin.initializeApp({ projectId: PROJECT_ID, storageBucket: BUCKET });
const db = admin.firestore();
const auth = admin.auth();
const bucket = admin.storage().bucket();

// ── Test accounts (local emulator only) ────────────────────────────────────
// These exist only inside the emulator and are listed in README.md.
const TEST_PASSWORD = 'NurseAssist-Test-2026';
const ACCOUNTS = [
  {
    staffId: 'WRN-T01',
    name: 'Test Nurse',
    email: 'test.nurse@nurseassist.test',
    department: 'Surgical Ward',
    role: 'nurse',
  },
  {
    staffId: 'LEC-T01',
    name: 'Test Lecturer',
    email: 'test.lecturer@nurseassist.test',
    department: 'Kulliyyah of Nursing',
    role: 'lecturer',
  },
];

// Images uploaded to the Storage emulator are served to the Android
// emulator at 10.0.2.2 (the host machine as seen from inside the emulator).
const DEVICE_HOST = process.env.SEED_DEVICE_HOST || '10.0.2.2';

// ── Helpers ────────────────────────────────────────────────────────────────

async function clearEmulators() {
  const fsUrl = `http://${LOCAL}:8080/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
  const authUrl = `http://${LOCAL}:9099/emulator/v1/projects/${PROJECT_ID}/accounts`;
  for (const url of [fsUrl, authUrl]) {
    const res = await fetch(url, { method: 'DELETE' });
    if (!res.ok) throw new Error(`Could not clear ${url}: ${res.status}`);
  }
  const [files] = await bucket.getFiles();
  await Promise.all(files.map((f) => f.delete()));
}

const hoursAgo = (h) => new Date(Date.now() - h * 3600 * 1000).toISOString();
const daysAgo = (d) => hoursAgo(d * 24);

/** Factors for a wound type, per the Wound Care Quick Reference algorithm. */
function factorsFor(type) {
  return { over25: type >= 5, infected: [3, 4, 7, 8].includes(type), wet: type % 2 === 0 };
}

function aiResult(type, confidence, probabilities) {
  const f = factorsFor(type);
  return {
    confidenceScore: confidence,
    woundType: type,
    woundName: `Type_${type}`,
    severity: 'Moderate',
    estimatedSize: null,
    characteristics: {
      necroticTissue: `Necrotic tissue / slough ${f.over25 ? '>' : '<'}25%`,
      infection: f.infected ? 'Presence of infection' : 'No signs of infection',
      exudateLevel: f.wet ? 'Moderate exudates / wet' : 'Dry / minimal exudates',
      tissueClassification: [],
    },
    management: {
      dressingMaterials: [],
      antibioticRecommendation: '',
      surgicalProcedures: [],
      additionalNotes: null,
    },
    segmentationMapUrl: null,
    allClassProbabilities: probabilities,
  };
}

function assessment({ id, patientId, aiType, confidence, probabilities, imageUrl,
  time = null, vitals = null, staffId = 'WRN-T01', at = hoursAgo(3) }) {
  const timeType = time ? time.woundType : null;
  return {
    id,
    patientId,
    imageUrl,
    assessmentDate: at,
    analysisResult: aiResult(aiType, confidence, probabilities),
    additionalNotes: null,
    requiresSpecialistConfirmation: false,
    specialistConfirmed: null,
    modelPredictedType: aiType,
    modelConfidence: confidence,
    clinicianCorrectedType: timeType,
    clinicianCorrectedName: timeType ? `Type_${timeType}` : null,
    correctedBy: timeType ? staffId : null,
    correctedAt: timeType ? at : null,
    approvedForTraining: false,
    approvedBy: null,
    approvedAt: null,
    rejectedForTraining: false,
    rejectedBy: null,
    rejectedAt: null,
    supervisorCorrectedType: null,
    supervisorCorrectedName: null,
    supervisorFeedback: null,
    supervisorFeedbackBy: null,
    supervisorFeedbackAt: null,
    hasSupervisorFeedback: false,
    timeAssessment: time,
    vitals,
  };
}

function timeAssessment({ necrotic, slough, granulation, epithelial, over25,
  infection, moisture, edges, edgeDetails = null, skin = [], at = hoursAgo(3) }) {
  const infected = infection !== 'Nil';
  const wet = moisture === 'Moderate / wet';
  return {
    necroticPct: necrotic,
    sloughPct: slough,
    granulationPct: granulation,
    epithelialPct: epithelial,
    necroticSloughOver25: over25,
    infection,
    inflammation: infected ? 'Present' : 'Nil',
    moisture,
    heavyExudate: false,
    edges,
    edgeDetails,
    surroundingSkin: skin,
    surroundingSkinNotes: null,
    assessedBy: 'WRN-T01',
    assessedByName: 'Test Nurse',
    assessedAt: at,
    woundType: (over25 ? 4 : 0) + (infected ? 2 : 0) + (wet ? 2 : 1),
  };
}

async function uploadSampleImage(fileName) {
  const source = path.join(__dirname, '..', '..', 'assets', 'images', 'app_icon.png');
  const token = crypto.randomUUID();
  const dest = `wound_images/test-seed/${fileName}`;
  await bucket.upload(source, {
    destination: dest,
    metadata: {
      contentType: 'image/png',
      metadata: { firebaseStorageDownloadTokens: token },
    },
  });
  return `http://${DEVICE_HOST}:9199/v0/b/${BUCKET}/o/${encodeURIComponent(dest)}?alt=media&token=${token}`;
}

// ── Seed ───────────────────────────────────────────────────────────────────

async function main() {
  console.log('Clearing local emulator data…');
  await clearEmulators();

  console.log('Creating test accounts…');
  for (const a of ACCOUNTS) {
    const user = await auth.createUser({
      email: a.email,
      password: TEST_PASSWORD,
      displayName: a.name,
      emailVerified: true,
    });
    await db.collection('staff').doc(a.staffId).set({
      staffId: a.staffId,
      name: a.name,
      department: a.department,
      email: a.email,
      role: a.role,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await db.collection('roles').doc(user.uid).set({ role: a.role, staffId: a.staffId });
    await db.collection('staffLookup').doc(a.staffId).set({ email: a.email, uid: user.uid });
  }

  console.log('Uploading a sample wound image…');
  const imageUrl = await uploadSampleImage('sample-wound.png');

  console.log('Creating test patients and assessments…');
  const patients = [
    {
      // Has an allergy that clashes with Type 8 dressings, recent vitals,
      // one untouched AI result and one nurse-vs-AI disagreement.
      id: 'test-patient-a',
      mrn: 'TEST-001',
      name: 'Test Patient A',
      age: 64,
      gender: 'Female',
      contact: '012-000 0001',
      registeredDate: daysAgo(10),
      woundAssessmentIds: ['test-a1', 'test-a2'],
      staffIdAssignedTo: 'WRN-T01',
      phone: null,
      addressRoom: 'Ward 5, Bed 12',
      allergies: 'Povidone-iodine',
      medications: 'Metformin 500mg BD, Amlodipine 5mg OD',
      chronicConditions: [
        { id: 'cc-1', name: 'Type 2 Diabetes', diagnosedDate: '2019-03-01T00:00:00.000', isApproximate: false },
        { id: 'cc-2', name: 'Hypertension', diagnosedDate: null, isApproximate: false },
      ],
      vitalReadings: [
        {
          systolic: 132, diastolic: 84, heartRate: 92, spo2: 97, temperature: 37.2,
          rbs: 9.4, painScore: 4, takenAt: hoursAgo(2),
          takenBy: 'WRN-T01', takenByName: 'Test Nurse',
        },
      ],
      emergencyContactName: 'Test Contact A',
      emergencyContactRelationship: 'Daughter',
      emergencyContactPhone: '012-000 1001',
    },
    {
      // "NKDA" must NOT show as an allergy; no vitals yet.
      id: 'test-patient-b',
      mrn: 'TEST-002',
      name: 'Test Patient B',
      age: 47,
      gender: 'Male',
      contact: '012-000 0002',
      registeredDate: daysAgo(4),
      woundAssessmentIds: ['test-b1'],
      staffIdAssignedTo: 'WRN-T01',
      phone: null,
      addressRoom: 'Ward 3, Bed 4',
      allergies: 'NKDA',
      medications: null,
      chronicConditions: [],
      vitalReadings: [],
      emergencyContactName: null,
      emergencyContactRelationship: null,
      emergencyContactPhone: null,
    },
  ];
  for (const p of patients) await db.collection('patients').doc(p.id).set(p);

  const assessments = [
    // No TIME yet: shows AI suggestions; iodine allergy conflicts with Type 8
    assessment({
      id: 'test-a1', patientId: 'test-patient-a', aiType: 8, confidence: 0.81,
      probabilities: [0, 0.01, 0.02, 0.04, 0.02, 0.06, 0.04, 0.81],
      imageUrl, at: hoursAgo(1),
    }),
    // Nurse TIME gives Type 8, AI said Type 6 → disagreement for the lecturer
    assessment({
      id: 'test-a2', patientId: 'test-patient-a', aiType: 6, confidence: 0.7,
      probabilities: [0, 0, 0, 0, 0.1, 0.7, 0.05, 0.15], imageUrl, at: daysAgo(1),
      time: timeAssessment({
        necrotic: 30, slough: 20, granulation: 50, epithelial: null, over25: true,
        infection: 'Local signs', moisture: 'Moderate / wet', edges: 'Undermining',
        edgeDetails: "12–3 o'clock, 2 cm", skin: ['Erythema', 'Maceration'], at: daysAgo(1),
      }),
      vitals: {
        systolic: 128, diastolic: 82, heartRate: 104, spo2: 96, temperature: 38.4,
        rbs: 11.8, painScore: 6, takenAt: daysAgo(1),
        takenBy: 'WRN-T01', takenByName: 'Test Nurse',
      },
    }),
    // Nurse agrees with the AI (Type 2)
    assessment({
      id: 'test-b1', patientId: 'test-patient-b', aiType: 2, confidence: 0.9,
      probabilities: [0.03, 0.9, 0.02, 0.02, 0.01, 0.01, 0.005, 0.005], imageUrl,
      at: daysAgo(2),
      time: timeAssessment({
        necrotic: 0, slough: 10, granulation: 70, epithelial: 20, over25: false,
        infection: 'Nil', moisture: 'Moderate / wet', edges: 'Attached',
        skin: ['Intact'], at: daysAgo(2),
      }),
    }),
  ];
  for (const a of assessments) await db.collection('woundAssessments').doc(a.id).set(a);

  console.log('\nDone. Local test data is ready:');
  console.log('  Logins: see tools/firebase-emulator/README.md');
  console.log('  Emulator UI: http://127.0.0.1:4000');
}

main().catch((err) => {
  console.error('\nSeeding failed:', err.message);
  console.error('Are the emulators running? Start them first (see README.md).');
  process.exit(1);
});
