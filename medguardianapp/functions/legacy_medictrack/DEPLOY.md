# Deploying the MedicTrack notification worker

This `functions/` folder is the server-side piece that was missing: it's
what actually sends the FCM push, so a reminder arrives even if MedicTrack
is fully closed, backgrounded, or the phone was rebooted. The Flutter app
already writes everything this worker needs (`dose_events` per user); this
just reads that queue and pushes.

## One-time setup

1. Install the Firebase CLI if you don't have it: `npm install -g firebase-tools`
2. From your **project root** (the folder that contains `lib/`, `pubspec.yaml`, and this `functions/` folder):
   ```
   firebase login
   firebase use <your-firebase-project-id>
   ```
3. If your project doesn't already have a top-level `firebase.json` / `firestore.indexes.json` (FlutterFire CLI usually creates them), run `firebase init` and select **Functions** and **Firestore**, pointing Functions at this existing `functions/` folder when it asks.
4. Merge the contents of `functions/firebase.json.snippet` into your project's `firebase.json`, and `functions/firestore.indexes.json.snippet` into `firestore.indexes.json`. (Delete the `.snippet` files once merged — they're reference only, not consumed directly by the CLI.)
5. **Your project must be on the Blaze (pay-as-you-go) plan.** Scheduled functions require Cloud Scheduler + Pub/Sub, which aren't available on the free Spark plan. For a personal reminder app, actual usage stays well inside Blaze's free monthly quota — you're very unlikely to be billed anything.

## Install & deploy

```
cd functions
npm install
cd ..
firebase deploy --only functions,firestore:indexes
```

The first deploy of `sendDoseReminders` and `extendDoseSchedule` also
provisions their Cloud Scheduler jobs automatically — nothing else to set
up in the Google Cloud Console.

## In-app "Notifications" inbox

`sendDoseReminders` now also writes a doc to the top-level `notifications`
collection (`userId`, `title`, `body`, `type`, `read: false`, `createdAt`)
every time it sends a push — that's what `NotificationService.getUserNotifications()`
/ `getUnreadCount()` read for MedicTrack's own in-app "Notifications" screen.
Before this change the Cloud Function only ever called `admin.messaging()`
directly, which delivers a real OS push but never touches Firestore, so the
in-app inbox stayed on "No Notifications — You're all caught up!" forever
even while real pushes were arriving on the device. If you deployed an
earlier version of this file, redeploy (`firebase deploy --only functions`)
to pick this up — existing dose_events that were already marked
`advanceSentAt`/`exactSentAt` won't retroactively appear in the inbox, only
reminders sent after the redeploy will.

## New: sendRecheckReminders (every 1 minute)

Added to cover the "recheck a high/low BP or sugar reading" workflow
(`VitalsUploadScreen._handleRecheckFlow` writes `users/{uid}.pendingRecheck`).
The in-app countdown sheet only works while the app stays open; this
function sends a real FCM push + in-app notification once the recheck is
due, even if the person closed the app or tapped "I'll recheck later" —
same idea as `sendDoseReminders`. Needs one more composite index (already
added to `firestore.indexes.json.snippet`): `users` collection,
`pendingRecheck.remindedAt` + `pendingRecheck.dueAt`. If you already
deployed an earlier version of `firestore.indexes.json`, re-merge the
snippet and redeploy: `firebase deploy --only functions,firestore:indexes`.

## If a reminder type works but another doesn't — check indexes first

This has already come up twice in this app (the dose reminders and the
dependant-request list): a Firestore query that combines an equality
`where()` with a range filter or `orderBy()` on a different field needs a
**composite index** created ahead of time. Without it, the query doesn't
error loudly — it just returns nothing, forever, with no exception the app
can show you. If one notification type is working (e.g. the health-urgent
push, which uses simpler queries) while another silently never fires (e.g.
`sendDoseReminders`), the very first thing to check is:

```
firebase firestore:indexes
```

and compare against everything in `firestore.indexes.json.snippet`. A
query stuck in "Building" for more than a few minutes, or missing
entirely, means that notification path will never fire until it finishes
or is created. The Firebase console's Firestore → Indexes tab will also
show any index Cloud Functions logs complained about needing, with a
direct "create index" link — `firebase functions:log` after a few minutes
of normal use is the fastest way to confirm which (if any) is still missing.

## What each function does

- **sendDoseReminders** (every 1 minute): scans all users' `dose_events` for
  anything due in the next ~10 minutes (not yet advance-notified), due right
  now (not yet exact-notified), or still unconfirmed 10 minutes **after**
  its due time (not yet late-alerted), and sends a real FCM push for each.
  The late-alert push uses the separate `medicine_alerts` Android channel
  (red/urgent) so it stands out from the two earlier reminders.
- **sweepMissedDoses** (every 1 minute): any dose still `status: 'planned'`
  20 minutes past its due time is updated to `status: 'missed'` server-side.
  There is no manual "skipped" option anywhere in the app by design — a
  dose nobody confirms is simply, eventually, recorded as missed.
- **extendDoseSchedule** (once a day, plus instantly whenever a medicine's
  schedule is created/edited): mirrors the app's own rolling 8-day event
  window server-side, so the queue `sendDoseReminders` reads from keeps
  refilling even if the user never reopens the app for days.

### Reminder/alert/missed timing

| When | What happens |
|---|---|
| 10 min **before** due | "⏰ coming up" push (existing) |
| At due time | "💊 time for X" push (existing) |
| 10 min **after** due, still unconfirmed | 🔴 urgent alert push (`medicine_alerts` channel) + red in-app styling |
| 20 min **after** due, still unconfirmed | Auto-recorded as missed (`sweepMissedDoses`) |

This needs the 2 new composite indexes in `firestore.indexes.json.snippet`
(for `lateSentAt`, and for the `sweepMissedDoses` status+dueAt query) merged
in alongside the existing ones, then `firebase deploy --only functions,firestore:indexes`.

## Verifying it's working

```
firebase functions:log --only sendDoseReminders
```

You should see a line like `sendDoseReminders: 1 advance, 0 exact pushed`
around the time a reminder is due. If `sent` is 0 but `failed` is nonzero,
check that `user_tokens/{uid}.tokens` actually has entries for the device —
that's written by `NotificationService.saveTokenToFirestore()` on login,
which already runs correctly in this app.

## Still needed on the Android side (outside `lib/`, not in this zip)

For the on-device local-alarm fallback and for Android 13+ notification
permission prompts to work, `android/app/src/main/AndroidManifest.xml`
needs:

```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

None of these are required for the FCM push itself to arrive — FCM works
without them — but `POST_NOTIFICATIONS` (Android 13+) is required for
*any* notification, local or push, to actually display once it arrives, so
this is the one to double check if pushes are sending (per the Cloud
Functions logs) but nothing appears on screen.
