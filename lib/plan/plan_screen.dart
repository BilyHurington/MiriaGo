import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../app_theme.dart';
import '../data/pilgrimage_repository.dart';
import '../widgets/auto_caching_reference_thumbnail.dart';
import '../widgets/confirm_action_dialog.dart';
import '../widgets/input_dialog.dart';
import '../widgets/reference_thumbnail_stub.dart'
    if (dart.library.io) '../widgets/reference_thumbnail_io.dart';
import '../widgets/snackbar_helper.dart';
import '../camera_reference/camerawesome_reference_screen.dart';
import '../point_detail/point_detail_sheet.dart';
import '../records/point_visit_records_screen.dart';
import '../records/visit_record_detail_screen.dart';
import '../map/map_marker_scale.dart';
import '../map/map_tile_config.dart';
import '../map/current_location_resolver.dart';
import '../utils/selected_item_order.dart';
import 'add_points_screen.dart';
import 'plan_group_picker_sheet.dart';
import 'plan_group_utils.dart';
import 'plan_memo_screen.dart';
import 'pilgrimage_models.dart';
import 'pilgrimage_plan_controller.dart';
import 'reference_cache_progress_dialog.dart';
import 'reference_full_cache_runner.dart';
import 'reference_image_status.dart';

const _planActionSubtitleMinPanelWidth = 380.0;

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
  String? _selectedGroupId;
  late String _selectedPlanId;
  PointSortMode _sortMode = PointSortMode.plan;
  bool _sortDescending = false;
  bool _showMap = false;
  bool _showPlanActions = false;
  bool _showVirtualLocation = false;
  bool _isLocating = false;
  bool _isCachingFullReferences = false;
  double _mapHeightRatio = 0.42;
  LatLng? _currentLocation;
  final _pointListController = ScrollController();
  final _pointTileKeys = <String, GlobalKey>{};
  final _planActionsPanelRegionKey = GlobalKey();

  PilgrimagePlanController get controller => widget.controller;

  AppSettings get settings => widget.settings;

  @override
  void initState() {
    super.initState();
    _selectedPlanId = controller.plan.id;
    _selectedGroupId = controller.plan.currentGroupId;
  }

  @override
  void dispose() {
    _pointListController.dispose();
    super.dispose();
  }

  void _selectGroup(int index, List<PlanGroupBucket> groups) {
    final selectedIndex = index.clamp(0, groups.length - 1);
    final groupId = groups[selectedIndex].id;
    setState(() {
      _selectedGroupIndex = selectedIndex;
      _selectedGroupId = groupId;
      _showMap = false;
    });
    controller.setCurrentGroup(groupId);
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
        _selectedGroupId = groups[nextGroupIndex].id;
      }
    });
    if (nextGroupIndex >= 0) {
      controller.setCurrentGroup(groups[nextGroupIndex].id);
    }
    controller.selectPoint(point);
  }

  void _handleMapPointTap(
    BuildContext context,
    PilgrimagePoint point,
    List<PlanGroupBucket> groups,
  ) {
    if (controller.selectedPoint?.id == point.id) {
      _showPointDetail(context, point);
      return;
    }

    _selectPoint(point, groups);
    _scrollPointTileIntoView(point.id);
  }

  void _scrollPointTileIntoView(String pointId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final context = _pointTileKeys[pointId]?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: 0.35,
        );
        return;
      }

      final group = planGroupBuckets(
        controller.plan,
        controller.completedPointIds,
      ).elementAtOrNull(_selectedGroupIndex);
      if (group == null || !_pointListController.hasClients) {
        return;
      }
      final displayPoints = displayPointsForGroup(
        group,
        sortMode: _sortMode,
        descending: _sortDescending,
        currentLocation: _currentLocation,
      );
      final index = displayPoints.indexWhere((point) => point.id == pointId);
      if (index < 0) {
        return;
      }

      final estimatedOffset = (index * 86.0).clamp(
        0.0,
        _pointListController.position.maxScrollExtent,
      );
      _pointListController.animateTo(
        estimatedOffset,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final nextContext = _pointTileKeys[pointId]?.currentContext;
        if (nextContext == null) {
          return;
        }
        Scrollable.ensureVisible(
          nextContext,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          alignment: 0.35,
        );
      });
    });
  }

  GlobalKey _pointTileKey(String pointId) {
    return _pointTileKeys.putIfAbsent(pointId, GlobalKey.new);
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

  void _togglePlanActions() {
    setState(() {
      _showPlanActions = !_showPlanActions;
    });
  }

  void _collapsePlanActions() {
    if (!_showPlanActions) {
      return;
    }
    setState(() {
      _showPlanActions = false;
    });
  }

  void _openPlanAction(VoidCallback action) {
    _collapsePlanActions();
    action();
  }

  void _handlePlanBodyPointerDown(PointerDownEvent event) {
    if (!_showPlanActions || !settings.dismissPlanActionsOnOutsideTap) {
      return;
    }
    final renderBox =
        _planActionsPanelRegionKey.currentContext?.findRenderObject()
            as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return;
    }
    final panelRect = renderBox.localToGlobal(Offset.zero) & renderBox.size;
    if (!panelRect.contains(event.position)) {
      _collapsePlanActions();
    }
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
      final position = await resolveCurrentLocation();
      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _showVirtualLocation = true;
      });
    } on CurrentLocationException catch (error) {
      _showSnackBar(currentLocationFailureMessage(error));
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
    if (_selectedPlanId != plan.id) {
      _selectedPlanId = plan.id;
      _selectedGroupId = plan.currentGroupId;
    }
    final restoredGroupIndex = groups.indexWhere(
      (group) => group.id == _selectedGroupId,
    );
    if (restoredGroupIndex >= 0) {
      _selectedGroupIndex = restoredGroupIndex;
    }
    if (_selectedGroupIndex >= groups.length) {
      _selectedGroupIndex = groups.isEmpty ? 0 : groups.length - 1;
    }
    if (groups.isNotEmpty) {
      _selectedGroupId = groups[_selectedGroupIndex].id;
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
        toolbarHeight: kToolbarHeight,
        actionsPadding: EdgeInsets.zero,
        title: Text(
          plan.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            key: const ValueKey('plan-switch-button'),
            tooltip: '切换计划',
            onPressed: widget.onOpenPlanManager,
            icon: const Icon(LucideIcons.arrowLeftRight),
          ),
          IconButton(
            key: const ValueKey('plan-actions-toggle'),
            tooltip: _showPlanActions ? '收起计划操作' : '展开计划操作',
            onPressed: _togglePlanActions,
            icon: Icon(
              _showPlanActions
                  ? LucideIcons.chevronUp
                  : LucideIcons.chevronDown,
            ),
          ),
        ],
      ),
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _handlePlanBodyPointerDown,
        child: Column(
          children: [
            if (selectedGroup == null || controller.points.isEmpty)
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _WorkHeader(plan: plan),
                    _PlanActionsReveal(
                      expanded: _showPlanActions,
                      child: KeyedSubtree(
                        key: _planActionsPanelRegionKey,
                        child: _PlanActionsPanel(
                          isCachingReferences: _isCachingFullReferences,
                          onCacheReferences: _handleReferenceCachePressed,
                          onAddPoints: () =>
                              _openPlanAction(widget.onOpenAddPoints),
                          onManagePoints: () =>
                              _openPlanAction(widget.onOpenPointManager),
                          onOpenMemo: () => _openPlanAction(_openPlanMemo),
                          onImportExport: () =>
                              _openPlanAction(widget.onOpenImportExport),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _EmptyPlanCard(onAddPoints: widget.onOpenAddPoints),
                  ],
                ),
              )
            else ...[
              _PlanActionsReveal(
                expanded: _showPlanActions,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: KeyedSubtree(
                  key: _planActionsPanelRegionKey,
                  child: _PlanActionsPanel(
                    isCachingReferences: _isCachingFullReferences,
                    onCacheReferences: _handleReferenceCachePressed,
                    onAddPoints: () => _openPlanAction(widget.onOpenAddPoints),
                    onManagePoints: () =>
                        _openPlanAction(widget.onOpenPointManager),
                    onOpenMemo: () => _openPlanAction(_openPlanMemo),
                    onImportExport: () =>
                        _openPlanAction(widget.onOpenImportExport),
                  ),
                ),
              ),
              _GroupSwitcher(
                groups: groups,
                selectedIndex: _selectedGroupIndex,
                showProgressRing: widget.settings.showPlanGroupProgress,
                onSelectGroup: (group) {
                  final currentGroups = planGroupBuckets(
                    controller.plan,
                    controller.completedPointIds,
                  );
                  final index = currentGroups.indexWhere(
                    (candidate) => candidate.id == group.id,
                  );
                  if (index >= 0) {
                    _selectGroup(index, currentGroups);
                  }
                },
                onCreateGroup: () => _createGroupFromPointDetail(context),
              ),
              _PlanGroupControls(
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
                onSelectPoint: (point) =>
                    _handleMapPointTap(context, point, groups),
                completedPointIds: controller.completedPointIds,
              ),
              Expanded(
                child: ListView(
                  controller: _pointListController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    for (final point in displayPoints) ...[
                      _PlanPointTile(
                        key: _pointTileKey(point.id),
                        controller: controller,
                        point: point,
                        status: controller.statusFor(point),
                        recordCount: controller
                            .recordsForPoint(point.id)
                            .length,
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
      ),
    );
  }

  Future<void> _openPlanMemo() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PlanMemoScreen(controller: controller),
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
      onReplaceReference: (point, image) => controller.updatePoint(
        point.copyWith(
          referenceImageUrl: null,
          referenceThumbnailPath: image.thumbnailPath,
          referenceFullImagePath: image.fullImagePath,
        ),
      ),
      groups: controller.plan.groups,
      groupBuckets: planGroupBuckets(
        controller.plan,
        controller.completedPointIds,
      ),
      onMoveToGroup: controller.movePointToGroup,
      onCreateGroup: () => _createGroupFromPointDetail(context),
      records: controller.recordsForPoint(point.id),
      onOpenRecords: () => _openPointRecords(context, point),
      onOpenRecord: (record) => _openRecordDetail(context, record),
      onEditPoint: () => _editPoint(context, point),
      onDelete: controller.deletePoint,
      navigationApp: settings.navigationApp,
      settings: settings,
      planController: controller,
    );
  }

  Future<PilgrimagePlanGroup?> _createGroupFromPointDetail(
    BuildContext context,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _PlanPointCreateGroupDialog(),
    );
    final trimmedName = name?.trim();
    if (trimmedName == null || trimmedName.isEmpty || !mounted) {
      return null;
    }

    final groups = controller.plan.groups;
    final nextOrderIndex = groups.isEmpty
        ? 0
        : groups
                  .map((group) => group.orderIndex)
                  .reduce((a, b) => a > b ? a : b) +
              1;
    final now = DateTime.now();
    final group = PilgrimagePlanGroup(
      id: 'group-${now.microsecondsSinceEpoch}',
      name: trimmedName,
      orderIndex: nextOrderIndex,
      createdAt: now,
    );
    try {
      final updatedPlan = await widget.repository.createPlanGroup(
        planId: controller.plan.id,
        group: group,
      );
      if (!mounted) {
        return null;
      }
      controller.replacePlan(updatedPlan);
      return updatedPlan.groups
          .where((item) => item.id == group.id)
          .firstOrNull;
    } catch (_) {
      if (mounted) {
        _showSnackBar('片区创建失败，请稍后重试。');
      }
      return null;
    }
  }

  Future<void> _editPoint(BuildContext context, PilgrimagePoint point) async {
    final updated = await EditPointScreen.open(
      context,
      plan: controller.plan,
      repository: widget.repository,
      point: point,
    );
    if (updated != true || !mounted) {
      return;
    }
    final updatedPlan = await widget.repository.loadActivePlan();
    if (!mounted) {
      return;
    }
    controller.replacePlan(updatedPlan);
  }

  void _openPointRecords(BuildContext context, PilgrimagePoint point) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PointVisitRecordsScreen(
          point: point,
          controller: controller,
          settings: settings,
        ),
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
          settings: settings,
          onDelete: () => controller.deleteVisitRecord(record),
        ),
      ),
    );
  }

  Future<void> _handleReferenceCachePressed() async {
    if (_isCachingFullReferences) {
      return;
    }

    final points = pointsNeedingFullReferenceCache(controller.points);
    if (points.isEmpty) {
      _showSnackBar('当前计划没有需要缓存的参考图', kind: AppStatusBannerKind.warning);
      return;
    }

    final confirmed = await showConfirmActionDialog(
      context,
      title: '缓存完整参考图',
      message: '将缓存当前计划中 ${points.length} 张完整参考图，可能需要较长时间和网络流量。',
      confirmLabel: '开始缓存',
      notice: '建议在 Wi-Fi 环境下进行缓存',
      emphasizedValues: ['${points.length} 张'],
    );
    if (!confirmed || !mounted) {
      return;
    }
    _collapsePlanActions();
    await _cacheFullReferenceImages();
  }

  Future<void> _cacheFullReferenceImages() async {
    if (_isCachingFullReferences) {
      return;
    }
    setState(() {
      _isCachingFullReferences = true;
    });
    try {
      await showReferenceCacheProgressDialog(
        context: context,
        run: (onProgress) {
          return cacheFullReferenceImages(
            plan: controller.plan,
            repository: widget.repository,
            onPlanUpdated: controller.replacePlan,
            imageSource: settings.anitabiImageSource,
            maxConcurrent: settings.mapThumbnailConcurrentLoads,
            onProgress: onProgress,
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCachingFullReferences = false;
        });
      }
    }
  }

  void _showSnackBar(
    String message, {
    AppStatusBannerKind kind = AppStatusBannerKind.error,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showStatusSnack(kind: kind, title: message);
  }
}

