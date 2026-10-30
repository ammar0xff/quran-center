import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:quran_center/firebase_options.dart';

/// Initializes Firebase before the app starts.
///
/// If Firebase is not configured yet (placeholder options from
/// `flutterfire configure` not run), the app still starts; sign-in then fails
/// with a generic message instead of crashing.
Future<void> bootstrap() async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
      providerAndroid:
          kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode ? const AppleDebugProvider() : const AppleAppAttestProvider(),
    );
  } catch (e) {
    if (kDebugMode) debugPrint('App Check not activated: $e');
  }

  // Crash reports in release builds only; never in debug or tests.
  if (!kDebugMode) {
    try {
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (_) {
      // Crash reporting is optional.
    }
  }
}
