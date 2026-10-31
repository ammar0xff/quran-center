import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/core/auth/app_session.dart';
import 'package:quran_center/core/demo/demo_controller.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/data/models/enums.dart';

/// Wraps any screen when demo mode is active to show:
/// 1. A persistent top conversion CTA bar to view pricing & subscribe.
/// 2. A floating 3-in-1 role switcher pill (مديرة | محفّظ | طالب).
class DemoOverlayWrapper extends ConsumerWidget {
  const DemoOverlayWrapper({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemo = ref.watch(isDemoModeProvider);
    if (!isDemo) return child;

    final currentRole = ref.watch(demoActiveRoleProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          // The actual screen content
          Positioned.fill(
            child: Column(
              children: [
                // Top Persistent Demo CTA Bar
                const DemoTopCtaBar(),
                Expanded(child: child),
              ],
            ),
          ),

          // Pinned Floating Role Switcher Pill at the bottom
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Center(
              child: DemoRoleSwitcherPill(
                activeRole: currentRole,
                onRoleChanged: (role) => switchDemoRole(ref, context, role),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The top banner visible across the demo mode.
class DemoTopCtaBar extends ConsumerWidget {
  const DemoTopCtaBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0A3A30), // Deep emerald
          border: Border(
            bottom: BorderSide(
              color: DesignTokens.gold.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: DesignTokens.gold.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DesignTokens.gold, width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility_rounded, color: Color(0xFFE9CF93), size: 14),
                    SizedBox(width: 4),
                    Text(
                      'معاينة تفاعلية',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFE9CF93),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'دار النور النموذجية بكافة أدوارها',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: DesignTokens.gold,
                  foregroundColor: const Color(0xFF0A3A30),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => context.push(Routes.pricing),
                icon: const Icon(Icons.star_rounded, size: 16),
                label: const Text(
                  'تفعيل داري الآن',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'إنهاء المعاينة',
                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => exitDemoMode(ref, context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The pill widget allowing the director to switch between the 3 interfaces in 1 click.
class DemoRoleSwitcherPill extends StatelessWidget {
  const DemoRoleSwitcherPill({
    required this.activeRole,
    required this.onRoleChanged,
    super.key,
  });

  final UserRole activeRole;
  final ValueChanged<UserRole> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 6,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF0E5A47), // Emerald
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: DesignTokens.gold, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RolePillItem(
              title: 'مديرة الدار',
              icon: Icons.admin_panel_settings_rounded,
              isSelected: activeRole == UserRole.director,
              onTap: () => onRoleChanged(UserRole.director),
            ),
            _RolePillItem(
              title: 'المحفّظ',
              icon: Icons.menu_book_rounded,
              isSelected: activeRole == UserRole.teacher,
              onTap: () => onRoleChanged(UserRole.teacher),
            ),
            _RolePillItem(
              title: 'الطالب',
              icon: Icons.school_rounded,
              isSelected: activeRole == UserRole.student,
              onTap: () => onRoleChanged(UserRole.student),
            ),
          ],
        ),
      ),
    );
  }
}

class _RolePillItem extends StatelessWidget {
  const _RolePillItem({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? DesignTokens.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF0A3A30) : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF0A3A30) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
