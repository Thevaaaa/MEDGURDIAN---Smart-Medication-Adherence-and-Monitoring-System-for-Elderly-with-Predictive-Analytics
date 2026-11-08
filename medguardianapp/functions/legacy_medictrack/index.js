/**
 * MedicTrack — Cloud Functions worker
 * ════════════════════════════════════════════════════════════════════════
 * This is the missing server-side half of the reminder system. The Flutter
 * app (lib/services/dose_service.dart) already:
 *   1. Watches each user's `medicines` docs for schedules with
 *      trackingEnabled == true and a scheduleTimes list.
 *   2. Writes one `users/{uid}/dose_events/{medicineId}_{dueAtMs}` doc per
 *      upcoming dose, for the next ~8 days, with `dueAt`, `status: 'planned'`,
 *      `advanceSentAt: null`, `exactSentAt: null`.
 *   3. Also arms *local* device alarms (flutter_local_notifications) as a
 *      same-device fallback — those only fire while the OS hasn't killed
 *      the alarm and the app has synced recently.
 *
 * What was missing: nothing was actually reading `dose_events` and pushing
 * a real FCM message. That's this file. Because FCM pushes are sent from a
 * server via the Admin SDK, they are delivered by Google's push
 * infrastructure regardless of whether the MedicTrack app process is
 * running, backgrounded, or the phone was rebooted — which is what
 * "notify me even if the app is closed" actually requires.
 *
 * Two functions:
 *   • sendDoseReminders  — runs every 1 minute. Finds dose_events due in the
 *     next ~10 minutes (not yet advance-notified) and due now (not yet
 *     exact-notified), and sends the FCM push for each.
 *   • extendDoseSchedule — runs once a day (+ once on every medicine write)
 *     and mirrors the client's own rolling-window scheduling logic so the
 *     `dose_events` queue keeps refilling even if the user never reopens
 *     the app for days. Without this, sendDoseReminders would eventually
 *     run out of upcoming events to notify about.
 *
 * Deploy:
 *   cd functions && npm install
 *   firebase deploy --only functions
 * Requires the Firebase project to be on the Blaze (pay-as-you-go) plan —
 * scheduled functions (Cloud Scheduler + Pub/Sub) are not available on the
 * free Spark plan. In practice, for a personal reminder app, this runs
 * comfortably within the free monthly quota of the Blaze plan.
 * ════════════════════════════════════════════════════════════════════════
 */

const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

setGlobalOptions({ region: 'us-central1', maxInstances: 10 });

const ADVANCE_MINUTES = 10;
const ROLLING_WINDOW_DAYS = 8;
// A dose unconfirmed 10 minutes PAST its due time gets a second, more
// urgent push (distinct from the ADVANCE_MINUTES-before reminder); one
// unconfirmed 20 minutes past due is swept into status: 'missed'. These
// mirror DoseService.alertGrace / DoseService.missedGrace on the client.
const LATE_ALERT_MINUTES = 10;
const MISSED_MINUTES = 20;

// ── Helpers ────────────────────────────────────────────────────────────────

function tsFromMs(ms) {
  return admin.firestore.Timestamp.fromMillis(ms);
}

/** Builds the FCM payload for a dose_events doc. `kind` is one of
 *  'advance' (10 min before), 'exact' (at due time), or 'late' (10 min
 *  after, still unconfirmed — the red/urgent alert tier). */
