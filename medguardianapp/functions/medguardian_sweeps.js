/**
 * MedGuardian — dose reminder & missed-dose sweeps (Cloud Functions v2).
 *
 * Add to functions/index.js:
 *   Object.assign(exports, require('./medguardian_sweeps'));
 *
 * What it does, every 5 minutes, even when the elderly user's phone app is
 * closed:
 *   1. 15 minutes before each dose -> push "you can take it now" to the
 *      elderly user's phone(s). (The app only lets a dose be marked taken
 *      from 15 minutes before its time.)
 *   2. 1 hour after a dose that is still pending -> mark it "missed".
 *   3. Any dose that is missed and over 1 hour late -> create ONE alert
 *      users/{uid}/alerts/missed_{doseId}. Your existing alerts onCreate
 *      function then pushes it to every linked caregiver.
 *
 * IMPORTANT: remove/disable any older function that sends the "advance"
 * dose reminder or auto-marks doses missed, otherwise users get duplicates.
 *
 * Needs a collection-group index on doseLogs: status ASC + scheduledTime ASC
 * (the first deploy/run logs a link that creates it in one click).
 */
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

const EARLY_MS = 15 * 60 * 1000; // reminder + earliest "taken"
const MISS_MS = 60 * 60 * 1000; // missed after 1 hour

function uidFromDoseRef(ref) {
  // users/{uid}/doseLogs/{id}
  return ref.parent.parent.id;
}

function fmtTime(date, offsetMinutes) {
  const local = new Date(date.getTime() + (offsetMinutes || 0) * 60000);
  let h = local.getUTCHours();
  const m = String(local.getUTCMinutes()).padStart(2, '0');
  const ampm = h >= 12 ? 'PM' : 'AM';
  h = h % 12 === 0 ? 12 : h % 12;
  return `${h}:${m} ${ampm}`;
}

async function tokensFor(uid) {
  const qs = await db.collection('fcmTokens').where('uid', '==', uid).get();
  return qs.docs.map((d) => d.id);
}

async function push(uid, title, body, target, channel) {
  const tokens = await tokensFor(uid);
  if (!tokens.length) return;
  const res = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: { target, channel },
    android: { priority: 'high', notification: { channelId: channel, sound: 'default' } },
    apns: { payload: { aps: { sound: 'default' } } },
  });
  // Clean up dead tokens.
  await Promise.all(
    res.responses.map((r, i) => {
      const code = r.error && r.error.code;
      if (code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token') {
        return db.collection('fcmTokens').doc(tokens[i]).delete().catch(() => null);
      }
      return null;
    }),
  );
}

const userCache = new Map();
async function userOf(uid) {
  if (userCache.has(uid)) return userCache.get(uid);
  const snap = await db.collection('users').doc(uid).get();
  const data = snap.exists ? snap.data() : {};
  userCache.set(uid, data);
  return data;
}

async function createMissedAlert(uid, doseId, dose) {
  const user = await userOf(uid);
  const who = (user.name || 'Your loved one').trim();
  const when = fmtTime(dose.scheduledTime.toDate(), user.utcOffsetMinutes);
  const ref = db.collection('users').doc(uid).collection('alerts').doc(`missed_${doseId}`);
  try {
    // create() fails if the doc exists -> never duplicates, never resets "acknowledged".
    await ref.create({
      time: admin.firestore.Timestamp.now(),
      type: 'missedDose',
      severity: 'warning',
      title: 'Missed dose',
      message: `${who} has not taken ${dose.medName || 'a medicine'}${dose.dosage ? ` (${dose.dosage})` : ''} scheduled for ${when} — it is now over an hour late.`,
      acknowledged: false,
      lat: null,
      lng: null,
    });
  } catch (e) {
    if (e.code !== 6 /* ALREADY_EXISTS */) throw e;
  }
}

exports.doseSweep = onSchedule({ schedule: 'every 5 minutes', timeZone: 'Etc/UTC', retryCount: 0 }, async () => {
  userCache.clear();
  const now = Date.now();
  const nowTs = admin.firestore.Timestamp.fromMillis(now);

  // 1 + 2: pending doses from 90 min ago up to 15 min from now.
  const pending = await db
    .collectionGroup('doseLogs')
    .where('status', '==', 'pending')
    .where('scheduledTime', '>=', admin.firestore.Timestamp.fromMillis(now - 6 * 60 * 60 * 1000))
    .where('scheduledTime', '<=', admin.firestore.Timestamp.fromMillis(now + EARLY_MS))
    .get();

  for (const doc of pending.docs) {
    const d = doc.data();
    const uid = uidFromDoseRef(doc.ref);
    const at = d.scheduledTime.toMillis();
    try {
      if (now >= at + MISS_MS) {
        await doc.ref.update({ status: 'missed', actionTime: null, autoMissedAt: nowTs });
        await createMissedAlert(uid, doc.id, d);
      } else if (now >= at - EARLY_MS && now < at + MISS_MS && !d.advanceSentAt) {
        const user = await userOf(uid);
        await doc.ref.update({ advanceSentAt: nowTs });
        await push(
          uid,
          `Time for ${d.medName || 'your medicine'}`,
          `${d.dosage ? `${d.dosage} · ` : ''}due at ${fmtTime(d.scheduledTime.toDate(), user.utcOffsetMinutes)}. You can take it now.`,
          'meds',
          'dose_reminders',
        );
      }
    } catch (e) {
      logger.error('doseSweep pending', doc.ref.path, e);
    }
  }

  // 3: doses the user marked "missed" themselves — tell caregivers once the
  // hour has passed.
  const missed = await db
    .collectionGroup('doseLogs')
    .where('status', '==', 'missed')
    .where('scheduledTime', '>=', admin.firestore.Timestamp.fromMillis(now - 6 * 60 * 60 * 1000))
    .where('scheduledTime', '<=', admin.firestore.Timestamp.fromMillis(now - MISS_MS))
    .get();
  for (const doc of missed.docs) {
    try {
      await createMissedAlert(uidFromDoseRef(doc.ref), doc.id, doc.data());
    } catch (e) {
      logger.error('doseSweep missed', doc.ref.path, e);
    }
  }
});
