import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../app_theme.dart';
import '../data/pilgrimage_repository.dart';
import '../plan_transfer/plan_package.dart';
import '../plan_transfer/plan_package_file_stub.dart'
    if (dart.library.io) '../plan_transfer/plan_package_file_io.dart';
import '../widgets/snackbar_helper.dart';
import 'pilgrimage_models.dart';

class PlanManagerScreen extends StatefulWidget {
  const PlanManagerScreen({required this.repository, super.key});

  final PilgrimageRepository repository;

  @override
  State<PlanManagerScreen> createState() => _PlanManagerScreenState();
}

class _PlanManagerScreenState extends State<PlanManagerScreen> {
  List<PilgrimagePlan>? _plans;
  PilgrimagePlan? _activePlan;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _error = null;
    });

    try {
      final plans = await widget.repository.loadPlans();
      final activePlan = await widget.repository.loadActivePlan();
      if (!mounted) {
        return;
      }

      setState(() {
        _plans = plans;
        _activePlan = activePlan;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error;
      });
    }
  }

  Future<void> _switchPlan(PilgrimagePlan plan) async {
    await widget.repository.setActivePlan(plan.id);
    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  Future<void> _createEmptyPlan() async {
    final planNumber = (_plans?.length ?? 0) + 1;
    await widget.repository.createPlan(
      name: '新巡礼计划 $planNumber',
      area: '未设置区域',
    );
    await _loadPlans();
  }

  Future<void> _deletePlan(PilgrimagePlan plan) async {
    await widget.repository.deletePlan(plan.id);
    await _loadPlans();
  }

  Future<void> _renamePlan(PilgrimagePlan plan) async {
    final controller = TextEditingController(text: plan.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名计划'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '计划名称'),
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || name == plan.name) {
      return;
    }

    await widget.repository.renamePlan(planId: plan.id, name: name);
    await _loadPlans();
  }

  Future<void> _exportPlan(PilgrimagePlan plan) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showReplacingSnackBar(
      SnackBar(content: Text('正在导出「${plan.name}」...')),
    );

    try {
      final records = await widget.repository.loadVisitRecords(plan.id);
      final path = await exportPlanPackageToFile(
        PlanPackage(plan: plan, visitRecords: records),
      );
      if (path == null) {
        messenger.showReplacingSnackBar(
          const SnackBar(content: Text('当前平台暂不支持导出计划文件')),
        );
        return;
      }

      await Share.shareXFiles(
        [
          XFile(
            path,
            mimeType: seichiPlanMimeType,
            name: '${plan.name}.$seichiPlanFileExtension',
          ),
        ],
        subject: plan.name,
        text: '圣地巡礼助手计划：${plan.name}',
      );
    } catch (_) {
      messenger.showReplacingSnackBar(const SnackBar(content: Text('计划导出失败')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = _plans;

    return Scaffold(
      appBar: AppBar(title: const Text('切换计划')),
      body: Builder(
        builder: (context) {
          if (_error != null) {
            return _ErrorState(onRetry: _loadPlans);
          }

          if (plans == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _CreatePlanButton(onPressed: _createEmptyPlan);
              }

              final plan = plans[index - 1];
              return _PlanCard(
                plan: plan,
                selected: plan.id == _activePlan?.id,
                canDelete: plans.length > 1 && plan.id != _activePlan?.id,
                onSwitch: () => _switchPlan(plan),
                onRename: () => _renamePlan(plan),
                onExport: () => _exportPlan(plan),
                onDelete: () => _deletePlan(plan),
              );
            },
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemCount: plans.length + 1,
          );
        },
      ),
    );
  }
}

class _CreatePlanButton extends StatelessWidget {
  const _CreatePlanButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('新建计划'),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.canDelete,
    required this.onSwitch,
    required this.onRename,
    required this.onExport,
    required this.onDelete,
  });

  final PilgrimagePlan plan;
  final bool selected;
  final bool canDelete;
  final VoidCallback onSwitch;
  final VoidCallback onRename;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusText = selected ? '当前计划' : '可切换';
    final statusColor = selected ? AppColors.accent : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _CompactPlanButton(
                tooltip: '导出计划',
                onPressed: onExport,
                icon: const Icon(Icons.ios_share_outlined, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${plan.area} / ${plan.points.length} 个点位 / ${_workCountText(plan)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 32,
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_circle : Icons.route_outlined,
                  color: statusColor,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const Spacer(),
                if (!selected)
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: onSwitch,
                    child: const Text('切换'),
                  ),
                _CompactPlanButton(
                  tooltip: '重命名计划',
                  onPressed: onRename,
                  icon: const Icon(Icons.edit_outlined, size: 22),
                ),
                if (canDelete)
                  _CompactPlanButton(
                    tooltip: '删除计划',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 22),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _workCountText(PilgrimagePlan plan) {
    final count = plan.works.isNotEmpty
        ? plan.works.length
        : plan.points.map((point) => point.work.id).toSet().length;
    return '$count 部作品';
  }
}

class _CompactPlanButton extends StatelessWidget {
  const _CompactPlanButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 36, height: 32),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: icon,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('重新加载计划'),
      ),
    );
  }
}