function buildMessage({ tokens, kind, medicineName, dosage, assignedToName, medicineId, eventId, uid }) {
  const dosagePart = dosage ? ` (${dosage})` : '';
  const forWhom = assignedToName && assignedToName !== 'Me' ? ` for ${assignedToName}` : '';
  let title, body;
  if (kind === 'advance') {
    title = `⏰ ${medicineName} in ${ADVANCE_MINUTES} minutes`;
    body = `Coming up in ${ADVANCE_MINUTES} minutes${dosagePart}${forWhom}. Get it ready.`;
  } else if (kind === 'late') {
    title = `🔴 ALERT: ${medicineName} not confirmed`;
    body = `Still not confirmed ${LATE_ALERT_MINUTES} minutes after the scheduled time${forWhom}. ` +
      `It will be recorded as missed in ${MISSED_MINUTES - LATE_ALERT_MINUTES} more minutes.`;
  } else {
    title = `💊 Time for ${medicineName}`;
    body = `Take it now${dosagePart}${forWhom}. Open MedicTrack to record this dose.`;
  }

  return {
    tokens,
    notification: { title, body },
    data: {
      type: kind === 'advance' ? 'reminder_advance' : kind === 'late' ? 'reminder_alert' : 'reminder',
      medicineId: medicineId || '',
      eventId,
      userId: uid,
    },
    android: {
      priority: 'high',
      notification: {
        channelId: kind === 'late' ? 'medicine_alerts' : 'medicine_reminders',
        sound: 'default',
        priority: 'max',
        color: kind === 'late' ? '#C0392B' : undefined,
      },
    },
    apns: {
      payload: { aps: { sound: 'default', contentAvailable: true } },
    },
  };
}

/** Writes a doc to the top-level `notifications` collection so MedicTrack's
 *  own in-app "Notifications" inbox (NotificationService.getUserNotifications
 *  / getUnreadCount, which only ever reads that collection) shows dose
 *  reminders too — a raw admin.messaging() push never touches Firestore, so
 *  without this the inbox stayed permanently empty even while real FCM
 *  pushes were arriving on the device.
 */
async function logInAppNotification(uid, kind, eventDoc) {
  const d = eventDoc.data();
  const dosagePart = d.dosage ? ` (${d.dosage})` : '';
  const forWhom = d.assignedToName && d.assignedToName !== 'Me' ? ` for ${d.assignedToName}` : '';
  let title, body, type;
  if (kind === 'advance') {
    title = `⏰ ${d.medicineName || 'Medicine'} in ${ADVANCE_MINUTES} minutes`;
    body = `Coming up in ${ADVANCE_MINUTES} minutes${dosagePart}${forWhom}. Get it ready.`;
    type = 'reminder_advance';
  } else if (kind === 'late') {
    title = `🔴 ALERT: ${d.medicineName || 'Medicine'} not confirmed`;
    body = `Still not confirmed ${LATE_ALERT_MINUTES} minutes after the scheduled time${forWhom}.`;
    type = 'reminder_alert';
  } else {
    title = `💊 Time for ${d.medicineName || 'Medicine'}`;
    body = `Take it now${dosagePart}${forWhom}. Open MedicTrack to record this dose.`;
    type = 'reminder';
  }

  await db.collection('notifications').add({
    userId: uid,
    type,
    title,
    body,
    payload: `dose:${d.medicineId || ''}`,
    medicineId: d.medicineId || '',
    eventId: eventDoc.id,
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }).catch((e) => console.warn(`Could not log in-app notification for ${uid}/${eventDoc.id}:`, e.message));
}

/** Sends one FCM push and prunes any tokens the device has invalidated. */
async function sendAndPrune(uid, tokens, kind, eventDoc) {
  // Log to the in-app inbox regardless of whether a push token exists —
  // the user should still see the reminder in-app even if delivery to the
  // device itself is temporarily impossible (e.g. tokens not yet saved).
  await logInAppNotification(uid, kind, eventDoc);

  if (!tokens || tokens.length === 0) {
    console.warn(`⚠️ No FCM tokens for user ${uid} — cannot deliver ${kind} push for ${eventDoc.id}`);
    return;
  }
  const d = eventDoc.data();
  const message = buildMessage({
    tokens,
    kind,
    medicineName: d.medicineName || 'Medicine',
    dosage: d.dosage,
    assignedToName: d.assignedToName,
    medicineId: d.medicineId,
    eventId: eventDoc.id,
    uid,
  });

  const res = await admin.messaging().sendEachForMulticast(message);
  console.log(`📤 ${kind} push for ${eventDoc.id}: ${res.successCount} sent, ${res.failureCount} failed`);

  const deadTokens = [];
  res.responses.forEach((r, i) => {
    if (!r.success) {
      const code = r.error && r.error.code;
      if (code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token') {
        deadTokens.push(tokens[i]);
      }
    }
  });
  if (deadTokens.length) {
    await db.collection('user_tokens').doc(uid).update({
      tokens: admin.firestore.FieldValue.arrayRemove(...deadTokens),
    }).catch((e) => console.warn(`Could not prune dead tokens for ${uid}:`, e.message));
  }
}

