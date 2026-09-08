import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_theme.dart';
import '../widgets/app_status_banner.dart';
import 'reference_full_cache_runner.dart';
import 'pilgrimage_models.dart';

typedef ReferenceCacheRun =
    Future<void> Function(ValueChangedProgress onProgress);

/// Task state outlives its dismissible progress view.
class ReferenceCacheTask extends ChangeNotifier {
  static final _tasks = Expando<Map<String, ReferenceCacheTask>>();

  static ReferenceCacheTask forPlan(Object repository, String planId) {
    final tasks = _tasks[repository] ??= {};
    return tasks.putIfAbsent(planId, ReferenceCacheTask.new);
  }

  ReferenceFullCacheProgress? progress;
  PilgrimagePlan? updatedPlan;
  bool isRunning = false;
  bool hasError = false;
  Future<void> _finished = Future.value();
  Future<void> get finished => _finished;

  Future<void> start(ReferenceCacheRun run) {
    if (isRunning) return _finished;
    final done = Completer<void>();
    _finished = done.future;
    isRunning = true;
    hasError = false;
    updatedPlan = null;
    progress = ReferenceFullCacheProgress(total: progress?.total ?? 0);
    notifyListeners();
    unawaited(_execute(run, done));
    return _finished;
  }

  Future<void> _execute(ReferenceCacheRun run, Completer<void> done) async {
    try {
      await run((value) {
        progress = value;
        notifyListeners();
      });
    } catch (_) {
      hasError = true;
    } finally {
      isRunning = false;
      notifyListeners();
      done.complete();
    }
  }
}

Future<void> showReferenceCacheProgressDialog({
  required BuildContext context,
  required ReferenceCacheRun run,
  ReferenceCacheTask? task,
  bool startOnOpen = true,
}) async {
  final activeTask = task ?? ReferenceCacheTask();
  await showStatusBannerOverlay(
    context: context,
    builder: (_) => ReferenceCacheProgressDialog(
      run: run,
      task: activeTask,
      startOnOpen: startOnOpen,
    ),
  );
  await activeTask.finished;
}

class ReferenceCacheProgressDialog extends StatefulWidget {
  const ReferenceCacheProgressDialog({
    required this.run,
    this.task,
    this.startOnOpen = true,
    super.key,
  });

  final ReferenceCacheRun run;
  final ReferenceCacheTask? task;
  final bool startOnOpen;

  @override
  State<ReferenceCacheProgressDialog> createState() =>
      _ReferenceCacheProgressDialogState();
}

enum _CacheDialogStatus { running, success, partial, failed }

class _ReferenceCacheProgressDialogState
    extends State<ReferenceCacheProgressDialog> {
  late final _task = widget.task ?? ReferenceCacheTask();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.startOnOpen && !_task.isRunning) {
        _task.start(widget.run);
      }
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _task,
    builder: (context, _) {
      final progress = _task.progress;
      final status = _task.isRunning || progress == null
          ? _CacheDialogStatus.running
          : _task.hasError
          ? _CacheDialogStatus.failed
          : progress.failed == 0
          ? _CacheDialogStatus.success
          : progress.succeeded == 0
          ? _CacheDialogStatus.failed
          : _CacheDialogStatus.partial;
      return _CacheBannerCard(
        bannerKey: const ValueKey('reference-cache-progress-dialog'),
        status: status,
        total: progress?.total ?? 0,
        processed: progress?.processed ?? 0,
        succeeded: progress?.succeeded ?? 0,
        failed: progress?.failed ?? 0,
        interrupted: _task.hasError,
        onRetry:
            status == _CacheDialogStatus.partial ||
                status == _CacheDialogStatus.failed
            ? () => _task.start(widget.run)
            : null,
      );
    },
  );
}

class _CacheBannerCard extends StatelessWidget {
  const _CacheBannerCard({
    required this.bannerKey,
    required this.status,
    required this.total,
    required this.processed,
    required this.succeeded,
    required this.failed,
    this.onRetry,
    this.interrupted = false,
  });

  final Key bannerKey;
  final _CacheDialogStatus status;
  final int total;
  final int processed;
  final int succeeded;
  final int failed;
  final VoidCallback? onRetry;
  final bool interrupted;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : (processed / total).clamp(0.0, 1.0);
    final percent = (fraction * 100).round();
    final kind = switch (status) {
      _CacheDialogStatus.running => AppStatusBannerKind.running,
      _CacheDialogStatus.success => AppStatusBannerKind.success,
      _CacheDialogStatus.partial => AppStatusBannerKind.warning,
      _CacheDialogStatus.failed => AppStatusBannerKind.error,
    };
    final retryLabel = switch (status) {
      _CacheDialogStatus.failed => '重试全部',
      _CacheDialogStatus.partial => '重试失败',
      _ => null,
    };

    return AppStatusBanner(
      key: bannerKey,
      kind: kind,
      icon: status == _CacheDialogStatus.running ? LucideIcons.refreshCw : null,
      title: _titleFor(status),
      subtitle: interrupted
          ? '缓存中断，请重试；已保存的图片不会删除。'
          : status == _CacheDialogStatus.running
          ? null
          : _subtitleFor(
              status: status,
              total: total,
              succeeded: succeeded,
              failed: failed,
            ),
      subtitleWidget: status == _CacheDialogStatus.running
          ? AppStatusBannerProgressLine(
              countLabel: '$processed / $total',
              percentLabel: '$percent%',
              value: fraction,
              barKey: const ValueKey('reference-cache-progress-bar'),
            )
          : null,
      actionLabel: retryLabel,
      onAction: onRetry,
      actionKey: retryLabel == null
          ? null
          : const ValueKey('reference-cache-retry'),
      footer: status == _CacheDialogStatus.running
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.info,
                  size: 15,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '提示：缓存过程中请保持网络连接，避免切换页面或锁屏。',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      height: 1.3,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            )
          : null,
    );
  }
}

String _titleFor(_CacheDialogStatus status) {
  return switch (status) {
    _CacheDialogStatus.running => '正在缓存参考图...',
    _CacheDialogStatus.success => '参考图缓存完成',
    _CacheDialogStatus.partial => '参考图缓存完成',
    _CacheDialogStatus.failed => '参考图缓存失败',
  };
}

String _subtitleFor({
  required _CacheDialogStatus status,
  required int total,
  required int succeeded,
  required int failed,
}) {
  return switch (status) {
    _CacheDialogStatus.running => '$succeeded / $total',
    _CacheDialogStatus.success => '$succeeded / $total 张成功，已保存到本地',
    _CacheDialogStatus.partial ||
    _CacheDialogStatus.failed => '$succeeded / $total 张成功 · $failed 张失败',
  };
}
