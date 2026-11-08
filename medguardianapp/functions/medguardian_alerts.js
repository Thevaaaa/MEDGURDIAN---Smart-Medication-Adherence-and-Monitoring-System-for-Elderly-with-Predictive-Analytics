/**
 * MedGuardian — push a new alert to every linked caregiver (Cloud Functions v2).
 *
 * Trigger : a document is created in users/{elderlyUid}/alerts/{alertId}
 *           (written by the app for falls / SOS, and by doseSweep for missed doses).
 * Action  : finds every caregiver linked to that elderly user (links where
 *           elderlyId == uid), looks up their device tokens in fcmTokens and
 *           sends a push notification.
 * Evidence: writes pushedAt / pushedCount / pushedStatus back on the alert document,
 *           so you can see in the Firestore Console that the function ran.
 */
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

/** Pure helper (easy to test): the notification a caregiver receives. */
function buildPush(alert, elderlyName) {
  const critical = alert.severity === 'critical' || alert.type === 'fallDetected' || alert.type === 'sos';
  const who = (elderlyName || '').trim();
  const title = alert.title || (critical ? 'Urgent alert' : 'MedGuardian alert');
  let body = (alert.message || '').toString();
  if (who && !body.toLowerCase().includes(who.toLowerCase())) body = `${who}: ${body}`;
  return {
    title: who && critical ? `${title} – ${who}` : title,
    body: body.slice(0, 300),
    channel: critical ? 'critical_alerts' : 'care_updates',
    critical,
  };
}

async function caregiverIdsOf(elderlyUid) {
  const snap = await db.collection('links').where('elderlyId', '==', elderlyUid).get();
  return [...new Set(snap.docs.map((d) => d.data().caregiverId).filter(Boolean))];
}

async function tokensOf(uid) {
  const qs = await db.collection('fcmTokens').where('uid', '==', uid).get();
  return qs.docs.map((d) => d.id);
}

exports.pushCaregiverAlert = onDocumentCreated('users/{uid}/alerts/{alertId}', async (event) => {
  const snap = event.data;
  if (!snap) return;
  const alert = snap.data() || {};
  if (alert.pushedAt) return; // already handled (events can be delivered twice)

  const elderlyUid = event.params.uid;
  const userDoc = await db.collection('users').doc(elderlyUid).get();
  const msg = buildPush(alert, userDoc.exists ? userDoc.data().name : '');

  const caregivers = await caregiverIdsOf(elderlyUid);
  const tokenLists = await Promise.all(caregivers.map(tokensOf));
  const tokens = [...new Set(tokenLists.flat())];

  let status = 'no_caregiver_linked';
  let success = 0;
  if (caregivers.length && !tokens.length) status = 'no_caregiver_device_token';

  if (tokens.length) {
    const res = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title: msg.title, body: msg.body },
      data: { target: 'alerts', channel: msg.channel, alertId: snap.id, elderlyId: elderlyUid, type: String(alert.type || '') },
      android: { priority: 'high', notification: { channelId: msg.channel, sound: 'default' } },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    success = res.successCount;
    status = success ? (res.failureCount ? 'partially_sent' : 'sent') : 'fcm_rejected';
    // Remove tokens that no longer exist.
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

  logger.info('pushCaregiverAlert', { elderlyUid, alertId: snap.id, caregivers: caregivers.length, tokens: tokens.length, success, status });
  await snap.ref.update({
    pushedAt: admin.firestore.FieldValue.serverTimestamp(),
    pushedCount: success,
    pushedStatus: status,
  });
});

exports._buildPush = buildPush; // exported for testing only (underscore: not a deployed function)
