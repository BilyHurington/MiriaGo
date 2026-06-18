import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../app_theme.dart';
import '../data/pilgrimage_repository.dart';
import '../widgets/snackbar_helper.dart';
import '../camera_reference/camerawesome_reference_screen.dart';
import '../point_detail/point_detail_sheet.dart';
import '../records/point_visit_records_screen.dart';
import '../records/visit_record_detail_screen.dart';
import '../map/map_tile_config.dart';
import 'plan_group_utils.dart';
import 'pilgrimage_models.dart';
import 'pilgrimage_plan_controller.dart';
import 'reference_full_cache_runner.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({
    required this.controller,
    required this.settings,
    required this.repository,
    required this.onOpenMap,
    required this.onOpenPlanManager,
    required this.onOpenAddPoints,
    required this.onOpenPointManager,
    required this.onOpenImportExport,
    super.key,
  });

  final PilgrimagePlanController controller;
  final AppSettings settings;
  final PilgrimageRepository repository;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenPlanManager;
  final VoidCallback onOpenAddPoints;
  final VoidCallback onOpenPointManager;
  final VoidCallback onOpenImportExport;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  int _selectedGroupIndex = 0;
  PointSortMode _sortMode = PointSortMode.plan;
  bool _sortDescending = false;
  bool _showMap = false;
  bool _showVirtualLocation = false;
  bool _isLocating = false;
  bool _isCachingFullReferences = false;
  ReferenceFullCacheProgress? _fullReferenceCacheProgress;
  double _mapHeightRatio = 0.42;
  LatLng? _currentLocation;
  final _pointListController = ScrollController();

  PilgrimagePlanController get controller => widget.controller;

  AppSettings get settings => widget.settings;

  @override
  void dispose() {
    _pointListController.dispose();
    super.dispose();
  }

  void _selectGroup(int index, List<PlanGroupBucket> groups) {
    setState(() {
      _selectedGroupIndex = index.clamp(0, groups.length - 1);
      _showMap = false;
    });
  }

  void _selectPoint(PilgrimagePoint point, List<PlanGroupBucket> groups) {
    final nextGroupIndex = groups.indexWhere((group) {
      if (point.groupId == null) {
        return group.isUngrouped;
      }
      return group.id == point.groupId;
    });
    setState(() {
      if (nextGroupIndex >= 0) {
        _selectedGroupIndex = nextGroupIndex;
      }
    });
    controller.selectPoint(point);
  }

  void _resizeMap(double deltaY, double viewportHeight) {
    if (!_showMap) {
      return;
    }
    setState(() {
      _mapHeightRatio = (_mapHeightRatio + deltaY / viewportHeight).clamp(
        0.22,
        0.58,
      );
    });
  }

  Future<void> _toggleCurrentLocation() async {
    if (_showVirtualLocation && _currentLocation != null) {
      setState(() {
        _showVirtualLocation = false;
      });
      return;
    }

    setState(() {
      _isLocating = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('定位服务未开启。');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showSnackBar('需要定位权限来显示当前位置。');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _showVirtualLocation = true;
      });
    } on TimeoutException {
      _showSnackBar('定位超时，请稍后重试。');
    } catch (_) {
      _showSnackBar('定位失败，请检查权限和定位服务。');
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = controller.plan;
    final groups = planGroupBuckets(plan, controller.completedPointIds);
    if (_selectedGroupIndex >= groups.length) {
      _selectedGroupIndex = groups.isEmpty ? 0 : groups.length - 1;
    }
    final selectedGroup = groups.isEmpty ? null : groups[_selectedGroupIndex];
    final displayPoints = selectedGroup == null
        ? const <PilgrimagePoint>[]
        : displayPointsForGroup(
            selectedGroup,
            sortMode: _sortMode,
            descending: _sortDescending,
            currentLocation: _currentLocation,
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(plan.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          _ReferenceCacheIconButton(
            isCaching: _isCachingFullReferences,
            progress: _fullReferenceCacheProgress,
            onPressed: _handleReferenceCachePressed,
          ),
          PopupMenuButton<_PlanMenuAction>(
            tooltip: '计划操作',
            icon: const Icon(Icons.more_horiz),
            onSelected: (action) {
              switch (action) {
                case _PlanMenuAction.switchPlan:
                  widget.onOpenPlanManager();
                case _PlanMenuAction.addPoints:
                  widget.onOpenAddPoints();
                case _PlanMenuAction.managePoints:
                  widget.onOpenPointManager();
                case _PlanMenuAction.importExport:
                  widget.onOpenImportExport();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _PlanMenuAction.switchPlan,
                child: ListTile(
                  leading: Icon(Icons.swap_horiz),
                  title: Text('切换计划'),
                ),
              ),
              PopupMenuItem(
                value: _PlanMenuAction.addPoints,
                child: ListTile(
                  leading: Icon(Icons.add_location_alt_outlined),
                  title: Text('添加点位'),
                ),
              ),
              PopupMenuItem(
                value: _PlanMenuAction.managePoints,
                child: ListTile(
                  leading: Icon(Icons.tune_outlined),
                  title: Text('管理计划'),
                ),
              ),
              PopupMenuItem(
                value: _PlanMenuAction.importExport,
                child: ListTile(
                  leading: Icon(Icons.import_export_outlined),
                  title: Text('导入导出'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (selectedGroup == null || controller.points.isEmpty)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _WorkHeader(plan: plan),
                  const SizedBox(height: 16),
                  _EmptyPlanCard(onAddPoints: widget.onOpenAddPoints),
                ],
              ),
            )
          else ...[
            if (!_showMap) _PlanMetaStrip(plan: plan),
            _GroupSwitcher(
              groups: groups,
              selectedIndex: _selectedGroupIndex,
              onSelectGroup: (index) => _selectGroup(index, groups),
            ),
            _PlanGroupControls(
              plan: plan,
              group: selectedGroup,
              showMap: _showMap,
              sortMode: _sortMode,
              sortDescending: _sortDescending,
              mapHeightRatio: _mapHeightRatio,
              settings: settings,
              showVirtualLocation: _showVirtualLocation,
              isLocating: _isLocating,
              currentLocation: _currentLocation,
              selectedPointId: controller.selectedPoint?.id,
              onSetSortMode: (mode) {
                setState(() {
                  _sortMode = mode;
                });
              },
              onToggleSortDirection: () {
                setState(() {
                  _sortDescending = !_sortDescending;
                });
              },
              onToggleMap: () {
                setState(() {
                  _showMap = !_showMap;
                });
              },
              onResizeMap: _resizeMap,
              onToggleVirtualLocation: _toggleCurrentLocation,
              onSelectPoint: (point) => _selectPoint(point, groups),
              completedPointIds: controller.completedPointIds,
            ),
            Expanded(
              child: ListView(
                controller: _pointListController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  for (final point in displayPoints) ...[
                    _PlanPointTile(
                      point: point,
                      status: controller.statusFor(point),
                      recordCount: controller.recordsForPoint(point.id).length,
                      onTap: () {
                        _selectPoint(point, groups);
                        _showPointDetail(context, point);
                      },
                      onOpenCamera: () => _openCamera(context, point),
                      onComplete: () => controller.completePoint(point),
                      onReopen: () => controller.reopenPoint(point),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openCamera(BuildContext context, PilgrimagePoint point) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CamerawesomeReferenceScreen(
          point: point,
          controller: controller,
          settings: settings,
        ),
      ),
    );
  }

  void _showPointDetail(BuildContext context, PilgrimagePoint point) {
    PointDetailSheet.show(
      context,
      point: point,
      status: controller.statusFor(point),
      onSetCurrent: () => controller.setCurrentPoint(point),
      onOpenCamera: () => _openCamera(context, point),
      onComplete: () => controller.statusFor(point) == VisitStatus.completed
          ? controller.reopenPoint(point)
          : controller.completePoint(point),
      onReplaceReference: (point, image) => controller.updatePointImageCache(
        point,
        referenceThumbnailPath: image.thumbnailPath,
        referenceFullImagePath: image.fullImagePath,
      ),
      groups: controller.plan.groups,
      onMoveToGroup: controller.movePointToGroup,
      records: controller.recordsForPoint(point.id),
      onOpenRecords: () => _openPointRecords(context, point),
      onOpenRecord: (record) => _openRecordDetail(context, record),
    );
  }

  void _openPointRecords(BuildContext context, PilgrimagePoint point) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PointVisitRecordsScreen(point: point, controller: controller),
      ),
    );
  }

  void _openRecordDetail(BuildContext context, PilgrimageVisitRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VisitRecordDetailScreen(
          record: record,
          point: controller.pointById(record.pointId),
          controller: controller,
          onDelete: () => controller.deleteVisitRecord(record),
        ),
      ),
    );
  }

  Future<void> _handleReferenceCachePressed() async {
    if (_isCachingFullReferences) {
      _showSnackBar(_fullReferenceCacheProgress?.label ?? '正在缓存完整参考图...');
      return;
    }

    final points = pointsNeedingFullReferenceCache(controller.points);
    if (points.isEmpty) {
      _showSnackBar('当前计划没有需要缓存的参考图');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('缓存完整参考图'),
        content: Text('将缓存当前计划中 ${points.length} 张完整参考图，可能需要较长时间和网络流量。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('开始缓存'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _cacheFullReferenceImages();
  }

  Future<void> _cacheFullReferenceImages() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_isCachingFullReferences) {
      return;
    }
    setState(() {
      _isCachingFullReferences = true;
      _fullReferenceCacheProgress = null;
    });
    messenger.showReplacingSnackBar(
      const SnackBar(content: Text('已开始缓存完整参考图')),
    );
    try {
      await cacheFullReferenceImages(
        plan: controller.plan,
        repository: widget.repository,
        onPlanUpdated: controller.replacePlan,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _fullReferenceCacheProgress = progress;
          });
        },
      );
    } finally {
      if (mounted) {
        final progress = _fullReferenceCacheProgress;
        setState(() {
          _isCachingFullReferences = false;
        });
        if (progress != null) {
          messenger.showReplacingSnackBar(
            SnackBar(content: Text(progress.label)),
          );
        }
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showReplacingSnackBar(SnackBar(content: Text(message)));
  }
}

