/**
 * MedGuardian — Cloud Functions entry point.
 *
 * Deployed functions:
 *   doseSweep           (medguardian_sweeps.js)  every 5 min: 15-min-before reminder push, marks doses
 *                                                 missed after 1 h, creates the missed-dose alert.
 *   pushCaregiverAlert  (medguardian_alerts.js)  when users/{uid}/alerts/{id} is created: push to
 *                                                 every linked caregiver (fall, SOS, missed dose).
 *
 * REGION: use the same location as your Firestore database (Firebase Console >
 * Firestore Database > Data, or Project settings > General > "Default GCP resource
 * location"). Change the value below if it is not us-central1.
 *
 * The old MedicTrack functions (dose_events / medicines / user_tokens) were moved to
 * functions/legacy_medictrack/ and are NOT deployed.
 */
const { setGlobalOptions } = require('firebase-functions/v2');
const REGION = 'us-central1';
setGlobalOptions({ region: REGION, maxInstances: 10 });

const alerts = require('./medguardian_alerts');
const sweeps = require('./medguardian_sweeps');

exports.doseSweep = sweeps.doseSweep;
exports.pushCaregiverAlert = alerts.pushCaregiverAlert;
