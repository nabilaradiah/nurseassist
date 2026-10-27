/**
 * Tests for storage.rules, run against the local Storage emulator.
 *
 *   npm run test:rules
 */

const fs = require('fs');
const path = require('path');
const { test, before, after, describe } = require('node:test');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { ref, uploadString, getBytes, deleteObject } = require('firebase/storage');

let env;

const storage = (uid) => env.authenticatedContext(uid).storage();
const anon = () => env.unauthenticatedContext().storage();
const IMAGE = 'not really a jpeg';

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-nurseassist',
    storage: {
      // Host and port come from FIREBASE_STORAGE_EMULATOR_HOST, set by emulators:exec
      rules: fs.readFileSync(path.join(__dirname, '../../storage.rules'), 'utf8'),
    },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    await uploadString(ref(ctx.storage(), 'wound_images/nurse/a.jpg'), IMAGE);
    await uploadString(ref(ctx.storage(), 'training-data/approved/type_1/a.jpg'), IMAGE);
  });
});

after(async () => {
  await env?.cleanup();
});

describe('wound_images', () => {
  test('a nurse can upload into their own folder', async () => {
    await assertSucceeds(uploadString(ref(storage('nurse'), 'wound_images/nurse/b.jpg'), IMAGE));
  });
  test("a nurse cannot upload into another nurse's folder", async () => {
    await assertFails(uploadString(ref(storage('nurse2'), 'wound_images/nurse/c.jpg'), IMAGE));
  });
  test('any signed-in user can view a wound image', async () => {
    await assertSucceeds(getBytes(ref(storage('nurse2'), 'wound_images/nurse/a.jpg')));
  });
  test('signed-out users cannot view wound images', async () => {
    await assertFails(getBytes(ref(anon(), 'wound_images/nurse/a.jpg')));
  });
  test("a nurse cannot delete another nurse's image", async () => {
    await assertFails(deleteObject(ref(storage('nurse2'), 'wound_images/nurse/a.jpg')));
  });
});

describe('training-data', () => {
  test('the app cannot read the training set (Cloud Function only)', async () => {
    await assertFails(getBytes(ref(storage('admin'), 'training-data/approved/type_1/a.jpg')));
  });
  test('the app cannot write into the training set', async () => {
    await assertFails(uploadString(ref(storage('admin'), 'training-data/approved/type_1/b.jpg'), IMAGE));
  });
});
