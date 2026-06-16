import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/pilgrimage_repository.dart';
import '../plan_transfer/import_export_screen.dart';
import '../widgets/confirm_action_dialog.dart';
import '../widgets/copyable_text.dart';
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
    final plans = _plans;
    if (plans == null || plans.length <= 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('至少需要保留一个计划')));
      return;
    }

    final confirmed = await showConfirmActionDialog(
      context,
      title: '删除计划',
      message: '将删除「${plan.name}」及其中的点位、片区、作品和巡礼记录。此操作无法撤销。',
      confirmLabel: '删除',
      icon: Icons.delete_outline,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }

    await widget.repository.deletePlan(plan.id);
    await _loadPlans();
  }

  Future<void> _editPlanInfo(PilgrimagePlan plan) async {
    final nameController = TextEditingController(text: plan.name);
    final areaController = TextEditingController(text: plan.area);
    final result = await showDialog<_PlanInfoFormResult>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑计划信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: '计划名称'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: areaController,
              decoration: const InputDecoration(labelText: '地区 / 区域'),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => Navigator.of(context).pop(
                _PlanInfoFormResult(
                  name: nameController.text.trim(),
                  area: areaController.text.trim(),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              _PlanInfoFormResult(
                name: nameController.text.trim(),
                area: areaController.text.trim(),
              ),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    nameController.dispose();
    areaController.dispose();
    if (result == null || result.name.isEmpty) {
      return;
    }

    final area = result.area.isEmpty ? '未设置区域' : result.area;
    if (result.name == plan.name && area == plan.area) {
      return;
    }

    await widget.repository.updatePlanInfo(
      planId: plan.id,
      name: result.name,
      area: area,
    );
    await _loadPlans();
  }

  Future<void> _openImportExport(PilgrimagePlan plan) async {
    final imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            ImportExportScreen(plan: plan, repository: widget.repository),
      ),
    );
    if (imported == true) {
      await _loadPlans();
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
                canDelete: plans.length > 1,
                onSwitch: () => _switchPlan(plan),
                onRename: () => _editPlanInfo(plan),
                onExport: () => _openImportExport(plan),
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

class _PlanInfoFormResult {
  const _PlanInfoFormResult({required this.name, required this.area});

  final String name;
  final String area;
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
    final summaryText =
        '${plan.area} / ${plan.points.length} 个点位 / ${_workCountText(plan)}';

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
          Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 42),
                child: CopyableText(
                  text: plan.name,
                  copyLabel: '计划名称',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: -5,
                child: _CompactPlanButton(
                  tooltip: '导入导出',
                  onPressed: onExport,
                  icon: const Icon(Icons.import_export_outlined, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          CopyableText(
            text: summaryText,
            copyText:
                '${plan.name}\n${plan.area}\n${plan.points.length} 个点位\n${_workCountText(plan)}',
            copyLabel: '计划信息',
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
                  tooltip: '编辑计划信息',
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
