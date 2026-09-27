import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../application/plan_session.dart';
import '../../../application/reference_cache_task.dart';
import '../../../application/settings_store.dart';
import '../../app/task_indicator.dart';
import '../../app/toast.dart';
import '../../components/components.dart';

/// 「缓存参考图」 for the active plan (old `_handleReferenceCachePressed`):
///
/// * a task for this plan is already running → reopen its progress;
/// * nothing to cache → 「当前计划没有需要缓存的参考图」;
/// * otherwise confirm (「缓存完整参考图」…) and start the background task.
///
/// Usable from any page (overview checklist, organize menu).
Future<void> startFullReferenceCache(BuildContext context) async {
  final session = context.read<PlanSession>();
  if (!session.isReady) return;
  final center = context.read<ReferenceCacheCenter>();
  final settings = context.read<SettingsStore>().settings;
  final toasts = context.read<ToastController>();
  final plan = session.plan;
  final task = center.taskFor(plan);
  if (task.isRunning) {
    await showReferenceCacheDetails(context, task);
    return;
  }
  final points = center.pointsNeedingCache(plan);
  if (points.isEmpty) {
    toasts.show(ToastData(kind: ToastKind.warning, title: '当前计划没有需要缓存的参考图'));
    return;
  }
  final confirmed = await showConfirmDialog(
    context,
    title: '缓存完整参考图',
    message: '将缓存当前计划中 ${points.length} 张完整参考图，可能需要较长时间和网络流量。',
    confirmLabel: '开始缓存',
    notice: '建议在 Wi-Fi 环境下进行缓存',
    emphasizedValues: ['${points.length} 张'],
  );
  if (!confirmed || !session.isReady || session.plan.id != plan.id) return;
  center.start(
    session.plan,
    imageSource: settings.anitabiImageSource,
    maxConcurrent: settings.mapThumbnailConcurrentLoads,
  );
}
