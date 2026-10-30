import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';

/// Shown for areas that are not built yet. It states that plainly instead of
/// pretending to be a working screen, and always offers sign-out.
class RoleHomePlaceholder extends ConsumerWidget {
  const RoleHomePlaceholder({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(currentSessionProvider).profile?.fullName;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.construction,
                    size: 56, color: DesignTokens.secondaryText),
                const SizedBox(height: DesignTokens.space16),
                if (name != null)
                  Text('مرحبًا $name',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: DesignTokens.space8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: DesignTokens.space24),
                OutlinedButton.icon(
                  onPressed: () => ref.read(authGatewayProvider).signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text('تسجيل الخروج'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
