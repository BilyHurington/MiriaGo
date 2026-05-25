import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/reference_cache_file_stub.dart'
    if (dart.library.io) '../data/reference_cache_file_io.dart';
import '../data/reference_image_cache_stub.dart'
    if (dart.library.io) '../data/reference_image_cache_io.dart'
    as reference_image_cache;
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
  final Set<String> _selectedPointIds = {};
  String? _selectedWorkId;
  var _didUpdate = false;
  var _isSaving = false;
  var _selectionMode = false;

  List<PilgrimagePoint> get _visiblePoints {
    final selectedWorkId = _selectedWorkId;
    if (selectedWorkId == null) {
      return _plan.points;
    }

    return _plan.points
        .where((point) => point.work.id == selectedWorkId)
        .toList(growable: false);
  }

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
          title: Text(
            _selectionMode ? '已选 ${_selectedPointIds.length}' : '管理点位',
          ),
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
            if (!_isSaving && _plan.points.isNotEmpty)
              IconButton(
                tooltip: _selectionMode ? '退出多选' : '多选',
                onPressed: _toggleSelectionMode,
                icon: Icon(
                  _selectionMode ? Icons.close : Icons.checklist_rtl_outlined,
                ),
              ),
          ],
        ),
        body: _plan.points.isEmpty
            ? const _EmptyPointManager()
            : Stack(
                children: [
                  _selectionMode ? _buildSelectionList() : _buildReorderList(),
                  if (_selectionMode)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: _BatchActionBar(
                        selectedCount: _selectedPointIds.length,
                        allSelected:
                            _visiblePoints.isNotEmpty &&
                            _selectedPointIds.length == _visiblePoints.length,
                        isBusy: _isSaving,
                        onSelectAll: _selectAll,
                        onClear: _clearSelection,
                        onComplete: _completeSelected,
                        onReopen: _reopenSelected,
                        onDelete: _confirmDeleteSelected,
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildReorderList() {
    final visiblePoints = _visiblePoints;
    final canReorder = _selectedWorkId == null;

    if (!canReorder) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: visiblePoints.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _PointManagerHeader(
              plan: _plan,
              selectedWorkId: _selectedWorkId,
              onWorkSelected: _selectWorkFilter,
              onCacheFullReferences: _cacheFullReferenceImages,
            );
          }

          final point = visiblePoints[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PointManagerTile(
              index: index - 1,
              point: point,
              status: _statusFor(point),
              isBusy: _isSaving,
              selectionMode: false,
              selected: false,
              canDrag: false,
              onToggleSelected: () => _togglePointSelection(point),
              onSetCurrent: () => _setCurrent(point),
              onComplete: () => _complete(point),
              onReopen: () => _reopen(point),
              onDelete: () => _confirmDelete(point),
            ),
          );
        },
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      header: _PointManagerHeader(
        plan: _plan,
        selectedWorkId: _selectedWorkId,
        onWorkSelected: _selectWorkFilter,
        onCacheFullReferences: _cacheFullReferenceImages,
      ),
      itemCount: visiblePoints.length,
      buildDefaultDragHandles: false,
      onReorderItem: _handleReorder,
      itemBuilder: (context, index) {
        final point = visiblePoints[index];
        return _PointManagerTile(
          key: ValueKey(point.id),
          index: index,
          point: point,
          status: _statusFor(point),
          isBusy: _isSaving,
          selectionMode: false,
          selected: false,
          canDrag: true,
          onToggleSelected: () => _togglePointSelection(point),
          onSetCurrent: () => _setCurrent(point),
          onComplete: () => _complete(point),
          onReopen: () => _reopen(point),
          onDelete: () => _confirmDelete(point),
        );
      },
    );
  }

  Widget _buildSelectionList() {
    final visiblePoints = _visiblePoints;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 92),
      itemCount: visiblePoints.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _PointManagerHeader(
            plan: _plan,
            selectedWorkId: _selectedWorkId,
            onWorkSelected: _selectWorkFilter,
            onCacheFullReferences: _cacheFullReferenceImages,
          );
        }

        final point = visiblePoints[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _PointManagerTile(
            index: index - 1,
            point: point,
            status: _statusFor(point),
            isBusy: _isSaving,
            selectionMode: true,
            selected: _selectedPointIds.contains(point.id),
            canDrag: false,
            onToggleSelected: () => _togglePointSelection(point),
            onSetCurrent: () => _setCurrent(point),
            onComplete: () => _complete(point),
            onReopen: () => _reopen(point),
            onDelete: () => _confirmDelete(point),
          ),
        );
      },
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

  void _selectWorkFilter(String? workId) {
    setState(() {
      _selectedWorkId = workId;
      _selectedPointIds.removeWhere(
        (pointId) => !_visiblePoints.any((point) => point.id == pointId),
      );
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedPointIds.clear();
    });
  }

  void _togglePointSelection(PilgrimagePoint point) {
    setState(() {
      if (_selectedPointIds.contains(point.id)) {
        _selectedPointIds.remove(point.id);
      } else {
        _selectedPointIds.add(point.id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedPointIds
        ..clear()
        ..addAll(_visiblePoints.map((point) => point.id));
    });
  }

  void _clearSelection() {
    setState(_selectedPointIds.clear);
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

  Future<void> _confirmDeleteSelected() async {
    if (_selectedPointIds.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('批量删除点位'),
        content: Text('确定从计划中删除 ${_selectedPointIds.length} 个点位吗？'),
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

    final pointIds = {..._selectedPointIds};
    await _savePlanChange(
      action: () => widget.repository.deletePointsFromPlan(
        planId: _plan.id,
        pointIds: pointIds,
      ),
      failureMessage: '批量删除失败',
    );
  }

  Future<void> _setCurrent(PilgrimagePoint point) async {
    await _saveStatusChange(
      action: () => widget.repository.setCurrentPoint(
        planId: _plan.id,
        pointId: point.id,
      ),
      failureMessage: '当前目标保存失败',
    );
  }

  Future<void> _complete(PilgrimagePoint point) async {
    final completedPointIds = {..._plan.completedPointIds, point.id};
    final nextCurrentPointId = _plan.currentPointId == point.id
        ? _plan.points
              .where((candidate) => !completedPointIds.contains(candidate.id))
              .firstOrNull
              ?.id
        : _plan.currentPointId;

    await _saveStatusChange(
      action: () => widget.repository.completePoint(
        planId: _plan.id,
        pointId: point.id,
        nextCurrentPointId: nextCurrentPointId,
      ),
      failureMessage: '完成状态保存失败',
    );
  }

  Future<void> _reopen(PilgrimagePoint point) async {
    await _saveStatusChange(
      action: () =>
          widget.repository.reopenPoint(planId: _plan.id, pointId: point.id),
      failureMessage: '点位状态保存失败',
    );
  }

  Future<void> _completeSelected() async {
    final pointIds = {..._selectedPointIds};
    if (pointIds.isEmpty) {
      return;
    }

    await _saveStatusChange(
      action: () => widget.repository.completePoints(
        planId: _plan.id,
        pointIds: pointIds,
      ),
      failureMessage: '批量完成失败',
    );
  }

  Future<void> _reopenSelected() async {
    final pointIds = {..._selectedPointIds};
    if (pointIds.isEmpty) {
      return;
    }

    await _saveStatusChange(
      action: () =>
          widget.repository.reopenPoints(planId: _plan.id, pointIds: pointIds),
      failureMessage: '批量重新打开失败',
    );
  }

  Future<void> _savePlanChange({
    required Future<PilgrimagePlan> Function() action,
    required String failureMessage,
  }) async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updatedPlan = await action();
      if (!mounted) {
        return;
      }

      setState(() {
        _plan = updatedPlan;
        _selectedPointIds.removeWhere(
          (pointId) => !_plan.points.any((point) => point.id == pointId),
        );
        if (_selectedPointIds.isEmpty) {
          _selectionMode = false;
        }
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
      ).showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }

  Future<void> _saveStatusChange({
    required Future<void> Function() action,
    required String failureMessage,
  }) async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await action();
      final updatedPlan = await widget.repository.loadActivePlan();
      if (!mounted) {
        return;
      }

      setState(() {
        _plan = updatedPlan;
        _selectedPointIds.clear();
        _selectionMode = false;
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
      ).showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }

  Future<void> _cacheFullReferenceImages() async {
    final fullPoints = _plan.points
        .where(
          (point) =>
              point.referenceImageUrl != null &&
              !referenceFullCacheFileIsCurrent(
                path: point.referenceFullImagePath,
                imageUrl: point.referenceImageUrl,
              ),
        )
        .toList(growable: false);
    if (fullPoints.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前计划没有需要缓存的参考图')));
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('正在缓存完整参考图...')));

    var cached = 0;
    for (final point in fullPoints) {
      final path = await reference_image_cache.cacheReferenceFullImage(point);
      if (path == null) {
        continue;
      }
      final updatedPlan = await widget.repository.updatePointImageCache(
        planId: _plan.id,
        pointId: point.id,
        referenceThumbnailPath: point.referenceThumbnailPath,
        referenceFullImagePath: path,
      );
      cached += 1;
      if (!mounted) {
        return;
      }
      setState(() {
        _plan = updatedPlan;
        _didUpdate = true;
      });
      messenger.showSnackBar(
        SnackBar(content: Text('正在缓存完整参考图 $cached/${fullPoints.length}')),
      );
    }

    if (!mounted) {
      return;
    }

    messenger.showSnackBar(
      SnackBar(content: Text('已缓存 $cached/${fullPoints.length} 张完整参考图')),
    );
  }
}

class _PointManagerHeader extends StatelessWidget {
  const _PointManagerHeader({
    required this.plan,
    required this.selectedWorkId,
    required this.onWorkSelected,
    required this.onCacheFullReferences,
  });

  final PilgrimagePlan plan;
  final String? selectedWorkId;
  final ValueChanged<String?> onWorkSelected;
  final Future<void> Function() onCacheFullReferences;

  @override
  Widget build(BuildContext context) {
    final completedCount = plan.completedPointIds.length;
    final works = _worksForPlan(plan);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
            if (works.length > 1) ...[
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _WorkFilterChip(
                      label: '全部作品',
                      selected: selectedWorkId == null,
                      onSelected: () => onWorkSelected(null),
                    ),
                    for (final work in works) ...[
                      const SizedBox(width: 8),
                      _WorkFilterChip(
                        label: work.title,
                        selected: selectedWorkId == work.id,
                        onSelected: () => onWorkSelected(work.id),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => onCacheFullReferences(),
                icon: const Icon(Icons.download_for_offline_outlined, size: 18),
                label: const Text('缓存完整参考图'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PilgrimageWork> _worksForPlan(PilgrimagePlan plan) {
    final worksById = <String, PilgrimageWork>{};
    for (final work in plan.works) {
      worksById[work.id] = work;
    }
    for (final point in plan.points) {
      worksById[point.work.id] = point.work;
    }

    return worksById.values.toList(growable: false);
  }
}

class _WorkFilterChip extends StatelessWidget {
  const _WorkFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      selected: selected,
      selectedColor: AppColors.accent,
      backgroundColor: AppColors.surfaceMuted,
      side: BorderSide(color: selected ? AppColors.accent : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (_) => onSelected(),
    );
  }
}

class _PointManagerTile extends StatelessWidget {
  const _PointManagerTile({
    required this.index,
    required this.point,
    required this.status,
    required this.isBusy,
    required this.selectionMode,
    required this.selected,
    required this.canDrag,
    required this.onToggleSelected,
    required this.onSetCurrent,
    required this.onComplete,
    required this.onReopen,
    required this.onDelete,
    super.key,
  });

  final int index;
  final PilgrimagePoint point;
  final VisitStatus status;
  final bool isBusy;
  final bool selectionMode;
  final bool selected;
  final bool canDrag;
  final VoidCallback onToggleSelected;
  final VoidCallback onSetCurrent;
  final VoidCallback onComplete;
  final VoidCallback onReopen;
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
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: selectionMode && !isBusy ? onToggleSelected : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PointLeadingControl(
                  index: index,
                  isBusy: isBusy,
                  selectionMode: selectionMode,
                  selected: selected,
                  canDrag: canDrag,
                  onToggleSelected: onToggleSelected,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        point.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
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
                      const SizedBox(height: 4),
                      Text(
                        _cacheStatusText(point),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 5),
                      SizedBox(
                        height: 32,
                        child: Row(
                          children: [
                            Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _CacheStatusPill(point: point),
                            const Spacer(),
                            if (!selectionMode) ...[
                              _CompactTileButton(
                                tooltip: status == VisitStatus.completed
                                    ? '重新打开'
                                    : '标记完成',
                                onPressed: isBusy
                                    ? null
                                    : status == VisitStatus.completed
                                    ? onReopen
                                    : onComplete,
                                icon: Icon(
                                  status == VisitStatus.completed
                                      ? Icons.restart_alt
                                      : Icons.check_outlined,
                                  size: 22,
                                ),
                              ),
                              _CompactTileButton(
                                tooltip: '设为当前',
                                onPressed:
                                    isBusy || status == VisitStatus.current
                                    ? null
                                    : onSetCurrent,
                                icon: const Icon(Icons.flag_outlined, size: 22),
                              ),
                              _CompactTileButton(
                                tooltip: '删除点位',
                                onPressed: isBusy ? null : onDelete,
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 22,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _cacheStatusText(PilgrimagePoint point) {
    final fullCached = referenceFullCacheFileIsCurrent(
      path: point.referenceFullImagePath,
      imageUrl: point.referenceImageUrl,
    );
    return fullCached ? '缓存：已缓存' : '缓存：未缓存';
  }
}

class _CacheStatusPill extends StatelessWidget {
  const _CacheStatusPill({required this.point});

  final PilgrimagePoint point;

  @override
  Widget build(BuildContext context) {
    final fullCached = referenceFullCacheFileIsCurrent(
      path: point.referenceFullImagePath,
      imageUrl: point.referenceImageUrl,
    );
    final label = fullCached ? '已缓存' : '未缓存';
    final color = fullCached ? AppColors.accent : AppColors.accentDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _CompactTileButton extends StatelessWidget {
  const _CompactTileButton({
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

class _PointLeadingControl extends StatelessWidget {
  const _PointLeadingControl({
    required this.index,
    required this.isBusy,
    required this.selectionMode,
    required this.selected,
    required this.canDrag,
    required this.onToggleSelected,
  });

  final int index;
  final bool isBusy;
  final bool selectionMode;
  final bool selected;
  final bool canDrag;
  final VoidCallback onToggleSelected;

  @override
  Widget build(BuildContext context) {
    if (selectionMode) {
      return SizedBox(
        width: 54,
        child: Center(
          child: Checkbox(
            value: selected,
            onChanged: isBusy ? null : (_) => onToggleSelected(),
          ),
        ),
      );
    }

    if (!canDrag) {
      return const SizedBox(width: 54);
    }

    return ReorderableDragStartListener(
      index: index,
      enabled: !isBusy,
      child: const SizedBox(
        width: 54,
        child: Center(
          child: Icon(Icons.drag_indicator, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _BatchActionBar extends StatelessWidget {
  const _BatchActionBar({
    required this.selectedCount,
    required this.allSelected,
    required this.isBusy,
    required this.onSelectAll,
    required this.onClear,
    required this.onComplete,
    required this.onReopen,
    required this.onDelete,
  });

  final int selectedCount;
  final bool allSelected;
  final bool isBusy;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onComplete;
  final VoidCallback onReopen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedCount > 0;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: allSelected ? '清空' : '全选',
              onPressed: isBusy
                  ? null
                  : allSelected
                  ? onClear
                  : onSelectAll,
              icon: Icon(
                allSelected ? Icons.check_box : Icons.check_box_outline_blank,
              ),
            ),
            IconButton(
              tooltip: '清空',
              onPressed: isBusy || !hasSelection ? null : onClear,
              icon: const Icon(Icons.clear_all),
            ),
            const Spacer(),
            IconButton(
              tooltip: '标记完成',
              onPressed: isBusy || !hasSelection ? null : onComplete,
              icon: const Icon(Icons.check_outlined),
            ),
            IconButton(
              tooltip: '重新打开',
              onPressed: isBusy || !hasSelection ? null : onReopen,
              icon: const Icon(Icons.restart_alt),
            ),
            IconButton(
              tooltip: '删除',
              onPressed: isBusy || !hasSelection ? null : onDelete,
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
