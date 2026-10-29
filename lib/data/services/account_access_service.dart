import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A failure the UI can show directly (message is already user-facing Arabic).
class AccountAccessException implements Exception {
  AccountAccessException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The account was created and linked, but the activation email could not be
/// sent. The director can resend it; nothing needs to be redone.
class ActivationEmailException extends AccountAccessException {
  ActivationEmailException()
      : super('تم إنشاء الحساب لكن تعذر إرسال رسالة التفعيل. أعد إرسالها لاحقًا.');
}

/// Translates a Cloud Functions error code into an actionable Arabic message.
String accessErrorMessage(String code) {
  switch (code) {
    case 'already-exists':
      return 'هذا البريد الإلكتروني مستخدم بالفعل لحساب آخر.';
    case 'failed-precondition':
      return 'هذا الإجراء غير متاح في حالة الطالب الحالية.';
    case 'permission-denied':
      return 'ليست لديك صلاحية تنفيذ هذا الإجراء.';
    case 'unauthenticated':
      return 'انتهت الجلسة. سجّل الدخول مرة أخرى.';
    case 'not-found':
      return 'لم يتم العثور على الطالب.';
    case 'invalid-argument':
      return 'البيانات المدخلة غير صحيحة.';
    default:
      return 'تعذر الاتصال بالخادم. تحقق من الاتصال وحاول مرة أخرى.';
  }
}

/// Digital-access operations. Every operation that creates or changes a login
/// runs on the backend; the client never creates accounts or writes the
/// student↔account link itself.
abstract class AccountAccessService {
  /// Creates a login for an existing accountless student, links it, and sends
  /// activation instructions to [email].
  Future<void> enableStudentAccess({
    required String studentId,
    required String email,
  });

  /// Suspends ([suspend] = true) or reactivates a student's login.
  Future<void> setSuspended({required String studentId, required bool suspend});

  /// Re-sends the activation / password-setup email.
  Future<void> resendActivation(String email);
}

/// Production implementation backed by Firebase Cloud Functions + Auth.
class CloudFunctionsAccountAccessService implements AccountAccessService {
  CloudFunctionsAccountAccessService({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _functions = functions,
        _auth = auth;

  final FirebaseFunctions? _functions;
  final FirebaseAuth? _auth;

  FirebaseFunctions get _fn => _functions ?? FirebaseFunctions.instance;
  FirebaseAuth get _firebaseAuth => _auth ?? FirebaseAuth.instance;

  Future<T> _call<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on FirebaseFunctionsException catch (e) {
      throw AccountAccessException(accessErrorMessage(e.code));
    } catch (_) {
      // Firebase not configured / offline / unexpected: never leak internals.
      throw AccountAccessException(accessErrorMessage('unavailable'));
    }
  }

  @override
  Future<void> enableStudentAccess({
    required String studentId,
    required String email,
  }) async {
    final normalized = email.trim().toLowerCase();
    await _call(() => _fn
        .httpsCallable('enableStudentAccess')
        .call<dynamic>({'studentId': studentId, 'email': normalized}));
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: normalized);
    } catch (_) {
      throw ActivationEmailException();
    }
  }

  @override
  Future<void> setSuspended({
    required String studentId,
    required bool suspend,
  }) async {
    await _call(() => _fn
        .httpsCallable('setStudentAccessSuspended')
        .call<dynamic>({'studentId': studentId, 'suspend': suspend}));
  }

  @override
  Future<void> resendActivation(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } catch (_) {
      throw ActivationEmailException();
    }
  }
}
