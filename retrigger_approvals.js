/**
 * Re-triggers the copyApprovedWoundImage Cloud Function for assessments
 * that were approved before the function existed.
 * Does this by flipping approvedForTraining false → true.
 */
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const db = admin.firestore();

async function retrigger() {
  const snapshot = await db.collection('woundAssessments')
    .where('approvedForTraining', '==', true)
    .get();

  if (snapshot.empty) {
    console.log('No approved assessments found.');
    process.exit(0);
  }

  console.log(`Found ${snapshot.size} approved assessment(s). Re-triggering...`);

  for (const doc of snapshot.docs) {
    const data = doc.data();
    console.log(`\n[${doc.id}] patient: ${data.patientId}`);

    // Flip to false first
    await doc.ref.update({ approvedForTraining: false });
    console.log(`  → set approvedForTraining = false`);

    // Small delay then flip back to true — this triggers the Cloud Function
    await new Promise(r => setTimeout(r, 1500));
    await doc.ref.update({ approvedForTraining: true });
    console.log(`  → set approvedForTraining = true  (Cloud Function triggered)`);
  }

  console.log('\nDone. Check Firebase Storage in a few seconds.');
  process.exit(0);
}

retrigger().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
