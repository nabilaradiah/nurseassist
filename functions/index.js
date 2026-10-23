const functions = require('firebase-functions');
const admin     = require('firebase-admin');

admin.initializeApp();

const BUCKET = 'nurseassist-b8242.firebasestorage.app';

/**
 * Triggered when a woundAssessment document is updated.
 * When a supervisor flips approvedForTraining to true, copies the wound image
 * from wound_images/{uid}/ into training-data/approved/type_X/ so the ML
 * training notebooks can pick it up directly by wound type.
 */
exports.copyApprovedWoundImage = functions.region('asia-southeast1').firestore
  .document('woundAssessments/{assessmentId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after  = change.after.data();

    // Only run when approvedForTraining flips false → true
    if (before.approvedForTraining === true) return null;
    if (!after.approvedForTraining)          return null;

    const assessmentId = context.params.assessmentId;

    // Priority: supervisor reassignment > clinician correction > model prediction
    const woundType = after.supervisorCorrectedType ?? after.clinicianCorrectedType ?? after.modelPredictedType;
    if (!woundType) {
      console.error(`[${assessmentId}] No wound type found — skipping copy`);
      return null;
    }

    // Extract the storage path from the Firebase Storage download URL
    // URL format: .../o/wound_images%2F{uid}%2Ffilename.jpg?alt=media&token=...
    const sourcePath = extractStoragePath(after.imageUrl);
    if (!sourcePath) {
      console.error(`[${assessmentId}] Could not parse storage path from imageUrl`);
      return null;
    }

    const filename = sourcePath.split('/').pop();
    const destPath = `training-data/approved/type_${woundType}/${filename}`;

    try {
      const bucket = admin.storage().bucket(BUCKET);
      await bucket.file(sourcePath).copy(bucket.file(destPath));
      console.log(`[${assessmentId}] Copied: ${sourcePath} → ${destPath}`);

      // Save the training path back to Firestore for reference
      await change.after.ref.update({ trainingImagePath: destPath });

      return null;
    } catch (err) {
      console.error(`[${assessmentId}] Copy failed:`, err.message);
      return null;
    }
  });

/**
 * Triggered when a woundAssessment document is deleted — on its own or
 * together with its patient. Deletes the wound photo from Storage so no
 * orphaned patient images are left behind. The client can't do this itself:
 * Storage rules only let the uploading nurse delete their own photos.
 * Copies already approved into training-data/ are kept.
 */
exports.deleteWoundImageOnAssessmentDelete = functions.region('asia-southeast1').firestore
  .document('woundAssessments/{assessmentId}')
  .onDelete(async (snap, context) => {
    const assessmentId = context.params.assessmentId;
    const sourcePath = extractStoragePath(snap.data().imageUrl);
    if (!sourcePath || !sourcePath.startsWith('wound_images/')) {
      console.log(`[${assessmentId}] No wound image to delete`);
      return null;
    }

    try {
      await admin.storage().bucket(BUCKET).file(sourcePath).delete({ ignoreNotFound: true });
      console.log(`[${assessmentId}] Deleted ${sourcePath}`);
    } catch (err) {
      console.error(`[${assessmentId}] Could not delete ${sourcePath}:`, err.message);
    }
    return null;
  });

/**
 * Extracts the decoded storage path from a Firebase Storage download URL.
 * e.g. "https://.../o/wound_images%2Fuid%2Ffile.jpg?alt=media"
 *   →  "wound_images/uid/file.jpg"
 */
function extractStoragePath(imageUrl) {
  try {
    const url   = new URL(imageUrl);
    const match = url.pathname.match(/\/o\/(.+)/);
    if (!match) return null;
    return decodeURIComponent(match[1]);
  } catch {
    return null;
  }
}