// ── sendDoseReminders — every 1 minute ──────────────────────────────────────
exports.sendDoseReminders = onSchedule('every 1 minutes', async () => {
  const now = Date.now();

  const advanceFrom = tsFromMs(now + (ADVANCE_MINUTES - 1) * 60 * 1000);
  const advanceTo = tsFromMs(now + (ADVANCE_MINUTES + 1) * 60 * 1000);
  const exactFrom = tsFromMs(now - 2 * 60 * 1000);
  const exactTo = tsFromMs(now + 1 * 60 * 1000);
  // "Late" fires LATE_ALERT_MINUTES after dueAt, i.e. dueAt is now further
  // in the past — hence the window is `now - (LATE_ALERT_MINUTES + 1..-1)`.
  const lateFrom = tsFromMs(now - (LATE_ALERT_MINUTES + 1) * 60 * 1000);
  const lateTo = tsFromMs(now - (LATE_ALERT_MINUTES - 1) * 60 * 1000);

  const [advanceSnap, exactSnap, lateSnap] = await Promise.all([
    db.collectionGroup('dose_events')
      .where('status', '==', 'planned')
      .where('advanceSentAt', '==', null)
      .where('dueAt', '>=', advanceFrom)
      .where('dueAt', '<=', advanceTo)
      .get(),
    db.collectionGroup('dose_events')
      .where('status', '==', 'planned')
      .where('exactSentAt', '==', null)
      .where('dueAt', '>=', exactFrom)
      .where('dueAt', '<=', exactTo)
      .get(),
    db.collectionGroup('dose_events')
      .where('status', '==', 'planned')
      .where('lateSentAt', '==', null)
      .where('dueAt', '>=', lateFrom)
      .where('dueAt', '<=', lateTo)
      .get(),
  ]);

  // Cache tokens + the medicineReminders preference per user within this run.
  const tokenCache = new Map();
  async function tokensFor(uid) {
    if (tokenCache.has(uid)) return tokenCache.get(uid);
    const doc = await db.collection('user_tokens').doc(uid).get();
    const tokens = doc.exists ? (doc.data().tokens || []) : [];
    tokenCache.set(uid, tokens);
    return tokens;
  }
  const prefCache = new Map();
  async function remindersEnabledFor(uid) {
    if (prefCache.has(uid)) return prefCache.get(uid);
    const doc = await db.collection('users').doc(uid).collection('settings').doc('notifications').get();
    // Mirrors dose_service.dart's own default: absent/undefined means ON.
    const enabled = doc.data()?.medicineReminders !== false;
    prefCache.set(uid, enabled);
    return enabled;
  }

  const writes = [];

  for (const doc of advanceSnap.docs) {
    const uid = doc.ref.parent.parent.id;
    if (await remindersEnabledFor(uid)) {
      const tokens = await tokensFor(uid);
      await sendAndPrune(uid, tokens, 'advance', doc);
    }
    writes.push(doc.ref.update({ advanceSentAt: admin.firestore.FieldValue.serverTimestamp() }));
  }

  for (const doc of exactSnap.docs) {
    const uid = doc.ref.parent.parent.id;
    if (await remindersEnabledFor(uid)) {
      const tokens = await tokensFor(uid);
      await sendAndPrune(uid, tokens, 'exact', doc);
    }
    writes.push(doc.ref.update({ exactSentAt: admin.firestore.FieldValue.serverTimestamp() }));
  }

  // Late alerts fire regardless of the `medicineReminders` preference toggle
  // (same as advance/exact) but only for doses STILL 'planned' at +10 min —
  // the query itself already excludes anything already recorded taken.
  for (const doc of lateSnap.docs) {
    const uid = doc.ref.parent.parent.id;
    if (await remindersEnabledFor(uid)) {
      const tokens = await tokensFor(uid);
      await sendAndPrune(uid, tokens, 'late', doc);
    }
    writes.push(doc.ref.update({ lateSentAt: admin.firestore.FieldValue.serverTimestamp() }));
  }

  await Promise.all(writes);
  console.log(`✅ sendDoseReminders: ${advanceSnap.size} advance, ${exactSnap.size} exact, ${lateSnap.size} late-alert pushed`);
});

