import 'dart:async';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../widgets/app_status_banner.dart';
import 'reference_full_cache_runner.dart';

Future<void> showReferenceCacheProgressDialog({
  required BuildContext context,
  required Future<void> Function(
    void Function(ReferenceFullCacheProgress progress) onProgress,
  )
  run,
}) async {
  final runDone = Completer<void>();
  var runStarted = false;

  await showStatusBannerOverlay(
    context: context,
    builder: (dialogContext) {
      return ReferenceCacheProgressDialog(
        run: (onProgress) async {
          runStarted = true;
          try {
            await run(onProgress);
          } finally {
            if (!runDone.isCompleted) {
              runDone.complete();
            }
          }
        },
      );
    },
  );

  if (runStarted) {
    await runDone.future;
  }
}

Future<void> showReferenceCacheBannerDebugPreview(BuildContext context) {
  return showStatusBannerOverlay(
    context: context,
    builder: (dialogContext) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CacheBannerCard(
              bannerKey: const ValueKey('reference-cache-debug-running'),
              status: _CacheDialogStatus.running,
              total: 18,
              processed: 8,
              succeeded: 8,
              failed: 0,
            ),
            const SizedBox(height: 8),
            _CacheBannerCard(
              bannerKey: const ValueKey('reference-cache-debug-success'),
              status: _CacheDialogStatus.success,
              total: 18,
              processed: 18,
              succeeded: 18,
              failed: 0,
            ),
            const SizedBox(height: 8),
            _CacheBannerCard(
              bannerKey: const ValueKey('reference-cache-debug-partial'),
              status: _CacheDialogStatus.partial,
              total: 18,
              processed: 18,
              succeeded: 14,
              failed: 4,
            ),
            const SizedBox(height: 8),
            _CacheBannerCard(
              bannerKey: const ValueKey('reference-cache-debug-failed'),
              status: _CacheDialogStatus.failed,
              total: 18,
              processed: 18,
              succeeded: 0,
              failed: 18,
            ),
          ],
        ),
      );
    },
  );
}

class ReferenceCacheProgressDialog extends StatefulWidget {
  const ReferenceCacheProgressDialog({required this.run, super.key});

  final Future<void> Function(
    void Function(ReferenceFullCacheProgress progress) onProgress,
  )
  run;

  @override
  State<ReferenceCacheProgressDialog> createState() =>
      _ReferenceCacheProgressDialogState();
}

enum _CacheDialogStatus { running, success, partial, failed }

class _ReferenceCacheProgressDialogState
    extends State<ReferenceCacheProgressDialog> {
  var _isRunning = true;
  ReferenceFullCacheProgress? _progress;

  _CacheDialogStatus get _status {
    final progress = _progress;
    if (_isRunning || progress == null || !progress.done) {
      return _CacheDialogStatus.running;
    }
    if (progress.failed == 0) {
      return _CacheDialogStatus.success;
    }
    if (progress.succeeded == 0) {
      return _CacheDialogStatus.failed;
    }
    return _CacheDialogStatus.partial;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _start();
      }
    });
  }

  Future<void> _start() async {
    setState(() {
      _isRunning = true;
      final previous = _progress;
      if (previous != null && previous.done) {
        _progress = ReferenceFullCacheProgress(total: previous.total);
      }
    });
    try {
      await widget.run((progress) {
        if (!mounted) {
          return;
        }
        setState(() {
          _progress = progress;
        });
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      final current = _progress;
      setState(() {
        _progress = ReferenceFullCacheProgress(
          total: current?.total ?? 0,
          processed: current?.processed ?? 0,
          succeeded: current?.succeeded ?? 0,
          failed: (current?.failed ?? 0) > 0
              ? current!.failed
              : (current?.total ?? 0),
          done: true,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final progress = _progress;
    return _CacheBannerCard(
      bannerKey: const ValueKey('reference-cache-progress-dialog'),
      status: status,
      total: progress?.total ?? 0,
      processed: progress?.processed ?? 0,
      succeeded: progress?.succeeded ?? 0,
      failed: progress?.failed ?? 0,
      onRetry:
          status == _CacheDialogStatus.partial ||
              status == _CacheDialogStatus.failed
          ? _start
          : null,
    );
  }
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
  });

  final Key bannerKey;
  final _CacheDialogStatus status;
  final int total;
  final int processed;
  final int succeeded;
  final int failed;
  final VoidCallback? onRetry;

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
      icon: status == _CacheDialogStatus.running ? Icons.cached_outlined : null,
      title: _titleFor(status),
      subtitle: status == _CacheDialogStatus.running
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
                  Icons.info_outline,
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
