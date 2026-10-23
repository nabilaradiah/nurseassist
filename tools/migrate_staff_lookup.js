/**
 * One-off migration: creates staffLookup/{STAFF_ID} → { email, uid } for every
 * existing staff/ record, so existing accounts can still log in by Staff ID
 * once the new firestore.rules (staff/ no longer public) are deployed.
 *
 *   node tools/migrate_staff_lookup.js path/to/serviceAccountKey.json
 *
 * Run it BEFORE deploying the new rules. Safe to re-run: existing lookup
 * documents are left alone. Uses the Admin SDK, so it bypasses the rules.
 */

const admin = require('firebase-admin');

const keyPath = process.argv[2];
if (!keyPath) {
  console.error('Usage: node tools/migrate_staff_lookup.js path/to/serviceAccountKey.json');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(require(require('path').resolve(keyPath))),
});
const db = admin.firestore();
const auth = admin.auth();

async function migrate() {
  const staff = await db.collection('staff').get();
  let created = 0;
  for (const doc of staff.docs) {
    const { staffId, email } = doc.data();
    if (!staffId || !email || staffId.includes('/')) {
      console.warn(`[${doc.id}] skipped — missing staffId/email`);
      continue;
    }
    const ref = db.collection('staffLookup').doc(staffId.toUpperCase());
    if ((await ref.get()).exists) continue;

    let uid;
    try {
      uid = (await auth.getUserByEmail(email)).uid;
    } catch {
      console.warn(`[${staffId}] skipped — no Auth account for ${email}`);
      continue;
    }
    await ref.set({ email: email.toLowerCase(), uid });
    created++;
    console.log(`[${staffId}] → ${email}`);
  }
  console.log(`\nDone. Created ${created} lookup document(s).`);
}

migrate().then(() => process.exit(0)).catch((err) => {
  console.error('Migration failed:', err.message);
  process.exit(1);
});