// ── sweepMissedDoses — every 1 minute ───────────────────────────────────────
// A dose still 'planned' MISSED_MINUTES past its due time is recorded as
// missed automatically — there is no manual "skipped" option anywhere in
// the app; a dose that's never confirmed is simply, eventually, missed.
// This runs server-side (rather than relying on DoseService.status()'s
// client-side fallback) so the `status` field itself is correct in
// Firestore for adherence scoring even if the app is never reopened.
exports.sweepMissedDoses = onSchedule('every 1 minutes', async () => {
  const cutoff = tsFromMs(Date.now() - MISSED_MINUTES * 60 * 1000);
  const snap = await db.collectionGroup('dose_events')
    .where('status', '==', 'planned')
    .where('dueAt', '<=', cutoff)
    .get();

  if (snap.empty) return;
  const batch = db.batch();
  snap.docs.forEach((doc) => batch.update(doc.ref, {
    status: 'missed',
    missedAt: admin.firestore.FieldValue.serverTimestamp(),
  }));
  await batch.commit();
  console.log(`⚠️ sweepMissedDoses: ${snap.size} dose(s) auto-recorded as missed`);
});

// ── Rolling-window scheduling (server-side mirror of dose_service.dart) ────

/** Parses "HH:mm" into [hour, minute]. Returns null if invalid. */
function parseHHmm(time) {
  const m = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(time || '');
  if (!m) return null;
  return [parseInt(m[1], 10), parseInt(m[2], 10)];
}

/** Ensures dose_events exist for one medicine's schedule for the next
 *  ROLLING_WINDOW_DAYS days. Never overwrites an existing event (so a
 *  recorded 'taken'/'skipped' status, or a still-pending one, is untouched).
 */
