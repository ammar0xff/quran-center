import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:quran_center/firebase_options.dart';

/// Initializes Firebase before the app starts.
///
/// If Firebase is not configured yet (placeholder options from
/// `flutterfire configure` not run), the app still starts; sign-in then fails
/// with a generic message instead of crashing.
Future<void> bootstrap() async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Firebase initialization failed: $e');
    }
  }
}
