import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/firebase_options.dart';

// Provider container exposed for tests and root scope.
final container = ProviderContainer();

/// Initializes Firebase and the Riverpod provider container.
/// Call once before runApp.
Future<void> bootstrap() async {
  // Firebase initialization. In production this uses real project config.
  // If config is missing (placeholders), initialization still succeeds so the
  // app can show the configured config-error state rather than crashing.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Firebase initialization warning: $e');
    }
  }

  // Firebase App Check + Crashlytics would be wired here once real config exists.
}