async function syncMedicineEvents(uid, medicineId, m) {
  if (m.trackingEnabled !== true) return;
  const times = Array.from(new Set(m.scheduleTimes || []));
  if (times.length === 0) return;

  const now = new Date();
  const batch = db.batch();
  let writes = 0;

  for (const time of times) {
    const parsed = parseHHmm(time);
    if (!parsed) continue;
    const [hour, minute] = parsed;

    for (let day = 0; day < ROLLING_WINDOW_DAYS; day++) {
      const due = new Date(now.getFullYear(), now.getMonth(), now.getDate() + day, hour, minute, 0, 0);
      if (due.getTime() < now.getTime()) continue;

      const eventId = `${medicineId}_${due.getTime()}`;
      const ref = db.collection('users').doc(uid).collection('dose_events').doc(eventId);
      const existing = await ref.get();
      if (existing.exists) continue;

      batch.set(ref, {
        medicineId,
        medicineName: m.medicineName || 'Medicine',
        dosage: m.dosage || '',
        assignedTo: m.assignedTo || 'me',
        assignedToName: m.assignedToName || 'Me',
        scheduledTime: time,
        dueAt: admin.firestore.Timestamp.fromDate(due),
        status: 'planned',
        plan: `server:${time}`,
        advanceSentAt: null,
        exactSentAt: null,
        lateSentAt: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      writes++;
    }
  }

  if (writes > 0) {
    await batch.commit();
    console.log(`🔁 extendDoseSchedule: created ${writes} event(s) for medicine ${medicineId} (user ${uid})`);
  }
}

// Runs once a day for every tracked medicine — keeps the rolling window
// filled even if the user never reopens the app.
exports.extendDoseSchedule = onSchedule('every 24 hours', async () => {
  const meds = await db.collection('medicines').where('trackingEnabled', '==', true).get();
  for (const doc of meds.docs) {
    const m = doc.data();
    if (!m.userId) continue;
    await syncMedicineEvents(m.userId, doc.id, m).catch((e) =>
      console.warn(`extendDoseSchedule failed for medicine ${doc.id}:`, e.message));
  }
  console.log(`✅ extendDoseSchedule: checked ${meds.size} tracked medicines`);
});

// Also extend immediately whenever a medicine's own schedule changes, so a
// newly-created or newly-enabled reminder gets its first events right away
// instead of waiting up to 24h for the next scheduled run.
exports.onMedicineScheduleChanged = onDocumentWritten('medicines/{medicineId}', async (event) => {
  const after = event.data.after.exists ? event.data.after.data() : null;
  if (!after || after.trackingEnabled !== true || !after.userId) return;
  await syncMedicineEvents(after.userId, event.params.medicineId, after);
});

// ── sendRecheckReminders — every 1 minute ───────────────────────────────────
// The Flutter app writes `users/{uid}.pendingRecheck` (see
// vitals_upload_screen.dart `_handleRecheckFlow`) whenever a high/low BP or
// sugar reading needs a follow-up recheck (1–3 min for BP, ~30 min for
// sugar). The in-app countdown sheet is enough while the person keeps the
// app open, but if they tap "I'll recheck later" — or just leave/close the
// app — nothing ever reminded them again. This mirrors sendDoseReminders:
// once `pendingRecheck.dueAt` has passed and it hasn't been reminded yet,
// send a real FCM push (works even if the app is fully closed) plus an
// in-app notification, then mark `remindedAt` so it only fires once. The
// marker itself is only cleared by the client once the recheck is actually
// saved — this function never clears it, it just reminds.
exports.sendRecheckReminders = onSchedule('every 1 minutes', async () => {
  const now = Date.now();
  const snap = await db.collection('users')
    .where('pendingRecheck.remindedAt', '==', null)
    .where('pendingRecheck.dueAt', '<=', tsFromMs(now))
    .get();
  if (snap.empty) return;

  for (const doc of snap.docs) {
    const uid = doc.id;
    const pending = doc.data().pendingRecheck;
    if (!pending) continue;
    const type = pending.type === 'bloodPressure' ? 'blood pressure' : 'blood sugar';
    const direction = pending.direction === 'low' ? 'low' : 'high';
    const title = `⏰ Time to recheck your ${type}`;
    const body = `Your earlier ${type} reading was ${direction}. Open MedicTrack to recheck it now.`;

    const tokenDoc = await db.collection('user_tokens').doc(uid).get();
    const tokens = tokenDoc.exists ? (tokenDoc.data().tokens || []) : [];

    await db.collection('notifications').add({
      userId: uid, type: 'recheck_due', title, body,
      payload: `recheck:${pending.type || ''}`,
      read: false, createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }).catch((e) => console.warn(`Could not log recheck notification for ${uid}:`, e.message));

    if (tokens.length) {
      await admin.messaging().sendEachForMulticast({
        tokens,
        notification: { title, body },
        data: { type: 'recheck_due', recheckType: pending.type || '', userId: uid },
        android: { priority: 'high', notification: { channelId: 'health_urgent', sound: 'default', priority: 'max' } },
        apns: { payload: { aps: { sound: 'default', contentAvailable: true } } },
      }).catch((e) => console.warn(`Could not push recheck reminder for ${uid}:`, e.message));
    } else {
      console.warn(`⚠️ No FCM tokens for user ${uid} — recheck reminder logged in-app only`);
    }

    await doc.ref.update({ 'pendingRecheck.remindedAt': admin.firestore.FieldValue.serverTimestamp() })
      .catch((e) => console.warn(`Could not mark recheck reminded for ${uid}:`, e.message));
  }
  console.log(`✅ sendRecheckReminders: ${snap.size} reminder(s) sent`);
});

Object.assign(exports, require('./health_monitoring'));
