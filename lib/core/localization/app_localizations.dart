import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Minimal, functional localization backed by the ARB maps.
/// Replaces codegen output until `flutter_intl` codegen is wired.
/// Arabic-first; RTL applied by the caller via Directionality/Theme.
class AppLocalizations {
  static final Map<String, Map<String, String>> _messages = {
    'en': const {
      'appName': 'Quran Center',
      'appNameAr': 'دار تحفيظ قرآن',
      'splashLoading': 'Initializing\u2026',
      'splashRetry': 'Retry',
      'splashError': 'Unable to initialize the application.',
      'loginTitle': 'Sign In',
      'loginGreeting': 'Welcome back',
      'loginDescription': 'Sign in to your Quran center account.',
      'emailLabel': 'Email',
      'emailHint': 'Enter your email',
      'emailRequired': 'Email is required',
      'emailInvalid': 'Please enter a valid email address',
      'passwordLabel': 'Password',
      'passwordHint': 'Enter your password',
      'passwordRequired': 'Password is required',
      'showPassword': 'Show password',
      'hidePassword': 'Hide password',
      'signIn': 'Sign In',
      'signingIn': 'Signing in\u2026',
      'forgotPassword': 'Forgot password?',
      'helpSupport': 'Help & support',
      'privacyTerms': 'Privacy & Terms',
      'errorInvalidCredentials': 'Invalid email or password.',
      'errorAccountDisabled': 'This account has been disabled.',
      'errorNetworkUnavailable': 'Network unavailable. Please check your connection.',
      'errorSessionExpired': 'Session expired. Please sign in again.',
      'errorUnknown': 'An unexpected error occurred. Please try again.',
      'roleDirector': 'Director',
      'roleTeacher': 'Teacher',
      'roleStudent': 'Student',
    },
    'ar': const {
      'appName': 'إدارة مركز تحفيظ القرآن',
      'appNameAr': 'دار تحفيظ قرآن',
      'splashLoading': 'جاري التهيئة\u2026',
      'splashRetry': 'إعادة المحاولة',
      'splashError': 'تعذر تشغيل التطبيق.',
      'loginTitle': 'تسجيل الدخول',
      'loginGreeting': 'أهلاً بك مرة أخرى',
      'loginDescription': 'تسجيل الدخول إلى حساب مركز تحفيظ القرآن الخاص بك.',
      'emailLabel': 'البريد الإلكتروني',
      'emailHint': 'أدخل بريدك الإلكتروني',
      'emailRequired': 'البريد الإلكتروني مطلوب',
      'emailInvalid': 'الرجاء إدخال بريد إلكتروني صحيح',
      'passwordLabel': 'كلمة المرور',
      'passwordHint': 'أدخل كلمة المرور',
      'passwordRequired': 'كلمة المرور مطلوبة',
      'showPassword': 'إظهار كلمة المرور',
      'hidePassword': 'إخفاء كلمة المرور',
      'signIn': 'تسجيل الدخول',
      'signingIn': 'جاري تسجيل الدخول\u2026',
      'forgotPassword': 'نسيت كلمة المرور؟',
      'helpSupport': 'المساعدة والدعم',
      'privacyTerms': 'الخصوصية والشروط',
      'errorInvalidCredentials': 'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
      'errorAccountDisabled': 'تم تعطيل هذا الحساب.',
      'errorNetworkUnavailable': 'الشبكة غير متاحة. يرجى التحقق من اتصالك.',
      'errorSessionExpired': 'انتهت الجلسة. يرجى تسجيل الدخول مرة أخرى.',
      'errorUnknown': 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.',
      'roleDirector': 'مدير',
      'roleTeacher': 'معلم',
      'roleStudent': 'طالب',
    },
  };

  static const List<Locale> supportedLocales = [
    Locale('ar'),
    Locale('en'),
  ];

  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return AppLocalizations(locale);
  }

  String s(String key) {
    final lang = locale.languageCode;
    final map = _messages[lang] ?? _messages['en']!;
    return map[key] ?? key;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (l) => l.languageCode == locale.languageCode,
  );
  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  @override
  bool shouldReload(covariant AppLocalizationsDelegate old) => false;
}
