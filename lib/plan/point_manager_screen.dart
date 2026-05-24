import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/pilgrimage_repository.dart';
import 'pilgrimage_models.dart';

class PointManagerScreen extends StatefulWidget {
  const PointManagerScreen({
    required this.plan,
    required this.repository,
    super.key,
  });

  final PilgrimagePlan plan;
  final PilgrimageRepository repository;

  @override
  State<PointManagerScreen> createState() => _PointManagerScreenState();
}

class _PointManagerScreenState extends State<PointManagerScreen> {
  late PilgrimagePlan _plan = widget.plan;
  var _didUpdate = false;
  var _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }

        Navigator.of(context).pop(_didUpdate);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '返回',
            onPressed: () => Navigator.of(context).pop(_didUpdate),
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('管理点位'),
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
        body: _plan.points.isEmpty
            ? const _EmptyPointManager()
            : ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                header: _PointManagerHeader(plan: _plan),
                itemCount: _plan.points.length,
                buildDefaultDragHandles: false,
                onReorderItem: _handleReorder,
                itemBuilder: (context, index) {
                  final point = _plan.points[index];
                  return Padding(
                    key: ValueKey(point.id),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PointManagerTile(
                      index: index,
                      point: point,
                      status: _statusFor(point),
                      isBusy: _isSaving,
                      onDelete: () => _confirmDelete(point),
                    ),
                  );
                },
              ),
      ),
    );
  }

  VisitStatus _statusFor(PilgrimagePoint point) {
    if (_plan.completedPointIds.contains(point.id)) {
      return VisitStatus.completed;
    }

    if (_plan.currentPointId == point.id) {
      return VisitStatus.current;
    }

    return VisitStatus.pending;
  }

  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    if (_isSaving) {
      return;
    }

    final points = [..._plan.points];
    final oldPointIndex = oldIndex;
    final point = points.removeAt(oldPointIndex);
    points.insert(newIndex, point);

    setState(() {
      _plan = _plan.copyWith(points: points);
      _isSaving = true;
    });

    try {
      final updatedPlan = await widget.repository.reorderPoints(
        planId: _plan.id,
        pointIds: points.map((point) => point.id).toList(growable: false),
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _plan = updatedPlan;
        _didUpdate = true;
        _isSaving = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _plan = widget.plan;
        _isSaving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('点位顺序保存失败')));
    }
  }

  Future<void> _confirmDelete(PilgrimagePoint point) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除点位'),
        content: Text('确定从计划中删除「${point.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updatedPlan = await widget.repository.deletePointFromPlan(
        planId: _plan.id,
        pointId: point.id,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _plan = updatedPlan;
        _didUpdate = true;
        _isSaving = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('点位删除失败')));
    }
  }
}

class _PointManagerHeader extends StatelessWidget {
  const _PointManagerHeader({required this.plan});

  final PilgrimagePlan plan;

  @override
  Widget build(BuildContext context) {
    final completedCount = plan.completedPointIds.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.route_outlined, color: AppColors.accentDark),
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
                    '${plan.points.length} 个点位 / 已完成 $completedCount',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointManagerTile extends StatelessWidget {
  const _PointManagerTile({
    required this.index,
    required this.point,
    required this.status,
    required this.isBusy,
    required this.onDelete,
  });

  final int index;
  final PilgrimagePoint point;
  final VisitStatus status;
  final bool isBusy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (status) {
      VisitStatus.current => AppColors.accent,
      VisitStatus.completed => AppColors.textSecondary,
      VisitStatus.pending => AppColors.accentDark,
    };
    final statusText = switch (status) {
      VisitStatus.current => '当前目标',
      VisitStatus.completed => '已完成',
      VisitStatus.pending => '待访问',
    };

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              enabled: !isBusy,
              child: const SizedBox(
                width: 38,
                height: 44,
                child: Icon(
                  Icons.drag_indicator,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          point.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${point.work.title} / ${point.subtitle} / ${point.episodeLabel}',
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
            IconButton(
              tooltip: '删除点位',
              onPressed: isBusy ? null : onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPointManager extends StatelessWidget {
  const _EmptyPointManager();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '还没有可以管理的点位',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 15,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
