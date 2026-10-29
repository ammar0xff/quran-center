import 'package:flutter/material.dart';
import 'package:quran_center/core/theme/design_tokens.dart';

/// Custom bottom navigation bar used by role shells.
///
/// [items] are the destinations; [currentIndex] the active tab; [onTap]
/// navigates. Arabic-first: labels render RTL-appropriately via Directionality.
class CustomBottomNav extends StatelessWidget {
  const CustomBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<BottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: DesignTokens.bottomNavHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: DesignTokens.borders)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final item = items[i];
          final active = i == currentIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: double.infinity,
                color: active
                    ? DesignTokens.softMint.withValues(alpha: 0.5)
                    : Colors.transparent,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      active ? item.activeIcon : item.icon,
                      size: 22,
                      color: active ? DesignTokens.primaryDarkGreen : DesignTokens.secondaryText,
                    ),
                    const SizedBox(height: DesignTokens.space4),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                        color: active ? DesignTokens.primaryDarkGreen : DesignTokens.secondaryText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class BottomNavItem {
  const BottomNavItem({
    required this.label,
    required this.icon,
    this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData? activeIcon;
}
