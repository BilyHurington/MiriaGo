import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../../application/plan_session.dart';
import '../../../../application/settings/cache_cleanup_service.dart';
import '../../../../data/pilgrimage_repository.dart';
import '../../../app/toast.dart';
import '../../../components/components.dart';
import '../settings_widgets.dart';

/// 清除缓存: choose plans and delete their downloaded full-reference caches.
class CacheCleanupSettingsSection extends StatefulWidget {
  const CacheCleanupSettingsSection({this.controller, super.key});

  /// Overridable for tests.
  final CacheCleanupController? controller;

  @override
  State<CacheCleanupSettingsSection> createState() =>
      _CacheCleanupSettingsSectionState();
}

class _CacheCleanupSettingsSectionState
    extends State<CacheCleanupSettingsSection> {
  late final CacheCleanupController _controller =
      widget.controller ??
      CacheCleanupController(repository: context.read<PilgrimageRepository>());

  @override
  void initState() {
    super.initState();
    unawaited(_controller.loadPlans());
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  Future<void> _clean() async {
    final session = context.read<PlanSession>();
    final outcome = await _controller.run(
      confirm: (scan) => showConfirmDialog(
        context,
        title: '清除参考图缓存？',
        message: CacheCleanupController.confirmMessage(scan),
        confirmLabel: '清除',
      ),
    );
    if (!mounted) return;
    switch (outcome) {
      case CacheScanFailed(:final error):
        context.showToast(
          '缓存扫描失败',
          kind: ToastKind.error,
          message: error.toString(),
        );
      case CacheNothingToClean():
        context.showToast('所选计划没有可清理的下载缓存', kind: ToastKind.success);
      case CacheCleanupCancelled():
        break;
      case CacheCleanupDone():
        context.showToast(
          outcome.title,
          kind: outcome.hasFailures ? ToastKind.warning : ToastKind.success,
          message: outcome.message,
        );
        // Cleared cache paths belong to the active plan too.
        if (session.isReady) unawaited(session.refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final c = context.colors;
        final text = context.text;
        final plans = _controller.plans;
        if (_controller.loadError != null && plans == null) {
          return SettingsGroup(
            title: '计划',
            children: [
              ErrorState(
                title: '计划列表读取失败',
                compact: true,
                onRetry: _controller.loadPlans,
              ),
            ],
          );
        }
        if (plans == null) {
          return const SettingsGroup(
            title: '计划',
            children: [
              SettingsBlock(
                child: Column(
                  children: [
                    Skeleton.line(),
                    SizedBox(height: Space.x3),
                    Skeleton.line(widthFactor: 0.7),
                  ],
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsGroup(
              title: '选择计划',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MiriaIconButton(
                    icon: Symbols.select_all_rounded,
                    tooltip: '全选',
                    compact: true,
                    onPressed: _controller.busy ? null : _controller.selectAll,
                  ),
                  MiriaIconButton(
                    icon: Symbols.deselect_rounded,
                    tooltip: '清空',
                    compact: true,
                    onPressed:
                        _controller.selectedPlanIds.isEmpty || _controller.busy
                        ? null
                        : _controller.clearSelection,
                  ),
                ],
              ),
              children: [
                SettingsNote(_controller.selectionSummary),
                for (final plan in plans)
                  ListRow(
                    key: ValueKey('cache-plan-${plan.id}'),
                    leading: Checkbox(
                      value: _controller.isSelected(plan.id),
                      onChanged: _controller.busy
                          ? null
                          : (value) =>
                                _controller.toggle(plan.id, value == true),
                    ),
                    title: plan.name,
                    subtitle: '${plan.area} / ${plan.points.length} 个点位',
                    enabled: !_controller.busy,
                    onTap: () => _controller.toggle(
                      plan.id,
                      !_controller.isSelected(plan.id),
                    ),
                  ),
              ],
            ),
            SettingsGroup(
              title: '缓存内容',
              children: [
                SettingsBlock(
                  child: Container(
                    padding: const EdgeInsets.all(Space.x3),
                    decoration: BoxDecoration(
                      color: c.canvas,
                      borderRadius: Radii.smAll,
                      border: Border.all(color: c.hairline),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: c.primaryContainer,
                            borderRadius: Radii.smAll,
                          ),
                          child: Icon(
                            Symbols.photo_library_rounded,
                            size: 21,
                            color: c.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: Space.x3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('完整参考图缓存', style: text.titleSmall),
                              const SizedBox(height: Space.x1),
                              Text(
                                '清除相机参考和大图查看使用的完整参考图。缩略图缓存会保留，以保持列表和地图加载速度。',
                                style: text.bodySmall?.copyWith(
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            MiriaButton(
              key: const ValueKey('cache-cleanup-button'),
              label: _controller.actionLabel,
              icon: Symbols.cleaning_services_rounded,
              loading: _controller.busy && _controller.total == 0,
              expand: true,
              onPressed: _controller.canClean ? _clean : null,
            ),
            if (_controller.busy && _controller.total > 0) ...[
              const SizedBox(height: Space.x2),
              LinearProgressIndicator(
                value: _controller.completed / _controller.total,
              ),
            ],
          ],
        );
      },
    );
  }
}
