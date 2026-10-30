import 'package:firebase_auth/firebase_auth.dart';

/// A sign-in / reset failure whose message is already user-facing Arabic.
class AuthFailure implements Exception {
  AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Maps a Firebase Auth error code to an Arabic message.
///
/// Wrong password, unknown email and malformed credentials all return the
/// SAME message so the response never reveals whether an account exists.
String authErrorMessage(String code) {
  switch (code) {
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
    case 'invalid-email':
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
    case 'user-disabled':
      return 'تم تعطيل هذا الحساب. تواصل مع إدارة الدار.';
    case 'too-many-requests':
      return 'محاولات كثيرة. انتظر قليلًا ثم حاول مرة أخرى.';
    case 'network-request-failed':
      return 'الشبكة غير متاحة. تحقق من اتصالك وحاول مرة أخرى.';
    default:
      return 'حدث خطأ غير متوقع. حاول مرة أخرى.';
  }
}

/// The only thing the app needs from an authentication backend.
abstract class AuthGateway {
  /// Emits the signed-in uid, or null when signed out. Emits the restored
  /// session first on startup.
  Stream<String?> uidChanges();

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();

  /// Requests a password-reset email. Completes normally even when the email
  /// is unknown, so the result never reveals whether an account exists.
  Future<void> sendPasswordReset(String email);
}

/// Firebase Authentication implementation.
class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway([FirebaseAuth? auth]) : _auth = auth;

  final FirebaseAuth? _auth;
  FirebaseAuth get _fb => _auth ?? FirebaseAuth.instance;

  @override
  Stream<String?> uidChanges() => _fb.authStateChanges().map((u) => u?.uid);

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _fb.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(authErrorMessage(e.code));
    } catch (_) {
      // Firebase not configured / unexpected: never leak internals.
      throw AuthFailure(authErrorMessage('unknown'));
    }
  }

  @override
  Future<void> signOut() => _fb.signOut();

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _fb.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-email') return;
      throw AuthFailure(authErrorMessage(e.code));
    } catch (_) {
      throw AuthFailure(authErrorMessage('unknown'));
    }
  }
}