class _PlanPointCreateGroupDialog extends StatefulWidget {
  const _PlanPointCreateGroupDialog();

  @override
  State<_PlanPointCreateGroupDialog> createState() =>
      _PlanPointCreateGroupDialogState();
}

class _PlanPointCreateGroupDialogState
    extends State<_PlanPointCreateGroupDialog> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppInputDialog(
      title: '新建片区',
      content: AppDialogField(
        label: '片区名称',
        child: TextField(
          onTapOutside: dismissKeyboardOnTapOutside,
          key: const ValueKey('plan-point-group-name-field'),
          controller: _nameController,
          autofocus: true,
          decoration: appDialogInputDecoration(),
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
      ),
      confirmLabel: '创建',
      onConfirm: () => Navigator.of(context).pop(_nameController.text),
    );
  }
}

class _PlanActionsReveal extends StatelessWidget {
  const _PlanActionsReveal({
    required this.expanded,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final bool expanded;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: expanded
          ? Padding(padding: padding, child: child)
          : const SizedBox.shrink(),
    );
  }
}

class _PlanActionsPanel extends StatelessWidget {
  const _PlanActionsPanel({
    required this.isCachingReferences,
    required this.onCacheReferences,
    required this.onAddPoints,
    required this.onManagePoints,
    required this.onOpenMemo,
    required this.onImportExport,
  });

