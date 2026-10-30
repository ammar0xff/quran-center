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

## Still needed before real use
* `flutterfire configure` (the checked-in `firebase_options.dart` is a placeholder).
* Deploy rules and functions; enable App Check; set budget alerts.
