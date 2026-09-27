import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../application/reference_cache_task.dart';
import '../design/theme.dart';

enum TaskIndicatorVariant { floating, rail, sidebar }

/// Persistent indicator for background reference-cache tasks
/// (replaces the old auto-dismissing banner, DESIGN §10 Δ10).
class TaskIndicator extends StatelessWidget {
  const TaskIndicator({required this.variant, super.key});

  final TaskIndicatorVariant variant;

  @override
  Widget build(BuildContext context) {
    final center = context.watch<ReferenceCacheCenter>();
    final tasks = center.tasks;
    if (tasks.isEmpty) return const SizedBox.shrink();
    final task = tasks.lastWhere((t) => t.isRunning, orElse: () => tasks.last);
    return ListenableBuilder(
      listenable: task,
      builder: (context, _) => _IndicatorBody(
        task: task,
        variant: variant,
        onTap: () => showReferenceCacheDetails(context, task),
      ),
    );
  }
}

class _IndicatorBody extends StatelessWidget {
  const _IndicatorBody({
    required this.task,
    required this.variant,
    required this.onTap,
  });

  final ReferenceCacheTask task;
  final TaskIndicatorVariant variant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final progress = task.progress;
    final total = progress?.total ?? 0;
    final processed = progress?.processed ?? 0;
    final value = total == 0 ? null : processed / total;
    final status = task.status;
    final (Color color, IconData icon) = switch (status) {
      ReferenceCacheStatus.running => (c.primary, Symbols.download_rounded),
      ReferenceCacheStatus.success => (c.success, Symbols.check_circle_rounded),
      ReferenceCacheStatus.partial => (c.warning, Symbols.warning_rounded),
      ReferenceCacheStatus.failed ||
      ReferenceCacheStatus.interrupted => (c.danger, Symbols.error_rounded),
    };
    final ring = SizedBox.square(
      dimension: 22,
      child: status == ReferenceCacheStatus.running
          ? CircularProgressIndicator(
              value: value,
              strokeWidth: 2.6,
              color: color,
              backgroundColor: c.surfaceMuted,
            )
          : Icon(icon, size: 22, color: color, fill: 1),
    );
    final label = status == ReferenceCacheStatus.running
        ? '缓存 $processed/$total'
        : switch (status) {
            ReferenceCacheStatus.success => '缓存完成',
            ReferenceCacheStatus.partial => '部分失败',
            _ => '缓存失败',
          };
    final semantics = '参考图缓存：$label';

    switch (variant) {
      case TaskIndicatorVariant.rail:
        return Tooltip(
          message: semantics,
          child: IconButton(onPressed: onTap, icon: ring),
        );
      case TaskIndicatorVariant.sidebar:
      case TaskIndicatorVariant.floating:
        final floating = variant == TaskIndicatorVariant.floating;
        return Semantics(
          button: true,
          label: semantics,
          child: Material(
            color: floating ? c.surface : c.surfaceMuted,
            borderRadius: Radii.pillAll,
            elevation: 0,
            child: InkWell(
              borderRadius: Radii.pillAll,
              onTap: onTap,
              child: Container(
                decoration: floating
                    ? BoxDecoration(
                        borderRadius: Radii.pillAll,
                        border: Border.all(color: c.hairline),
                        boxShadow: Elevations.level2(c),
                      )
                    : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: floating ? MainAxisSize.min : MainAxisSize.max,
                  children: [
                    ring,
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        style: text.labelMedium?.copyWith(
                          fontFeatures: MiriaFonts.tabular,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    }
  }
}

/// Details dialog/sheet for a cache task: progress, result, retry.
Future<void> showReferenceCacheDetails(
  BuildContext context,
  ReferenceCacheTask task,
) {
  final center = context.read<ReferenceCacheCenter>();
  return showDialog<void>(
    context: context,
    builder: (context) => ListenableBuilder(
      listenable: task,
      builder: (context, _) {
        final c = context.colors;
        final text = context.text;
        final progress = task.progress;
        final total = progress?.total ?? 0;
        final processed = progress?.processed ?? 0;
        final succeeded = progress?.succeeded ?? 0;
        final failed = progress?.failed ?? 0;
        final status = task.status;
        final title = switch (status) {
          ReferenceCacheStatus.running => '正在缓存参考图...',
          ReferenceCacheStatus.success ||
          ReferenceCacheStatus.partial => '参考图缓存完成',
          _ => '参考图缓存失败',
        };
        final String body;
        switch (status) {
          case ReferenceCacheStatus.running:
            body = '$processed / $total';
          case ReferenceCacheStatus.success:
            body = '$succeeded / $total 张成功，已保存到本地';
          case ReferenceCacheStatus.partial:
            body = '$succeeded / $total 张成功 · $failed 张失败';
          case ReferenceCacheStatus.interrupted:
            body = '缓存中断，请重试；已保存的图片不会删除。';
          case ReferenceCacheStatus.failed:
            body = '$succeeded / $total 张成功 · $failed 张失败';
        }
        final percent = total == 0 ? 0 : (processed * 100 ~/ total);
        return AlertDialog(
          title: Text(title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task.planName.isNotEmpty)
                  Text(task.planName, style: text.titleSmall),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: text.bodyLarge?.copyWith(
                    fontFeatures: MiriaFonts.tabular,
                  ),
                ),
                if (status == ReferenceCacheStatus.running) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: total == 0 ? null : processed / total,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$percent%',
                        style: text.labelMedium?.copyWith(
                          fontFeatures: MiriaFonts.tabular,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '提示：缓存过程中请保持网络连接，避免切换页面或锁屏。',
                    style: text.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!task.isRunning)
              TextButton(
                onPressed: () {
                  center.dismiss(task);
                  Navigator.of(context).pop();
                },
                child: const Text('清除'),
              ),
            if (status == ReferenceCacheStatus.partial)
              FilledButton(onPressed: task.retry, child: const Text('重试失败')),
            if (status == ReferenceCacheStatus.failed ||
                status == ReferenceCacheStatus.interrupted)
              FilledButton(onPressed: task.retry, child: const Text('重试全部')),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    ),
  );
}
