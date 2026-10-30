import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/core/sync/outbox.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/data/providers/sync_providers.dart';
import 'package:quran_center/data/services/session_work.dart';

/// Shows changes that have not reached the server yet, and those it refused.
/// Hidden when everything is saved. With [scope] it only counts one session.
class SyncStatusBar extends ConsumerWidget {
  const SyncStatusBar({super.key, this.scope});

  final String? scope;

  static String describe(OutboxOp op) {
    final what = op.type == SessionWork.attendanceType ? 'حضور' : 'تسميع';
    final who = op.payload['label'] as String?;
    return who == null ? what : '$what: $who';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(outboxSnapshotProvider).valueOrNull;
    if (snap == null) return const SizedBox.shrink();
    final ops = (scope == null ? snap.ops : snap.inScope(scope!).toList());
    final pending = ops.where((o) => !o.failed).length;
    final failed = ops.where((o) => o.failed).length;
    if (pending == 0 && failed == 0) return const SizedBox.shrink();

    final box = ref.read(sessionWorkProvider).outbox;
    final color = failed > 0 ? DesignTokens.error : DesignTokens.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.space8),
      padding: const EdgeInsets.all(DesignTokens.space12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          snap.syncing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(
                  failed > 0
                      ? Icons.error_outline
                      : Icons.cloud_upload_outlined,
                  color: color),
          const SizedBox(width: DesignTokens.space12),
          Expanded(
            child: Text(
              [
                if (pending > 0)
                  '$pending تغييرات محفوظة على جهازك بانتظار المزامنة',
                if (failed > 0) '$failed تغييرات رفضها الخادم',
              ].join(' • '),
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => failed > 0
                ? _showFailures(
                    context, box, ops.where((o) => o.failed).toList())
                : box.flush(),
            child: Text(failed > 0 ? 'عرض' : 'مزامنة الآن'),
          ),
        ],
      ),
    );
  }

  void _showFailures(BuildContext context, Outbox box, List<OutboxOp> failed) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(DesignTokens.space16),
            children: [
              const Text('تغييرات رفضها الخادم',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: DesignTokens.space8),
              for (final op in failed)
                ListTile(
                  title: Text(describe(op)),
                  subtitle: Text(op.error ?? ''),
                  trailing: TextButton(
                    onPressed: () {
                      box.discard(op.key);
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('تجاهل'),
                  ),
                ),
              const SizedBox(height: DesignTokens.space8),
              FilledButton(
                onPressed: () {
                  box.retryFailed();
                  Navigator.of(ctx).pop();
                },
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
