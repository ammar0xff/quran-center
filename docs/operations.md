# Operations

## Running the tests

| What | Command | Needs |
|---|---|---|
| App (unit, widget, flow) | `flutter analyze && flutter test` | Flutter |
| Cloud Functions rule logic | `cd firebase/functions && npm test` | Node 20 |
| Security Rules | `cd firebase/rules-tests && npm test` | Node 20, Java |
| Cloud Functions **end to end** | `cd firebase/rules-tests && npm run test:functions` | Node 20, Java; run `npm test` in `firebase/functions` first so `lib/` is built |

The end-to-end suite starts the Auth, Firestore and Functions emulators, runs the
real functions and the real `firestore.rules`, and checks provisioning, teacher
and student account creation, suspension, cross-center isolation and that new
users cannot escalate.

## Creating the first director of a center

There is deliberately no sign-up screen: a director account can only be created
by an operator with Firebase Admin credentials.

```bash
cd firebase/functions && npm run build
GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json \
  node lib/provisionCli.js \
    --email director@example.com --name "اسم المديرة" \
    --center-id my-center --center-name "اسم الدار"
```

It creates the Auth account (no password), the `role`/`centerId` claims, the
`users/{uid}` profile and the center, and prints a one-time link for the
director to choose a password. It refuses an email that already has an account
and a center id that already exists.

## Before real use (none of this has been done)
1. `flutterfire configure` for the real project (the checked-in
   `firebase_options.dart` is a placeholder).
2. `firebase deploy --only firestore:rules,functions` (build `functions/` first).
3. Create each center's first director with `provisionCli` (above).
4. App Check: the app already activates it (Play Integrity / App Attest; debug
   providers in debug builds). It protects nothing until you register the app
   and turn on **enforcement** for Firestore, Functions and Auth in the console.
5. Crashlytics is wired for release builds only.
6. Push notifications (FCM) are not implemented: notifications are in-app.
7. Set budget alerts; there is no rate limiting beyond Firebase's defaults.

## Working without a connection (teachers)

Attendance and assessments recorded in a session are saved on the device first
(a per-user durable queue, `core/sync/outbox.dart`) and sent in the background:

* the teacher sees their choice immediately, marked "بانتظار المزامنة";
* the queue survives closing the app and is sent when the app starts and
  whenever the connection changes, oldest first;
* changing your mind about a student sends only the final value; sends are
  idempotent (deterministic document ids), so a repeat never duplicates;
* a change the server refuses (for example the session was ended elsewhere) is
  shown with the reason and can be retried or discarded, never silently lost;
* a session cannot be finished while its changes are still waiting, because the
  server would refuse attendance after completion.

Not available offline: starting or finishing a session, and opening a session
whose roster was never loaded on this device. The queue is checked with unit
tests (12) and end-to-end widget tests; it has not been exercised on a real
device or with a real network drop.

## Trying the whole system locally

`scripts/run-demo.sh` starts the Auth, Firestore and Functions emulators, fills
them with a small demo center (a director, a teacher, three students, circles,
a session today, tasks), builds the web app in emulator mode
(`--dart-define=USE_EMULATORS=true`) and serves it on http://127.0.0.1:8765.
Logins: `director@demo.test`, `teacher@demo.test`, `student@demo.test`, password
`demo-pass-123` (emulator only). The page shows an "emulator mode" banner.
This runs the real app against the real Security Rules and Cloud Functions, but
with throwaway data; it is not a deployment.
