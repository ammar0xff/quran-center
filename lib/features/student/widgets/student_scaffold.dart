import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/features/student/student_data.dart';
import 'package:quran_center/features/student/widgets/student_bottom_nav.dart';

/// Common frame for student screens: title, pull-to-refresh, loading, error
/// with retry, and the bottom navigation.
class StudentScaffold extends ConsumerWidget {
  const StudentScaffold({
    super.key,
    required this.title,
    required this.navIndex,
    required this.builder,
    this.showAppBar = true,
  });

  final String title;
  final int navIndex;
  final bool showAppBar;
  final Widget Function(BuildContext context, WidgetRef ref, StudentData data) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(studentDataProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: showAppBar ? AppBar(title: Text(title), centerTitle: false) : null,
        body: SafeArea(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
              child: Padding(
                padding: const EdgeInsets.all(DesignTokens.space24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 48, color: DesignTokens.secondaryText),
                    const SizedBox(height: DesignTokens.space12),
                    const Text('تعذر تحميل بياناتك. تحقق من اتصالك.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: DesignTokens.space12),
                    OutlinedButton(
                        onPressed: () => ref.invalidate(studentDataProvider),
                        child: const Text('إعادة المحاولة')),
                  ],
                ),
              ),
            ),
            data: (d) => RefreshIndicator(
              onRefresh: () async => ref.refresh(studentDataProvider.future),
              child: builder(context, ref, d),
            ),
          ),
        ),
        bottomNavigationBar: StudentBottomNav(currentIndex: navIndex),
      ),
    );
  }
}
