import 'package:flutter/material.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/design_system/components/rosette.dart';

enum PathState { done, current, upcoming, late }

class PathStep {
  const PathStep({
    required this.title,
    required this.subtitle,
    required this.state,
    this.onTap,
    this.actionLabel,
  });
  final String title;
  final String subtitle;
  final PathState state;
  final VoidCallback? onTap;

  /// Shown as a button on the current step only.
  final String? actionLabel;
}

/// The day as a vertical path: a rosette per step joined by a line. The step
/// to do now is filled and carries the action; finished ones show a tick,
/// later ones are outlined, an overdue one is red.
class DayPath extends StatelessWidget {
  const DayPath({super.key, required this.steps});
  final List<PathStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _Row(step: steps[i], index: i + 1, last: i == steps.length - 1),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.step, required this.index, required this.last});
  final PathStep step;
  final int index;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final current = step.state == PathState.current || step.state == PathState.late;
    final color = switch (step.state) {
      PathState.done => DesignTokens.success,
      PathState.current => DesignTokens.leaf,
      PathState.late => DesignTokens.error,
      PathState.upcoming => DesignTokens.bordersStrong,
    };
    final node = Rosette(
      size: current ? 54 : 44,
      color: color,
      filled: step.state != PathState.upcoming,
      child: step.state == PathState.done
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
          : Text('$index',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: current ? 18 : 15,
                  color: step.state == PathState.upcoming ? DesignTokens.secondaryText : Colors.white)),
    );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 56,
            child: Column(
              children: [
                node,
                if (!last)
                  Expanded(
                    child: Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: step.state == PathState.done ? DesignTokens.success.withValues(alpha: 0.5) : DesignTokens.borders,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                margin: EdgeInsets.zero,
                color: current ? Colors.white : Colors.white.withValues(alpha: 0.85),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
                  side: BorderSide(
                    color: current ? color.withValues(alpha: 0.6) : DesignTokens.borders,
                    width: current ? 2 : 1.5,
                  ),
                ),
                child: InkWell(
                  onTap: step.onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(step.title,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: step.state == PathState.upcoming
                                    ? DesignTokens.secondaryText
                                    : DesignTokens.mainText)),
                        const SizedBox(height: 2),
                        Text(step.subtitle,
                            style: TextStyle(
                                fontSize: 13,
                                color: step.state == PathState.late
                                    ? DesignTokens.error
                                    : DesignTokens.secondaryText)),
                        if (current && step.actionLabel != null) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(onPressed: step.onTap, child: Text(step.actionLabel!)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
