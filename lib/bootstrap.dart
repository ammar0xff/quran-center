import 'package:cloud_firestore/cloud_firestore.dart';
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
  }
}
