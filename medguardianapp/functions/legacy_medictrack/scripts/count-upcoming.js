#!/usr/bin/env node
/**
 * Terminal tool: counts upcoming medication and appointment reminders that
 * MedGuardian's `sendReminders` job will fire in a given time window.
 *
 * Setup (one-time):
 *   gcloud auth application-default login --project=YOUR_PROJECT_ID
 *
 * Usage (from the `functions/` folder):
 *   node scripts/count-upcoming.js                  # next 24 hours, all users
 *   node scripts/count-upcoming.js --hours=6         # next 6 hours
 *   node scripts/count-upcoming.js --uid=abc123      # one user only
 *   node scripts/count-upcoming.js --project=testdatabase-d0f5b   # override project
 */
const admin = require('firebase-admin');

const args = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const [k, v] = a.replace(/^--/, '').split('=');
    return [k, v ?? true];
  })
);

const hours = Number(args.hours) || 24;
const filterUid = args.uid || null;
const projectId = args.project || process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;

admin.initializeApp(projectId ? { projectId } : undefined);
const db = admin.firestore();

async function main() {
  const now = new Date();
  const until = new Date(now.getTime() + hours * 60 * 60 * 1000);
  const nowTs = admin.firestore.Timestamp.fromDate(now);
  const untilTs = admin.firestore.Timestamp.fromDate(until);

  console.log(`\nProject: ${projectId || '(default from credentials)'}`);
  console.log(`Window:  now \u2192 +${hours}h  (${now.toISOString()} \u2192 ${until.toISOString()})`);
  if (filterUid) console.log(`Filter:  uid = ${filterUid}`);
  console.log('');

  // ── Medication doses ────────────────────────────────────────────────
  const doseSnap = await db
    .collectionGroup('doseLogs')
    .where('scheduledTime', '>=', nowTs)
    .where('scheduledTime', '<=', untilTs)
    .get();

  const doseByUser = new Map();
  for (const doc of doseSnap.docs) {
    const uid = doc.ref.parent.parent.id;
    if (filterUid && uid !== filterUid) continue;
    const d = doc.data();
    if (d.status !== 'pending') continue; // already taken/missed — nothing left to send
    if (!doseByUser.has(uid)) doseByUser.set(uid, []);
    doseByUser.get(uid).push(d);
  }

  // ── Appointments ─────────────────────────────────────────────────────
  const apptSnap = await db
    .collectionGroup('appointments')
    .where('dateTime', '>=', nowTs)
    .where('dateTime', '<=', untilTs)
    .get();

  const apptByUser = new Map();
  for (const doc of apptSnap.docs) {
    const uid = doc.ref.parent.parent.id;
    if (filterUid && uid !== filterUid) continue;
    if (!apptByUser.has(uid)) apptByUser.set(uid, []);
    apptByUser.get(uid).push(doc.data());
  }

  const uids = new Set([...doseByUser.keys(), ...apptByUser.keys()]);
  let totalDoses = 0;
  let totalAppts = 0;

  if (uids.size === 0) {
    console.log('No upcoming doses or appointments in this window.');
  } else {
    for (const uid of uids) {
      const doses = doseByUser.get(uid) || [];
      const appts = apptByUser.get(uid) || [];
      totalDoses += doses.length;
      totalAppts += appts.length;

      let name = uid;
      try {
        const u = await db.collection('users').doc(uid).get();
        if (u.exists && u.data().name) name = `${u.data().name} (${uid})`;
      } catch (_) {}

      console.log(`\u2022 ${name}`);
      for (const d of doses.sort((a, b) => a.scheduledTime.toMillis() - b.scheduledTime.toMillis())) {
        console.log(`    dose  ${d.scheduledTime.toDate().toLocaleString()}  ${d.medName || 'medication'}${d.dosage ? ` (${d.dosage})` : ''}`);
      }
      for (const a of appts.sort((x, y) => x.dateTime.toMillis() - y.dateTime.toMillis())) {
        console.log(`    appt  ${a.dateTime.toDate().toLocaleString()}  ${a.title || 'appointment'}${a.location ? ` \u2014 ${a.location}` : ''}`);
      }
    }
  }

  console.log(`\nTotals: ${totalDoses} pending dose reminder(s), ${totalAppts} appointment reminder(s), across ${uids.size} user(s).\n`);
}

main()
  .catch((e) => {
    console.error('\nFailed:', e.message || e);
    if (String(e.message || '').includes('FAILED_PRECONDITION') || String(e.message || '').includes('index')) {
      console.error('This looks like a missing/building Firestore index — check the Firestore \u2192 Indexes tab, or run: firebase deploy --only firestore:indexes');
    }
    process.exitCode = 1;
  })
  .finally(() => process.exit());