  final bool isCachingReferences;
  final VoidCallback onCacheReferences;
  final VoidCallback onAddPoints;
  final VoidCallback onManagePoints;
  final VoidCallback onOpenMemo;
  final VoidCallback onImportExport;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _planActionSubtitleMinPanelWidth;
        final items = [
          _PlanActionItem(
            key: const ValueKey('plan-action-add-points'),
            icon: const Icon(LucideIcons.mapPinPlus, size: 20),
            title: '添加点位',
            subtitle: '加入巡礼场景',
            compact: compact,
            onTap: onAddPoints,
          ),
          _PlanActionItem(
            key: const ValueKey('plan-action-manage-points'),
            icon: const Icon(LucideIcons.slidersHorizontal, size: 20),
            title: '管理计划',
            subtitle: '整理片区点位',
            compact: compact,
            onTap: onManagePoints,
          ),
          _PlanActionItem(
            key: const ValueKey('plan-action-cache-references'),
            icon: isCachingReferences
                ? const SizedBox.square(
                    dimension: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.cloudDownload, size: 20),
            title: '缓存参考图',
            subtitle: '保存完整图片',
            compact: compact,
            onTap: onCacheReferences,
          ),
          _PlanActionItem(
            key: const ValueKey('plan-action-memo'),
            icon: const Icon(LucideIcons.stickyNote, size: 20),
            title: '计划备忘录',
            subtitle: '记录行程要点',
            compact: compact,
            onTap: onOpenMemo,
          ),
          _PlanActionItem(
            key: const ValueKey('plan-action-import-export'),
            icon: const Icon(LucideIcons.import, size: 20),
            title: '导入导出',
            subtitle: '备份迁移计划',
            compact: compact,
            onTap: onImportExport,
          ),
        ];
        return Container(
          key: const ValueKey('plan-actions-panel'),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: compact
              ? _planActionRow(items)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _planActionRow(items.sublist(0, 2)),
                    const AppHairline(),
                    _planActionRow(items.sublist(2)),
                  ],
                ),
        );
      },
    );
  }
}

