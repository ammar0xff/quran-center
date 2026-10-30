import 'package:flutter/material.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/design_system/components/rosette.dart';

/// Nothing to show: an empty rosette, an optional heading, one plain sentence
/// and optionally the action that fills the screen.
class EmptyState extends StatelessWidget {
  const EmptyState(
    this.message, {
    super.key,
    this.icon = Icons.auto_stories_rounded,
    this.title,
    this.action,
  });

  final String message;
  final IconData icon;
  final String? title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Rosette(
              size: 72,
              color: DesignTokens.bordersStrong,
              filled: false,
              child: Icon(icon, size: 30, color: DesignTokens.secondaryText),
            ),
            const SizedBox(height: 14),
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(title!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: DesignTokens.secondaryText,
                    fontSize: 15,
                    height: 1.6)),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
