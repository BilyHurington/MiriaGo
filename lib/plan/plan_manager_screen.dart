import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/pilgrimage_repository.dart';
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

  @override
  Widget build(BuildContext context) {
    final plans = _plans;

    return Scaffold(
      appBar: AppBar(
        title: const Text('切换计划'),
        actions: [
          IconButton(
            tooltip: '新建计划',
            onPressed: _createEmptyPlan,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
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
              final plan = plans[index];
              return _PlanCard(
                plan: plan,
                selected: plan.id == _activePlan?.id,
                canDelete: plans.length > 1 && plan.id != _activePlan?.id,
                onSwitch: () => _switchPlan(plan),
                onDelete: () => _deletePlan(plan),
              );
            },
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemCount: plans.length,
          );
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.canDelete,
    required this.onSwitch,
    required this.onDelete,
  });

  final PilgrimagePlan plan;
  final bool selected;
  final bool canDelete;
  final VoidCallback onSwitch;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: selected ? AppColors.accent : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              selected ? Icons.check : Icons.route_outlined,
              color: selected ? Colors.white : AppColors.accentDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
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
              ],
            ),
          ),
          if (!selected)
            TextButton(onPressed: onSwitch, child: const Text('切换')),
          if (canDelete)
            IconButton(
              tooltip: '删除计划',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
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