Widget _planActionRow(List<Widget> items) {
  return IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const _PlanActionDivider(),
          Expanded(child: items[i]),
        ],
      ],
    ),
  );
}

class _PlanActionItem extends StatelessWidget {
  const _PlanActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.compact,
    required this.onTap,
    super.key,
  });

  final Widget icon;
  final String title;
  final String subtitle;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final themedIcon = IconTheme(
      data: IconThemeData(color: AppColors.accentDark),
      child: icon,
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: compact
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 10,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    themedIcon,
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        title,
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      themedIcon,
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0,
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
}

class _PlanActionDivider extends StatelessWidget {
  const _PlanActionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 10),
      color: AppColors.border,
    );
  }
}

class _GroupSwitcher extends StatelessWidget {
  const _GroupSwitcher({
    required this.groups,
    required this.selectedIndex,
    required this.showProgressRing,
    required this.onSelectGroup,
    required this.onCreateGroup,
  });

  final List<PlanGroupBucket> groups;
  final int selectedIndex;
  final bool showProgressRing;
  final ValueChanged<PlanGroupBucket> onSelectGroup;
  final Future<PilgrimagePlanGroup?> Function() onCreateGroup;

  @override
  Widget build(BuildContext context) {
    final group = groups[selectedIndex];
    return Padding(
      key: const ValueKey('plan-group-switcher'),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: selectedIndex == 0
                ? null
                : () => onSelectGroup(groups[selectedIndex - 1]),
            icon: const Icon(LucideIcons.chevronLeft),
            tooltip: '上一个片区',
          ),
          Expanded(
            child: FilledButton.tonal(
              onPressed: () => _showGroupPicker(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: AppColors.border),
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
                : () => onSelectGroup(groups[selectedIndex + 1]),
            icon: const Icon(LucideIcons.chevronRight),
            tooltip: '下一个片区',
          ),
        ],
      ),
    );
  }

  void _showGroupPicker(BuildContext context) {
    showPlanGroupPickerSheet(
      context: context,
      groups: groups,
      selectedGroupId: groups[selectedIndex].id,
      showProgressRing: showProgressRing,
      onSelectGroup: onSelectGroup,
      onCreateGroup: onCreateGroup,
    );
  }
}

