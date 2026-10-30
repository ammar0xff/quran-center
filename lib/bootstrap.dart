import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:quran_center/firebase_options.dart';

/// Run against the local Firebase emulators instead of a real project:
/// `flutter run --dart-define=USE_EMULATORS=true` (see docs/operations.md).
const bool useEmulators = bool.fromEnvironment('USE_EMULATORS');

/// Initializes Firebase before the app starts.
///
/// If Firebase is not configured yet (placeholder options from
/// `flutterfire configure` not run), the app still starts; sign-in then fails
/// with a generic message instead of crashing.
Future<void> bootstrap() async {
  if (useEmulators) {
    await _bootstrapEmulators();
    return;
  }
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    // Keep documents already read available offline (the session roster, for
    // example). Writes the teacher makes in a session go through the app's own
    // durable outbox, so they never depend on this cache.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Firebase initialization failed: $e');
    }
    return; // nothing below works without Firebase
  }

  // App Check proves requests come from this app. It only protects anything
  // once enforcement is switched on in the Firebase console (see
  // docs/operations.md); until then it is harmless.
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestProvider(),
    );
  } catch (e) {
    if (kDebugMode) debugPrint('App Check not activated: $e');
  }

  // Crash reports in release builds only; never in debug or tests.
  if (!kDebugMode) {
    try {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (_) {
      // Crash reporting is optional.
    }
  }
}

/// Local development: a throwaway "demo-" project whose Auth, Firestore and
/// Functions are the emulators on this machine. Nothing here can reach real
/// data, and App Check / Crashlytics are skipped.
Future<void> _bootstrapEmulators() async {
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'demo-key',
      appId: '1:1:web:demo',
      messagingSenderId: '1',
      projectId: 'demo-quran-center',
    ),
  );
  const host = '127.0.0.1';
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8189);
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: false);
  FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
}