enum _PlanMenuAction { switchPlan, addPoints, managePoints, importExport }

class _ReferenceCacheIconButton extends StatelessWidget {
  const _ReferenceCacheIconButton({
    required this.isCaching,
    required this.progress,
    required this.onPressed,
  });

  final bool isCaching;
  final ReferenceFullCacheProgress? progress;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tooltip = isCaching ? progress?.label ?? '正在缓存完整参考图' : '缓存完整参考图';
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: isCaching
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download_for_offline_outlined),
    );
  }
}

class _GroupSwitcher extends StatelessWidget {
  const _GroupSwitcher({
    required this.groups,
    required this.selectedIndex,
    required this.onSelectGroup,
  });

  final List<PlanGroupBucket> groups;
  final int selectedIndex;
  final ValueChanged<int> onSelectGroup;

  @override
  Widget build(BuildContext context) {
    final group = groups[selectedIndex];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: selectedIndex == 0
                ? null
                : () => onSelectGroup(selectedIndex - 1),
            icon: const Icon(Icons.chevron_left),
            tooltip: '上一个片区',
          ),
          Expanded(
            child: FilledButton.tonal(
              onPressed: () => _showGroupPicker(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
              ),
              child: Text(
                group.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          IconButton(
            onPressed: selectedIndex == groups.length - 1
                ? null
                : () => onSelectGroup(selectedIndex + 1),
            icon: const Icon(Icons.chevron_right),
            tooltip: '下一个片区',
          ),
        ],
      ),
    );
  }

  void _showGroupPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: groups.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final group = groups[index];
              return ListTile(
                selected: index == selectedIndex,
                selectedTileColor: AppColors.accent.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                leading: Icon(
                  group.isUngrouped
                      ? Icons.inventory_2_outlined
                      : Icons.folder_outlined,
                ),
                title: Text(group.name),
                subtitle: Text(group.anchorLabel),
                trailing: Text(
                  '${group.completedCount} / ${group.points.length}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  onSelectGroup(index);
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _PlanGroupControls extends StatelessWidget {
  const _PlanGroupControls({
    required this.plan,
    required this.group,
    required this.showMap,
    required this.sortMode,
    required this.sortDescending,
    required this.mapHeightRatio,
    required this.settings,
    required this.showVirtualLocation,
    required this.isLocating,
    required this.currentLocation,
    required this.selectedPointId,
    required this.completedPointIds,
    required this.onSetSortMode,
    required this.onToggleSortDirection,
    required this.onToggleMap,
    required this.onResizeMap,
    required this.onToggleVirtualLocation,
    required this.onSelectPoint,
  });

  final PilgrimagePlan plan;
  final PlanGroupBucket group;
  final bool showMap;
  final PointSortMode sortMode;
  final bool sortDescending;
  final double mapHeightRatio;
  final AppSettings settings;
  final bool showVirtualLocation;
  final bool isLocating;
  final LatLng? currentLocation;
  final String? selectedPointId;
  final Set<String> completedPointIds;
  final ValueChanged<PointSortMode> onSetSortMode;
  final VoidCallback onToggleSortDirection;
  final VoidCallback onToggleMap;
  final void Function(double deltaY, double viewportHeight) onResizeMap;
  final VoidCallback onToggleVirtualLocation;
  final ValueChanged<PilgrimagePoint> onSelectPoint;

  @override
  Widget build(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final safePadding = MediaQuery.paddingOf(context);
    final maxMapHeight =
        (viewportHeight -
                safePadding.top -
                safePadding.bottom -
                kToolbarHeight -
                kBottomNavigationBarHeight -
                210)
            .clamp(150.0, 490.0);
    final mapHeight = (viewportHeight * mapHeightRatio).clamp(
      150.0,
      maxMapHeight,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
      child: Column(
        children: [
          if (!showMap) ...[
            _GroupSummary(group: group),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: _SortOrderControl(
                  mode: sortMode,
                  descending: sortDescending,
                  onChanged: onSetSortMode,
                  onToggleDirection: onToggleSortDirection,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onToggleMap,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(74, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                icon: Icon(showMap ? Icons.map : Icons.map_outlined, size: 18),
                label: Text(showMap ? '收起地图' : '地图'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (showMap) ...[
            _PlanInlineMap(
              group: group,
              completedPointIds: completedPointIds,
              selectedPointId: selectedPointId,
              showVirtualLocation: showVirtualLocation,
              isLocating: isLocating,
              currentLocation: currentLocation,
              height: mapHeight,
              settings: settings,
              onSelectPoint: onSelectPoint,
              onToggleVirtualLocation: onToggleVirtualLocation,
              onDrag: (deltaY) => onResizeMap(deltaY, viewportHeight),
            ),
            _MapResizeHandle(
              onDrag: (deltaY) => onResizeMap(deltaY, viewportHeight),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupSummary extends StatelessWidget {
  const _GroupSummary({required this.group});

  final PlanGroupBucket group;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  group.isUngrouped
                      ? Icons.inventory_2_outlined
                      : Icons.flag_outlined,
                  color: AppColors.accentDark,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group.anchorLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _GroupMetric(label: '点位', value: '${group.points.length}'),
                _GroupMetric(label: '完成', value: '${group.completedCount}'),
                _GroupMetric(label: '模式', value: group.orderModeLabel),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupMetric extends StatelessWidget {
  const _GroupMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortOrderControl extends StatelessWidget {
  const _SortOrderControl({
    required this.mode,
    required this.descending,
    required this.onChanged,
    required this.onToggleDirection,
  });

  final PointSortMode mode;
  final bool descending;
  final ValueChanged<PointSortMode> onChanged;
  final VoidCallback onToggleDirection;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: MenuAnchor(
                builder: (context, controller, child) {
                  return InkWell(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(8),
                    ),
                    onTap: () {
                      if (controller.isOpen) {
                        controller.close();
                      } else {
                        controller.open();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.sort_outlined, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _sortModeLabel(mode),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          const Icon(Icons.expand_more, size: 18),
                        ],
                      ),
                    ),
                  );
                },
                menuChildren: [
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.format_list_numbered),
                    onPressed: () => onChanged(PointSortMode.plan),
                    child: const Text('默认计划顺序'),
                  ),
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.near_me_outlined),
                    onPressed: () => onChanged(PointSortMode.distance),
                    child: const Text('按距离当前位置'),
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 24,
              child: VerticalDivider(width: 1, color: AppColors.border),
            ),
            Tooltip(
              message: _sortDirectionTooltip(mode, descending),
              child: InkWell(
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(8),
                ),
                onTap: onToggleDirection,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    descending ? Icons.south_outlined : Icons.north_outlined,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _sortModeLabel(PointSortMode mode) {
  return switch (mode) {
    PointSortMode.plan => '默认计划',
    PointSortMode.distance => '按距离',
  };
}

String _sortDirectionTooltip(PointSortMode mode, bool descending) {
  return switch (mode) {
    PointSortMode.plan => descending ? '反序' : '正序',
    PointSortMode.distance => descending ? '远到近' : '近到远',
  };
}

class _PlanInlineMap extends StatefulWidget {
  const _PlanInlineMap({
    required this.group,
    required this.completedPointIds,
    required this.selectedPointId,
    required this.showVirtualLocation,
    required this.isLocating,
    required this.currentLocation,
    required this.height,
    required this.settings,
    required this.onSelectPoint,
    required this.onToggleVirtualLocation,
    required this.onDrag,
  });

  final PlanGroupBucket group;
  final Set<String> completedPointIds;
  final String? selectedPointId;
  final bool showVirtualLocation;
  final bool isLocating;
  final LatLng? currentLocation;
  final double height;
  final AppSettings settings;
  final ValueChanged<PilgrimagePoint> onSelectPoint;
  final VoidCallback onToggleVirtualLocation;
  final ValueChanged<double> onDrag;

  @override
  State<_PlanInlineMap> createState() => _PlanInlineMapState();
}

class _PlanInlineMapState extends State<_PlanInlineMap> {
  final MapController _mapController = MapController();

  @override
  void didUpdateWidget(covariant _PlanInlineMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentLocation = widget.currentLocation;
    if (widget.showVirtualLocation &&
        currentLocation != null &&
        currentLocation != oldWidget.currentLocation) {
      _mapController.move(currentLocation, 16);
      return;
    }

    if (widget.selectedPointId != oldWidget.selectedPointId) {
      final point = _selectedPoint;
      if (point != null) {
        _mapController.move(point.position, 16);
        return;
      }
    }

    if (widget.group.id != oldWidget.group.id) {
      _mapController.move(_initialCenter, 15.2);
    }
  }

  PilgrimagePoint? get _selectedPoint {
    final selectedPointId = widget.selectedPointId;
    if (selectedPointId == null) {
      return null;
    }
    for (final point in widget.group.points) {
      if (point.id == selectedPointId) {
        return point;
      }
    }
    return null;
  }

  LatLng get _initialCenter {
    final selectedPoint = _selectedPoint;
    if (selectedPoint != null) {
      return selectedPoint.position;
    }
    if (widget.showVirtualLocation && widget.currentLocation != null) {
      return widget.currentLocation!;
    }
    return groupMapCenter(widget.group);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _initialCenter,
                  initialZoom: 15.2,
                  minZoom: 4,
                  maxZoom: 19,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  configuredMapTileLayer(widget.settings),
                  MarkerLayer(
                    markers: [
                      for (final point in widget.group.points)
                        Marker(
                          point: point.position,
                          width: point.id == widget.selectedPointId ? 34 : 28,
                          height: point.id == widget.selectedPointId ? 34 : 28,
                          child: GestureDetector(
                            onTap: () => widget.onSelectPoint(point),
                            child: _MapPointMarker(
                              selected: point.id == widget.selectedPointId,
                              completed: widget.completedPointIds.contains(
                                point.id,
                              ),
                            ),
                          ),
                        ),
                      if (widget.showVirtualLocation &&
                          widget.currentLocation != null)
                        Marker(
                          point: widget.currentLocation!,
                          width: 36,
                          height: 36,
                          child: const _CurrentLocationDot(),
                        ),
                    ],
                  ),
                  configuredMapAttribution(widget.settings),
                ],
              ),
              Positioned(
                left: 10,
                top: 10,
                right: 56,
                child: _MapCompactSummary(group: widget.group),
              ),
              Positioned(
                right: 10,
                top: 10,
                child: _MapFloatingIconButton(
                  tooltip: widget.showVirtualLocation ? '隐藏当前位置' : '显示当前位置',
                  icon: widget.isLocating
                      ? null
                      : widget.showVirtualLocation
                      ? Icons.my_location
                      : Icons.my_location_outlined,
                  onTap: widget.isLocating
                      ? null
                      : widget.onToggleVirtualLocation,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _MapResizeHotZone(onDrag: widget.onDrag),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapCompactSummary extends StatelessWidget {
  const _MapCompactSummary({required this.group});

  final PlanGroupBucket group;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          '${group.anchorLabel} · ${group.completedCount}/${group.points.length} 完成 · ${group.orderModeLabel}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _MapResizeHandle extends StatelessWidget {
  const _MapResizeHandle({required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) => onDrag(details.delta.dy),
      child: SizedBox(
        height: 10,
        width: double.infinity,
        child: Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: 48,
            height: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapResizeHotZone extends StatelessWidget {
  const _MapResizeHotZone({required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: (details) => onDrag(details.delta.dy),
      child: const SizedBox(height: 24, width: double.infinity),
    );
  }
}

class _MapPointMarker extends StatelessWidget {
  const _MapPointMarker({required this.selected, required this.completed});

  final bool selected;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final markerColor = selected
        ? AppColors.accentDark
        : completed
        ? AppColors.textSecondary
        : AppColors.accent;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: markerColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: selected ? 2.5 : 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: selected ? 9 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        completed ? Icons.check : Icons.place,
        size: selected ? 19 : 15,
        color: Colors.white,
      ),
    );
  }
}

class _CurrentLocationDot extends StatelessWidget {
  const _CurrentLocationDot();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const SizedBox(width: 16, height: 16),
        ),
      ),
    );
  }
}

class _MapFloatingIconButton extends StatelessWidget {
  const _MapFloatingIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: icon == null
                ? const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Icon(icon, size: 20, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _EmptyPlanCard extends StatelessWidget {
  const _EmptyPlanCard({required this.onAddPoints});

  final VoidCallback onAddPoints;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Icon(Icons.route_outlined, color: AppColors.accent),
              SizedBox(width: 8),
              Text(
                '还没有点位',
                style: TextStyle(
                  color: AppColors.accentDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '先从 Anitabi 或手动录入添加巡礼点，之后这里会显示当前目标和完成进度。',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAddPoints,
            icon: const Icon(Icons.add_location_alt_outlined, size: 18),
            label: const Text('添加点位'),
          ),
        ],
      ),
    );
  }
}

class _WorkHeader extends StatelessWidget {
  const _WorkHeader({required this.plan});

  final PilgrimagePlan plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            constraints: const BoxConstraints(minWidth: 52),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.movie_filter_outlined,
              color: AppColors.accentDark,
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
                    fontSize: 18,
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
                    fontSize: 13,
                    letterSpacing: 0,
                  ),
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

class _PlanMetaStrip extends StatelessWidget {
  const _PlanMetaStrip({required this.plan});

  final PilgrimagePlan plan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: [
          Icon(Icons.movie_filter_outlined, color: AppColors.accentDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${plan.area} / ${plan.points.length} 个点位 / ${_workCountText(plan)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
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

class _PlanPointTile extends StatelessWidget {
  const _PlanPointTile({
    required this.point,
    required this.status,
    required this.recordCount,
    required this.onTap,
    required this.onOpenCamera,
    required this.onComplete,
    required this.onReopen,
  });

  final PilgrimagePoint point;
  final VisitStatus status;
  final int recordCount;
  final VoidCallback onTap;
  final VoidCallback onOpenCamera;
  final VoidCallback onComplete;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final colors = _statusColors(status);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(colors.icon, color: colors.foreground, size: 22),
              ),
              const SizedBox(width: 12),
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
                        if (recordCount > 0) ...[
                          const SizedBox(width: 8),
                          _PointRecordBadge(count: recordCount),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${point.work.title} / ${point.subtitle} / ${point.displayEpisodeLabel}',
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
                tooltip: '拍摄参考',
                onPressed: onOpenCamera,
                icon: const Icon(Icons.photo_camera_outlined),
              ),
              IconButton(
                tooltip: status == VisitStatus.completed ? '重置' : '完成',
                onPressed: status == VisitStatus.completed
                    ? onReopen
                    : onComplete,
                icon: Icon(
                  status == VisitStatus.completed
                      ? Icons.restart_alt
                      : Icons.check_outlined,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _PointStatusColors _statusColors(VisitStatus status) {
    return switch (status) {
      VisitStatus.current => _PointStatusColors(
        background: AppColors.accent,
        foreground: Colors.white,
        border: AppColors.accent,
        icon: Icons.flag,
      ),
      VisitStatus.completed => _PointStatusColors(
        background: AppColors.surfaceMuted,
        foreground: AppColors.textSecondary,
        border: AppColors.border,
        icon: Icons.check_circle_outline,
      ),
      VisitStatus.pending => _PointStatusColors(
        background: AppColors.surfaceMuted,
        foreground: AppColors.accentDark,
        border: AppColors.border,
        icon: Icons.place_outlined,
      ),
    };
  }
}

class _PointRecordBadge extends StatelessWidget {
  const _PointRecordBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 13,
            color: AppColors.accentDark,
          ),
          const SizedBox(width: 4),
          Text(
            '已拍 $count',
            style: TextStyle(
              color: AppColors.accentDark,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _PointStatusColors {
  _PointStatusColors({
    required this.background,
    required this.foreground,
    required this.border,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final Color border;
  final IconData icon;
}