class _PlanGroupControls extends StatelessWidget {
  const _PlanGroupControls({
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
                icon: Icon(
                  showMap ? LucideIcons.map : LucideIcons.map,
                  size: 18,
                ),
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
                          const Icon(LucideIcons.arrowUpDown, size: 18),
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
                          const Icon(LucideIcons.chevronDown, size: 18),
                        ],
                      ),
                    ),
                  );
                },
                menuChildren: [
                  MenuItemButton(
                    leadingIcon: const Icon(LucideIcons.listOrdered),
                    onPressed: () => onChanged(PointSortMode.plan),
                    child: const Text('默认计划顺序'),
                  ),
                  MenuItemButton(
                    leadingIcon: const Icon(LucideIcons.navigation),
                    onPressed: () => onChanged(PointSortMode.distance),
                    child: const Text('按距离当前位置'),
                  ),
                ],
              ),
            ),
            SizedBox(
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
                    descending ? LucideIcons.arrowDown : LucideIcons.arrowUp,
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
      if (point.id == selectedPointId && point.hasCoordinate) {
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
    final mapPoints = selectedItemsLast<PilgrimagePoint>(
      widget.group.points.where((point) => point.hasCoordinate),
      isSelected: (point) => point.id == widget.selectedPointId,
    );

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
                  maxZoom: widget.settings.mapMaxZoom.toDouble(),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  configuredMapTileLayer(widget.settings),
                  MarkerLayer(
                    markers: [
                      for (final point in mapPoints)
                        Marker(
                          point: point.position,
                          width: scaledMapMarkerDimension(
                            point.id == widget.selectedPointId ? 34 : 28,
                            widget.settings.mapMarkerScale,
                          ),
                          height: scaledMapMarkerDimension(
                            point.id == widget.selectedPointId ? 34 : 28,
                            widget.settings.mapMarkerScale,
                          ),
                          child: ScaledMapMarker(
                            scale: widget.settings.mapMarkerScale,
                            baseWidth: point.id == widget.selectedPointId
                                ? 34
                                : 28,
                            baseHeight: point.id == widget.selectedPointId
                                ? 34
                                : 28,
                            child: GestureDetector(
                              onTap: () => widget.onSelectPoint(point),
                              child: _MapPointMarker(
                                key: ValueKey('plan-map-marker-${point.id}'),
                                selected: point.id == widget.selectedPointId,
                                completed: widget.completedPointIds.contains(
                                  point.id,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (widget.showVirtualLocation &&
                          widget.currentLocation != null)
                        Marker(
                          point: widget.currentLocation!,
                          width: scaledMapMarkerDimension(
                            36,
                            widget.settings.mapMarkerScale,
                          ),
                          height: scaledMapMarkerDimension(
                            36,
                            widget.settings.mapMarkerScale,
                          ),
                          child: ScaledMapMarker(
                            scale: widget.settings.mapMarkerScale,
                            baseWidth: 36,
                            baseHeight: 36,
                            child: const _CurrentLocationDot(),
                          ),
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
                child: IgnorePointer(
                  child: _MapCompactSummary(group: widget.group),
                ),
              ),
              Positioned(
                right: 10,
                top: 10,
                child: _MapFloatingIconButton(
                  tooltip: widget.showVirtualLocation ? '隐藏当前位置' : '显示当前位置',
                  icon: widget.isLocating
                      ? null
                      : widget.showVirtualLocation
                      ? LucideIcons.locateFixed
                      : LucideIcons.locateFixed,
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
          style: TextStyle(
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
  const _MapPointMarker({
    required this.selected,
    required this.completed,
    super.key,
  });

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
        completed ? LucideIcons.check : LucideIcons.mapPin,
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
              Icon(LucideIcons.package, color: AppColors.accent),
              const SizedBox(width: 10),
              Text(
                '还没有点位',
                style: TextStyle(
                  color: AppColors.accentDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _OnboardingTimeline(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('plan-add-points'),
              onPressed: onAddPoints,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              icon: const Icon(LucideIcons.mapPinPlus, size: 20),
              label: const Text('添加点位'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingTimeline extends StatelessWidget {
  const _OnboardingTimeline();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _OnboardingStep(
          number: 1,
          title: '加作品',
          body: '点击右上角展开计划操作，选择“添加点位”，再点击“作品管理”，搜索并添加想要加入巡礼计划的作品。',
        ),
        _OnboardingStep(
          number: 2,
          title: '选点位',
          body:
              '在“添加点位”页面点击“从作品地图导入”，在这里你可以选择并添加巡礼点位。\n你也可以在“添加点位”页面点击“从Anitabi链接导入”。通过使用有效链接，导入点位时作品也会被一起添加。',
        ),
        _OnboardingStep(
          number: 3,
          title: '划片区',
          body:
              '回到“计划”页，点击右上角展开计划操作，选择“管理计划”。在这里可以细致管理已加入计划的点位，创建片区并归纳距离接近的点位。',
          isLast: true,
        ),
      ],
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep({
    required this.number,
    required this.title,
    required this.body,
    this.isLast = false,
  });

  final int number;
  final String title;
  final String body;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$number',
                    style: TextStyle(
                      color: AppColors.onAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: AppColors.border)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 26,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
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
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 12),
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
            child: Icon(LucideIcons.clapperboard, color: AppColors.accentDark),
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
                  style: TextStyle(
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

class _PlanPointTile extends StatelessWidget {
  const _PlanPointTile({
    required this.controller,
    required this.point,
    required this.status,
    required this.recordCount,
    required this.onTap,
    required this.onOpenCamera,
    required this.onComplete,
    required this.onReopen,
    super.key,
  });

  final PilgrimagePlanController controller;
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
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 42,
                  height: 42,
                  color: colors.background,
                  child: _PlanPointThumbnail(
                    controller: controller,
                    point: point,
                    placeholder: Icon(
                      colors.icon,
                      color: colors.foreground,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 3),
                    Text(
                      point.work.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: status == VisitStatus.completed ? '撤回打卡' : '完成',
                onPressed: status == VisitStatus.completed
                    ? onReopen
                    : onComplete,
                icon: Icon(
                  status == VisitStatus.completed
                      ? LucideIcons.rotateCcw
                      : LucideIcons.check,
                ),
              ),
              IconButton(
                tooltip: '拍摄参考',
                onPressed: onOpenCamera,
                icon: SizedBox(
                  width: 24,
                  height: 24,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Center(child: Icon(LucideIcons.camera)),
                      if (recordCount > 0)
                        const Positioned(
                          top: -5,
                          right: -5,
                          child: _PointRecordBadge(),
                        ),
                    ],
                  ),
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
        icon: LucideIcons.flag,
      ),
      VisitStatus.completed => _PointStatusColors(
        background: AppColors.surfaceMuted,
        foreground: AppColors.textSecondary,
        border: AppColors.border,
        icon: LucideIcons.circleCheckBig,
      ),
      VisitStatus.pending => _PointStatusColors(
        background: AppColors.surfaceMuted,
        foreground: AppColors.accentDark,
        border: AppColors.border,
        icon: LucideIcons.mapPin,
      ),
    };
  }
}

class _PlanPointThumbnail extends StatelessWidget {
  const _PlanPointThumbnail({
    required this.controller,
    required this.point,
    required this.placeholder,
  });

  final PilgrimagePlanController controller;
  final PilgrimagePoint point;
  final Widget placeholder;

  @override
  Widget build(BuildContext context) {
    final repository = controller.repository;
    final remoteImageUrl = hasRemoteReferenceImage(point)
        ? point.referenceImageUrl
        : null;
    if (repository == null) {
      return ReferenceThumbnail(
        localPath: point.referenceThumbnailPath,
        imageUrl: remoteImageUrl,
        placeholder: placeholder,
      );
    }
    return AutoCachingReferenceThumbnail(
      planId: controller.plan.id,
      point: point,
      repository: repository,
      onPlanUpdated: controller.replacePlan,
      placeholder: placeholder,
    );
  }
}

class _PointRecordBadge extends StatelessWidget {
  const _PointRecordBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('plan-point-shot-badge'),
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(LucideIcons.images, size: 10, color: AppColors.accentDark),
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
