import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/auth/auth_gateway.dart';

void main() {
  group('authErrorMessage', () {
    test('wrong password, unknown user and bad email are indistinguishable', () {
      final messages = {
        for (final code in [
          'invalid-credential',
          'wrong-password',
          'user-not-found',
          'invalid-email',
        ])
          authErrorMessage(code)
      };
      expect(messages, hasLength(1));
    });

    test('other conditions get their own actionable message', () {
      final all = {
        authErrorMessage('invalid-credential'),
        authErrorMessage('user-disabled'),
        authErrorMessage('too-many-requests'),
        authErrorMessage('network-request-failed'),
        authErrorMessage('something-unexpected'),
      };
      expect(all, hasLength(5));
    });

    test('unknown codes never echo internals', () {
      expect(authErrorMessage('internal-error-xyz'), isNot(contains('xyz')));
    });
  });
}
