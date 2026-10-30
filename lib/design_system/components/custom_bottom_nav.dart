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
      decoration: const BoxDecoration(
        color: Colors.white,
        border:
            Border(top: BorderSide(color: DesignTokens.borders, width: 1.5)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: DesignTokens.bottomNavHeight,
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final active = i == currentIndex;
              final color = active
                  ? DesignTokens.primaryDarkGreen
                  : DesignTokens.secondaryText;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: active,
                  label: item.label,
                  child: InkWell(
                    onTap: () => onTap(i),
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: DesignTokens.durationFast,
                          width: 52,
                          height: 32,
                          decoration: BoxDecoration(
                            color: active
                                ? DesignTokens.softMint
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: active
                                ? Border.all(
                                    color: DesignTokens.primaryDarkGreen
                                        .withValues(alpha: 0.35),
                                    width: 1.5)
                                : null,
                          ),
                          child: Icon(
                              active
                                  ? (item.activeIcon ?? item.icon)
                                  : item.icon,
                              size: 22,
                              color: color),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                            color: color,
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
        ),
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
