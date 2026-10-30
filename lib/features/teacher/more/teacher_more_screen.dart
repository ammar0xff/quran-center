import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/core/auth/auth_gateway.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/data/datasources/firestore_helpers.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/teacher.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/features/director/accounts/accounts_screen.dart'
    show accountStatusLabel;
import 'package:quran_center/features/teacher/widgets/teacher_bottom_nav.dart';

class _TeacherAccount {
  const _TeacherAccount(
      {this.teacher,
      this.centerName,
      required this.circleCount,
      required this.studentCount});
  final Teacher? teacher;
  final String? centerName;
  final int circleCount;
  final int studentCount;
}

final _teacherAccountProvider =
    FutureProvider.autoDispose<_TeacherAccount>((ref) async {
  final profile = ref.watch(currentSessionProvider).profile!;
  final ds = ref.read(firestoreDataSourceProvider);
  final ws = ref.read(teacherWorkspaceProvider);

  Teacher? teacher;
  String? centerName;
  try {
    final raw = await ds.getDoc('teachers/${profile.uid}');
    if (raw != null && raw['centerId'] == profile.centerId) {
      teacher =
          Teacher.fromJson(profile.uid, firestoreConverter.decodeFromRead(raw));
    }
    centerName =
        (await ds.getDoc('centers/${profile.centerId}'))?['name'] as String?;
  } catch (_) {
    // Optional details; the rest of the screen still works.
  }
  final (circles, students) = await (
    ws.circles(profile.centerId, profile.uid),
    ws.students(profile.centerId, profile.uid),
  ).wait;
  return _TeacherAccount(
    teacher: teacher,
    centerName: centerName,
    circleCount: circles.where((c) => c.status == CircleStatus.active).length,
    studentCount: students
        .where((s) => s.enrollmentStatus == EnrollmentStatus.active)
        .length,
  );
});

/// The teacher's account: read-only details, password change by email, and
/// sign-out. A teacher cannot edit their own role, status or assignments;
/// profile changes go through the director.
class TeacherMoreScreen extends ConsumerWidget {
  const TeacherMoreScreen({super.key});

  Future<void> _changePassword(
      BuildContext context, WidgetRef ref, String email) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authGatewayProvider).sendPasswordReset(email);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text('أرسلنا رابط تغيير كلمة المرور إلى $email'),
            backgroundColor: DesignTokens.success));
    } on AuthFailure catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(e.message), backgroundColor: DesignTokens.error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentSessionProvider).profile;
    final account = ref.watch(_teacherAccountProvider).valueOrNull;
    final email = account?.teacher?.contactInfo?['email'];
    final phone = account?.teacher?.contactInfo?['phone'];

    Widget row(String l, String v) => Padding(
          padding: const EdgeInsets.symmetric(
              vertical: DesignTokens.space12, horizontal: DesignTokens.space16),
          child: Row(children: [
            SizedBox(
                width: 110,
                child: Text(l,
                    style: const TextStyle(color: DesignTokens.secondaryText))),
            Expanded(
                child: Text(v,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
        );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: AppBar(title: const Text('حسابي'), centerTitle: false),
        body: ListView(
          padding: const EdgeInsets.all(DesignTokens.space20),
          children: [
            Card(
              child: Column(children: [
                row('الاسم', profile?.fullName ?? '—'),
                const Divider(height: 1),
                row('الحالة',
                    profile == null ? '—' : accountStatusLabel(profile.status)),
                if (account?.centerName != null) ...[
                  const Divider(height: 1),
                  row('الدار', account!.centerName!),
                ],
                if (email != null) ...[
                  const Divider(height: 1),
                  row('البريد', email),
                ],
                if (phone != null) ...[
                  const Divider(height: 1),
                  row('الجوال', phone),
                ],
                if (account != null) ...[
                  const Divider(height: 1),
                  row('حلقاتي', '${account.circleCount}'),
                  const Divider(height: 1),
                  row('طلابي', '${account.studentCount}'),
                ],
              ]),
            ),
            const SizedBox(height: DesignTokens.space8),
            const Text('لتعديل بياناتك أو حلقاتك تواصل مع إدارة الدار.',
                style:
                    TextStyle(fontSize: 12, color: DesignTokens.secondaryText)),
            const SizedBox(height: DesignTokens.space20),
            if (email != null)
              OutlinedButton.icon(
                onPressed: () => _changePassword(context, ref, email),
                icon: const Icon(Icons.lock_reset),
                label: const Text('تغيير كلمة المرور'),
              ),
            const SizedBox(height: DesignTokens.space12),
            OutlinedButton.icon(
              onPressed: () => ref.read(authGatewayProvider).signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('تسجيل الخروج'),
            ),
          ],
        ),
        bottomNavigationBar: const TeacherBottomNav(currentIndex: 3),
      ),
    );
  }
}
