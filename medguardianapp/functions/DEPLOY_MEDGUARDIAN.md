# Deploying the MedGuardian Cloud Functions

Functions: `doseSweep` (every 5 minutes) and `pushCaregiverAlert` (on new alert).
Old MedicTrack code is in `legacy_medictrack/` and is not deployed.

Needs: Blaze plan (already on), Firebase CLI, project testdatabase-d0f5b.
Region: set `REGION` in index.js to the Firestore database location.
Index: firestore.indexes.json now has the doseLogs index (status + scheduledTime) that doseSweep needs.
