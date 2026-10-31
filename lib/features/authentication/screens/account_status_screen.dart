import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/design_system/components/rosette.dart';
import 'package:quran_center/core/auth/app_session.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';

/// Shown to a signed-in user who is not admitted to any role area
/// (suspended, pending, incomplete, no profile, unsupported role, or the
/// profile could not be loaded). No protected data is shown here.
class AccountStatusScreen extends ConsumerWidget {
  const AccountStatusScreen({super.key});

  static ({IconData icon, String title, String body}) describe(BlockReason? r) {
    switch (r) {
      case BlockReason.suspended:
        return (
          icon: Icons.block,
          title: 'الحساب معلّق',
          body: 'تم تعليق هذا الحساب. تواصل مع إدارة الدار لمعرفة التفاصيل.',
        );
      case BlockReason.pending:
        return (
          icon: Icons.hourglass_top,
          title: 'الحساب قيد التفعيل',
          body: 'لم يكتمل تفعيل حسابك بعد. تواصل مع إدارة الدار.',
        );
      case BlockReason.incomplete:
        return (
          icon: Icons.person_off,
          title: 'بيانات الحساب غير مكتملة',
          body: 'لم يكتمل إعداد حسابك. تواصل مع إدارة الدار.',
        );
      case BlockReason.unsupportedRole:
        return (
          icon: Icons.lock,
          title: 'نوع الحساب غير مدعوم',
          body: 'هذا النوع من الحسابات غير متاح في هذا الإصدار.',
        );
      case BlockReason.loadFailed:
        return (
          icon: Icons.wifi_off,
          title: 'تعذر التحقق من حسابك',
          body: 'تحقق من اتصالك بالإنترنت ثم أعد المحاولة.',
        );
      case BlockReason.subscriptionExpired:
        return (
          icon: Icons.access_time_filled,
          title: 'انتهت فترة الاشتراك',
          body: 'انتهت صلاحية اشتراك الدار. يرجى تجديد الاشتراك لمواصلة استخدام النظام.',
        );
      case BlockReason.noProfile:
      case null:
        return (
          icon: Icons.person_search,
          title: 'لم يتم العثور على ملف الحساب',
          body:
              'سجّلت الدخول بنجاح لكن لا يوجد ملف مرتبط بحسابك. تواصل مع إدارة الدار.',
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reason = ref.watch(currentSessionProvider).blockReason;
    final info = describe(reason);
    final canRetry = reason == BlockReason.loadFailed ||
        reason == BlockReason.pending ||
        reason == BlockReason.noProfile;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(DesignTokens.space24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Rosette(
                      size: 96,
                      color: DesignTokens.warning,
                      child: Icon(info.icon, size: 40, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space16),
                  Text(info.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: DesignTokens.space8),
                  Text(info.body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: DesignTokens.secondaryText, height: 1.6)),
                  const SizedBox(height: DesignTokens.space24),
                  if (canRetry)
                    FilledButton(
                      onPressed: () => ref.invalidate(sessionProvider),
                      child: const Text('إعادة التحقق'),
                    ),
                  const SizedBox(height: DesignTokens.space12),
                  OutlinedButton(
                    onPressed: () => ref.read(authGatewayProvider).signOut(),
                    child: const Text('تسجيل الخروج'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
