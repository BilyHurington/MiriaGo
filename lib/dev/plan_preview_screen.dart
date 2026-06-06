import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_theme.dart';
import '../data/sample_pilgrimage_repository.dart';
import '../plan/pilgrimage_models.dart';
import '../widgets/copyable_text.dart';
import '../widgets/reference_thumbnail_stub.dart'
    if (dart.library.io) '../widgets/reference_thumbnail_io.dart';

enum _PreviewSortMode { plan, distance }

const _desktopMinCenterWidth = 520.0;

class PlanPreviewScreen extends StatefulWidget {
  const PlanPreviewScreen({super.key});

  static const previewKey = 'plan';

  @override
  State<PlanPreviewScreen> createState() => _PlanPreviewScreenState();
}

class _PlanPreviewScreenState extends State<PlanPreviewScreen> {
  late final PilgrimagePlan _plan = _previewPlan();
  int _selectedGroupIndex = 0;
  String? _selectedPointId;
  bool _showMobileMap = false;
  bool _showVirtualLocation = false;
  int _mobilePreviewTab = 0;
  double _mobileMapHeightRatio = 0.42;
  double _desktopSidebarWidth = 288;
  double _desktopRightPaneWidth = 420;
  double _desktopMapHeight = 280;
  _PreviewSortMode _sortMode = _PreviewSortMode.plan;
  bool _sortDescending = false;
  final _mobilePointListController = ScrollController();

  List<_PreviewGroup> get _groups => _previewGroups(_plan);

  _PreviewGroup get _selectedGroup => _groups[_selectedGroupIndex];

  PilgrimagePoint? get _selectedPoint {
    final points = _selectedGroup.points;
    if (points.isEmpty) {
      return null;
    }
    if (_selectedPointId == null) {
      return points.first;
    }
    return points.firstWhere(
      (point) => point.id == _selectedPointId,
      orElse: () => points.first,
    );
  }

  @override
  void dispose() {
    _mobilePointListController.dispose();
    super.dispose();
  }

  void _selectGroup(int index) {
    final nextIndex = index.clamp(0, _groups.length - 1);
    final nextGroup = _groups[nextIndex];
    setState(() {
      _selectedGroupIndex = nextIndex;
      _selectedPointId = nextGroup.points.firstOrNull?.id;
      _showMobileMap = false;
    });
  }

  void _selectPoint(PilgrimagePoint point) {
    final nextGroupIndex = _groups.indexWhere((group) {
      if (point.groupId == null) {
        return group.isUngrouped;
      }
      return group.id == point.groupId;
    });
    setState(() {
      if (nextGroupIndex >= 0) {
        _selectedGroupIndex = nextGroupIndex;
      }
      _selectedPointId = point.id;
    });
  }

  void _setSortMode(_PreviewSortMode mode) {
    setState(() {
      _sortMode = mode;
    });
  }

  void _toggleSortDirection() {
    setState(() {
      _sortDescending = !_sortDescending;
    });
  }

  void _toggleMobileMap() {
    setState(() {
      _showMobileMap = !_showMobileMap;
    });
  }

  void _toggleVirtualLocation() {
    setState(() {
      _showVirtualLocation = !_showVirtualLocation;
    });
  }

  void _selectMobilePreviewTab(int index) {
    setState(() {
      _mobilePreviewTab = index;
    });
  }

  void _resizeMobileMap(double deltaY, double viewportHeight) {
    if (!_showMobileMap) {
      return;
    }
    setState(() {
      _mobileMapHeightRatio =
          (_mobileMapHeightRatio + deltaY / viewportHeight).clamp(0.22, 0.58);
    });
  }

  void _resizeDesktopSidebar(double deltaX, double viewportWidth) {
    setState(() {
      final maxSidebarWidth =
          viewportWidth - _desktopRightPaneWidth - _desktopMinCenterWidth;
      _desktopSidebarWidth = (_desktopSidebarWidth + deltaX).clamp(
        220,
        maxSidebarWidth < 220 ? 220 : maxSidebarWidth,
      );
    });
  }

  void _resizeDesktopRightPane(double deltaX, double viewportWidth) {
    setState(() {
      final maxRightPaneWidth =
          viewportWidth - _desktopSidebarWidth - _desktopMinCenterWidth;
      _desktopRightPaneWidth =
          (_desktopRightPaneWidth - deltaX).clamp(
            340,
            maxRightPaneWidth < 340 ? 340 : maxRightPaneWidth,
          );
    });
  }

  void _resizeDesktopMap(double deltaY, double paneHeight) {
    setState(() {
      _desktopMapHeight = (_desktopMapHeight + deltaY).clamp(
        200,
        (paneHeight - 240).clamp(220, 620),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    AppColors.palette = AppThemePalette.classicGreen;

    return Theme(
      data: AppTheme.light(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final useDesktop = constraints.maxWidth >= 900;
          if (useDesktop) {
            return _DesktopPlanPreview(
              plan: _plan,
              groups: _groups,
              selectedGroupIndex: _selectedGroupIndex,
              selectedPoint: _selectedPoint,
              sidebarWidth: _desktopSidebarWidth,
              rightPaneWidth: _desktopRightPaneWidth,
              mapHeight: _desktopMapHeight,
              sortMode: _sortMode,
              sortDescending: _sortDescending,
              showVirtualLocation: _showVirtualLocation,
              onSelectGroup: _selectGroup,
              onSelectPoint: _selectPoint,
              onSetSortMode: _setSortMode,
              onToggleSortDirection: _toggleSortDirection,
              onToggleVirtualLocation: _toggleVirtualLocation,
              onResizeSidebar: _resizeDesktopSidebar,
              onResizeRightPane: _resizeDesktopRightPane,
              onResizeMap: _resizeDesktopMap,
            );
          }

              return _MobilePlanPreview(
                plan: _plan,
                groups: _groups,
                selectedGroupIndex: _selectedGroupIndex,
                selectedPointId: _selectedPointId,
                showMap: _showMobileMap,
                mapHeightRatio: _mobileMapHeightRatio,
                sortMode: _sortMode,
                sortDescending: _sortDescending,
                pointListController: _mobilePointListController,
                showVirtualLocation: _showVirtualLocation,
                selectedTabIndex: _mobilePreviewTab,
                onSelectGroup: _selectGroup,
                onSelectPoint: _selectPoint,
                onToggleMap: _toggleMobileMap,
                onResizeMap: _resizeMobileMap,
                onSetSortMode: _setSortMode,
                onToggleSortDirection: _toggleSortDirection,
                onToggleVirtualLocation: _toggleVirtualLocation,
                onSelectTab: _selectMobilePreviewTab,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MobilePlanPreview extends StatelessWidget {
  const _MobilePlanPreview({
    required this.plan,
    required this.groups,
    required this.selectedGroupIndex,
    required this.selectedPointId,
    required this.showMap,
    required this.mapHeightRatio,
    required this.sortMode,
    required this.sortDescending,
    required this.pointListController,
    required this.showVirtualLocation,
    required this.selectedTabIndex,
    required this.onSelectGroup,
    required this.onSelectPoint,
    required this.onToggleMap,
    required this.onResizeMap,
    required this.onSetSortMode,
    required this.onToggleSortDirection,
    required this.onToggleVirtualLocation,
    required this.onSelectTab,
  });

  final PilgrimagePlan plan;
  final List<_PreviewGroup> groups;
  final int selectedGroupIndex;
  final String? selectedPointId;
  final bool showMap;
  final double mapHeightRatio;
  final _PreviewSortMode sortMode;
  final bool sortDescending;
  final ScrollController pointListController;
  final bool showVirtualLocation;
  final int selectedTabIndex;
  final ValueChanged<int> onSelectGroup;
  final ValueChanged<PilgrimagePoint> onSelectPoint;
  final VoidCallback onToggleMap;
  final void Function(double deltaY, double viewportHeight) onResizeMap;
  final ValueChanged<_PreviewSortMode> onSetSortMode;
  final VoidCallback onToggleSortDirection;
  final VoidCallback onToggleVirtualLocation;
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    final group = groups[selectedGroupIndex];
    final displayPoints = _displayPointsForGroup(
      group,
      sortMode: sortMode,
      descending: sortDescending,
    );
    final viewportHeight = MediaQuery.of(context).size.height;
    final mapHeight = (viewportHeight * mapHeightRatio).clamp(160.0, 490.0);

    if (selectedTabIndex == 1) {
      return Column(
        children: [
          Expanded(
            child: _MobileFullMapPreview(
              plan: plan,
              groups: groups,
              selectedGroupIndex: selectedGroupIndex,
              selectedPointId: selectedPointId,
              showVirtualLocation: showVirtualLocation,
              onSelectGroup: onSelectGroup,
              onSelectPoint: onSelectPoint,
              onToggleVirtualLocation: onToggleVirtualLocation,
            ),
          ),
          _PreviewBottomNavigationBar(
            selectedIndex: selectedTabIndex,
            onSelect: onSelectTab,
          ),
        ],
      );
    }

    void selectPointFromMap(PilgrimagePoint point) {
      onSelectPoint(point);
      final index = displayPoints.indexWhere((item) => item.id == point.id);
      if (index < 0) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!pointListController.hasClients) {
          return;
        }
        const itemExtent = 92.0;
        pointListController.animateTo(
          (index * itemExtent).clamp(
            0.0,
            pointListController.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      });
    }

    return Column(
      children: [
        if (showMap)
          _MobileMapPlanHeader(plan: plan)
        else
          _PlanHeader(plan: plan, compact: true),
        _MobileGroupSwitcher(
          groups: groups,
          selectedIndex: selectedGroupIndex,
          onSelectGroup: onSelectGroup,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
          child: Column(
            children: [
              if (!showMap) ...[
                _MobileGroupSummary(group: group),
                const SizedBox(height: 12),
              ],
              if (!group.isManualOrder) ...[
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
                        showMap ? Icons.map : Icons.map_outlined,
                        size: 18,
                      ),
                      label: Text(showMap ? '收起地图' : '地图'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (showMap) ...[
                _MobileMapPreview(
                  group: group,
                  completedPointIds: plan.completedPointIds,
                  selectedPointId: selectedPointId,
                  showVirtualLocation: showVirtualLocation,
                  height: mapHeight,
                  onSelectPoint: selectPointFromMap,
                  onToggleVirtualLocation: onToggleVirtualLocation,
                ),
                _MobileMapResizeHandle(
                  onDrag: (deltaY) => onResizeMap(deltaY, viewportHeight),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: pointListController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              for (final point in displayPoints) ...[
                _PointListTile(
                  point: point,
                  isSelected: point.id == selectedPointId,
                  isCompleted: plan.completedPointIds.contains(point.id),
                  onTap: () {
                    onSelectPoint(point);
                    _showPreviewPointDetailSheet(
                      context,
                      point: point,
                      status: _statusForPoint(plan, point),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
              if (group.points.isEmpty) const _EmptyGroupPlaceholder(),
            ],
          ),
        ),
        _PreviewBottomNavigationBar(
          selectedIndex: selectedTabIndex,
          onSelect: onSelectTab,
        ),
      ],
    );
  }
}

class _PreviewBottomNavigationBar extends StatelessWidget {
  const _PreviewBottomNavigationBar({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        indicatorColor: AppColors.accent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: AppColors.onAccent);
          }
          return const IconThemeData(color: AppColors.textPrimary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w500,
            letterSpacing: 0,
          );
        }),
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        backgroundColor: AppColors.surface,
        onDestinationSelected: onSelect,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: '计划',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: '地图',
          ),
          NavigationDestination(
            icon: Icon(Icons.collections_bookmark_outlined),
            selectedIcon: Icon(Icons.collections_bookmark),
            label: '记录',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}

class _MobileFullMapPreview extends StatelessWidget {
  const _MobileFullMapPreview({
    required this.plan,
    required this.groups,
    required this.selectedGroupIndex,
    required this.selectedPointId,
    required this.showVirtualLocation,
    required this.onSelectGroup,
    required this.onSelectPoint,
    required this.onToggleVirtualLocation,
  });

  final PilgrimagePlan plan;
  final List<_PreviewGroup> groups;
  final int selectedGroupIndex;
  final String? selectedPointId;
  final bool showVirtualLocation;
  final ValueChanged<int> onSelectGroup;
  final ValueChanged<PilgrimagePoint> onSelectPoint;
  final VoidCallback onToggleVirtualLocation;

  @override
  Widget build(BuildContext context) {
    final selectedGroup = groups[selectedGroupIndex];
    final selectedPoint = selectedGroup.points.firstWhere(
      (point) => point.id == selectedPointId,
      orElse: () => selectedGroup.points.firstOrNull ?? plan.points.first,
    );
    final polygons = _groupPolygons(
      groups,
      selectedGroupId: selectedGroup.id,
    );
    final markers = [
      for (final group in groups)
        for (final point in group.points)
          Marker(
            point: point.position,
            width: point.id == selectedPointId ? 34 : 28,
            height: point.id == selectedPointId ? 34 : 28,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelectPoint(point),
              child: _MapPointMarker(
                selected: point.id == selectedPointId,
                completed: plan.completedPointIds.contains(point.id),
              ),
            ),
          ),
      if (showVirtualLocation)
        const Marker(
          point: LatLng(34.8903, 135.8009),
          width: 36,
          height: 36,
          child: _VirtualLocationMarker(),
        ),
    ];

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: _groupMapCenter(selectedGroup),
            initialZoom: 15.1,
            minZoom: 4,
            maxZoom: 19,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'app.miriago.miriago',
            ),
            PolygonLayer(polygons: polygons),
            MarkerLayer(markers: markers),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Expanded(
                  child: _MapFloatingPill(
                    icon: Icons.folder_outlined,
                    label:
                        '${selectedGroup.name} · ${selectedGroup.completedCount}/${selectedGroup.points.length}',
                    onTap: () => _showMobileMapGroupPicker(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 12,
          top: 92,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _MapFloatingIconButton(
                  tooltip: showVirtualLocation ? '隐藏当前位置' : '显示当前位置',
                  icon: showVirtualLocation
                      ? Icons.my_location
                      : Icons.my_location_outlined,
                  onTap: onToggleVirtualLocation,
                ),
                const SizedBox(height: 8),
                _MapFloatingIconButton(
                  tooltip: '当前目标',
                  icon: Icons.flag_outlined,
                  onTap: () {
                    final currentPoint = plan.points.firstWhere(
                      (point) => point.id == plan.currentPointId,
                      orElse: () => selectedPoint,
                    );
                    onSelectPoint(currentPoint);
                  },
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 14,
          child: _MapPointBottomCard(
            point: selectedPoint,
            group: selectedGroup,
            status: _statusForPoint(plan, selectedPoint),
          ),
        ),
      ],
    );
  }

  void _showMobileMapGroupPicker(BuildContext context) {
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
                selected: index == selectedGroupIndex,
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
                trailing: Text('${group.completedCount} / ${group.points.length}'),
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

class _MapFloatingPill extends StatelessWidget {
  const _MapFloatingPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPointBottomCard extends StatelessWidget {
  const _MapPointBottomCard({
    required this.point,
    required this.group,
    required this.status,
  });

  final PilgrimagePoint point;
  final _PreviewGroup group;
  final VisitStatus status;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            _PreviewReferencePreview(point: point, status: status),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    point.name,
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
                    '${group.name} · ${point.displayEpisodeLabel}',
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
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => _showPreviewPointDetailSheet(
                context,
                point: point,
                status: status,
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(58, 40),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('详情'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileMapResizeHandle extends StatelessWidget {
  const _MobileMapResizeHandle({required this.onDrag});

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

class _SortOrderControl extends StatelessWidget {
  const _SortOrderControl({
    required this.mode,
    required this.descending,
    required this.onChanged,
    required this.onToggleDirection,
  });

  final _PreviewSortMode mode;
  final bool descending;
  final ValueChanged<_PreviewSortMode> onChanged;
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
                    onPressed: () => onChanged(_PreviewSortMode.plan),
                    child: const Text('默认计划顺序'),
                  ),
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.near_me_outlined),
                    onPressed: () => onChanged(_PreviewSortMode.distance),
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

String _sortModeLabel(_PreviewSortMode mode) {
  return switch (mode) {
    _PreviewSortMode.plan => '默认计划',
    _PreviewSortMode.distance => '按距离',
  };
}

String _sortDirectionTooltip(_PreviewSortMode mode, bool descending) {
  return switch (mode) {
    _PreviewSortMode.plan => descending ? '反序' : '正序',
    _PreviewSortMode.distance => descending ? '远到近' : '近到远',
  };
}

List<PilgrimagePoint> _displayPointsForGroup(
  _PreviewGroup group, {
  required _PreviewSortMode sortMode,
  required bool descending,
}) {
  final points = [...group.points];
  if (sortMode == _PreviewSortMode.distance) {
    const currentPosition = LatLng(34.8903, 135.8009);
    const distance = Distance();
    points.sort((a, b) {
      final distanceA = distance(currentPosition, a.position);
      final distanceB = distance(currentPosition, b.position);
      return distanceA.compareTo(distanceB);
    });
  }
  if (descending) {
    return points.reversed.toList(growable: false);
  }
  return points;
}

VisitStatus _statusForPoint(PilgrimagePlan plan, PilgrimagePoint point) {
  if (plan.completedPointIds.contains(point.id)) {
    return VisitStatus.completed;
  }
  if (plan.currentPointId == point.id) {
    return VisitStatus.current;
  }
  return VisitStatus.pending;
}

void _showPreviewPointDetailSheet(
  BuildContext context, {
  required PilgrimagePoint point,
  required VisitStatus status,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (context) {
      return _PreviewPointDetailSheet(point: point, status: status);
    },
  );
}

class _PreviewPointDetailSheet extends StatelessWidget {
  const _PreviewPointDetailSheet({required this.point, required this.status});

  final PilgrimagePoint point;
  final VisitStatus status;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.84;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: sheetHeight,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _PreviewReferencePreview(point: point, status: status),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PreviewStatusBadge(status: status),
                          const SizedBox(height: 8),
                          CopyableText(
                            text: point.name,
                            copyLabel: '点位名称',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${point.work.title} / ${point.subtitle}',
                            maxLines: 2,
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
                const SizedBox(height: 16),
                _PreviewInfoRow(
                  icon: Icons.movie_filter_outlined,
                  label: '作品',
                  value: '${point.work.title} / ${point.work.subtitle}',
                ),
                const SizedBox(height: 8),
                _PreviewInfoRow(
                  icon: Icons.local_movies_outlined,
                  label: '场景',
                  value: point.displayEpisodeLabel,
                ),
                const SizedBox(height: 8),
                _PreviewInfoRow(
                  icon: Icons.location_on_outlined,
                  label: '坐标',
                  value:
                      '${point.position.latitude.toStringAsFixed(5)}, ${point.position.longitude.toStringAsFixed(5)}',
                ),
                const SizedBox(height: 8),
                _PreviewInfoRow(
                  icon: Icons.image_outlined,
                  label: '参考',
                  value: point.referenceLabel,
                ),
                const SizedBox(height: 8),
                _PreviewInfoRow(
                  icon: Icons.source_outlined,
                  label: '来源',
                  value: switch (point.source) {
                    PointSource.anitabi => 'Anitabi / ${point.referenceLabel}',
                    PointSource.manual => '手动录入 / ${point.referenceLabel}',
                  },
                ),
                if (point.sourceId != null) ...[
                  const SizedBox(height: 8),
                  _PreviewInfoRow(
                    icon: Icons.tag_outlined,
                    label: 'ID',
                    value: point.sourceId!,
                  ),
                ],
                if (point.sourceUrl != null) ...[
                  const SizedBox(height: 8),
                  _PreviewInfoRow(
                    icon: Icons.link_outlined,
                    label: '链接',
                    value: point.sourceUrl!,
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.near_me_outlined, size: 18),
                        label: const Text('导航'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: const Text('拍摄参考'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: status == VisitStatus.current ? null : () {},
                        icon: const Icon(Icons.flag_outlined, size: 18),
                        label: const Text('设为当前'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('标记完成'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.drive_file_move_outlined, size: 18),
                    label: const Text('移动到其他片区'),
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

class _PreviewReferencePreview extends StatelessWidget {
  const _PreviewReferencePreview({required this.point, required this.status});

  final PilgrimagePoint point;
  final VisitStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      VisitStatus.current => AppColors.accent,
      VisitStatus.completed => AppColors.textSecondary,
      VisitStatus.pending => AppColors.accentDark,
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          border: Border.all(color: AppColors.border),
        ),
        child: ReferenceThumbnail(
          localPath: point.referenceThumbnailPath,
          imageUrl: point.referenceImageUrl,
          fit: BoxFit.cover,
          placeholder: Icon(Icons.image_outlined, color: color, size: 28),
        ),
      ),
    );
  }
}

class _PreviewStatusBadge extends StatelessWidget {
  const _PreviewStatusBadge({required this.status});

  final VisitStatus status;

  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      VisitStatus.current => '当前目标',
      VisitStatus.completed => '已完成',
      VisitStatus.pending => '待访问',
    };
    final color = switch (status) {
      VisitStatus.current => AppColors.accent,
      VisitStatus.completed => AppColors.textSecondary,
      VisitStatus.pending => AppColors.warning,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _PreviewInfoRow extends StatelessWidget {
  const _PreviewInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 19),
        const SizedBox(width: 8),
        SizedBox(
          width: 42,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: CopyableText(
            text: value,
            copyLabel: label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileMapPlanHeader extends StatelessWidget {
  const _MobileMapPlanHeader({required this.plan});

  final PilgrimagePlan plan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              plan.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          _InfoPill(
            icon: Icons.task_alt_outlined,
            label: '${plan.completedPointIds.length} / ${plan.points.length}',
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_horiz),
            tooltip: '计划操作',
          ),
        ],
      ),
    );
  }
}

class _MobileGroupCompactSummary extends StatelessWidget {
  const _MobileGroupCompactSummary({required this.group});

  final _PreviewGroup group;

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

class _MobileMapPreview extends StatelessWidget {
  const _MobileMapPreview({
    required this.group,
    required this.completedPointIds,
    required this.selectedPointId,
    required this.showVirtualLocation,
    required this.height,
    required this.onSelectPoint,
    required this.onToggleVirtualLocation,
  });

  final _PreviewGroup group;
  final Set<String> completedPointIds;
  final String? selectedPointId;
  final bool showVirtualLocation;
  final double height;
  final ValueChanged<PilgrimagePoint> onSelectPoint;
  final VoidCallback onToggleVirtualLocation;

  @override
  Widget build(BuildContext context) {
    final center = _groupMapCenter(group);
    final markers = group.points
        .take(16)
        .map(
          (point) {
            final isSelected = point.id == selectedPointId;
            final isCompleted = completedPointIds.contains(point.id);
            final markerColor = isSelected
                ? AppColors.accentDark
                : isCompleted
                ? AppColors.textSecondary
                : AppColors.accent;
            return Marker(
              point: point.position,
              width: isSelected ? 34 : 28,
              height: isSelected ? 34 : 28,
              child: Tooltip(
                message: point.name,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelectPoint(point),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: markerColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: isSelected ? 2.5 : 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: isSelected ? 9 : 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      isCompleted ? Icons.check : Icons.place,
                      size: isSelected ? 19 : 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            );
          },
        )
        .toList(growable: false);

    return SizedBox(
      height: height,
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
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 15.2,
                  minZoom: 4,
                  maxZoom: 19,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'app.miriago.miriago',
                  ),
                  MarkerLayer(markers: markers),
                  if (showVirtualLocation)
                    MarkerLayer(
                      markers: const [
                        Marker(
                          point: LatLng(34.8903, 135.8009),
                          width: 36,
                          height: 36,
                          child: _VirtualLocationMarker(),
                        ),
                      ],
                    ),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
              Positioned(
                left: 10,
                top: 10,
                right: 10,
                child: Row(
                  children: [
                    _MobileGroupCompactSummary(group: group),
                  ],
                ),
              ),
              Positioned(
                right: 10,
                top: 10,
                child: _MapFloatingIconButton(
                  tooltip: showVirtualLocation ? '隐藏当前位置' : '显示当前位置',
                  icon: showVirtualLocation
                      ? Icons.my_location
                      : Icons.my_location_outlined,
                  onTap: onToggleVirtualLocation,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VirtualLocationMarker extends StatelessWidget {
  const _VirtualLocationMarker();

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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
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
  final IconData icon;
  final VoidCallback onTap;

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
            child: Icon(icon, size: 20, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

LatLng _groupMapCenter(_PreviewGroup group) {
  if (group.group?.anchorLatitude != null &&
      group.group?.anchorLongitude != null) {
    return LatLng(group.group!.anchorLatitude!, group.group!.anchorLongitude!);
  }
  if (group.points.isEmpty) {
    return const LatLng(34.8903, 135.8009);
  }

  final latitude =
      group.points.map((point) => point.position.latitude).reduce((a, b) => a + b) /
      group.points.length;
  final longitude =
      group.points.map((point) => point.position.longitude).reduce((a, b) => a + b) /
      group.points.length;
  return LatLng(latitude, longitude);
}

List<Polygon> _groupPolygons(
  List<_PreviewGroup> groups, {
  required String selectedGroupId,
}) {
  const colors = [
    Color(0xFF0F8B8D),
    Color(0xFFFFCE00),
    Color(0xFF7C3AED),
    Color(0xFF2563EB),
    Color(0xFFE11D48),
  ];

  final polygons = <Polygon>[];
  for (var index = 0; index < groups.length; index += 1) {
    final group = groups[index];
    if (group.isUngrouped || group.points.isEmpty) {
      continue;
    }
    final points = _roundedGroupHull(group.points);
    if (points.length < 3) {
      continue;
    }
    final color = colors[index % colors.length];
    final isSelected = group.id == selectedGroupId;
    polygons.add(
      Polygon(
        points: points,
        color: color.withValues(alpha: isSelected ? 0.28 : 0.14),
        borderColor: color.withValues(alpha: isSelected ? 0.92 : 0.62),
        borderStrokeWidth: isSelected ? 3.5 : 2,
      ),
    );
  }
  return polygons;
}

List<LatLng> _roundedGroupHull(List<PilgrimagePoint> points) {
  const zoom = 15.0;
  const radiusPixels = 42.0;
  const circleSegments = 24;
  final pixels = points
      .map((point) => _latLngToWorldPixel(point.position, zoom))
      .toList(growable: false);

  final circleSamples = <math.Point<double>>[];
  for (final pixel in pixels) {
    for (var index = 0; index < circleSegments; index += 1) {
      final angle = math.pi * 2 * index / circleSegments;
      circleSamples.add(
        math.Point(
          pixel.x + math.cos(angle) * radiusPixels,
          pixel.y + math.sin(angle) * radiusPixels,
        ),
      );
    }
  }

  final hull = _convexHull(circleSamples);
  if (hull.length < 3) {
    return const [];
  }
  return hull
      .map((point) => _worldPixelToLatLng(point, zoom))
      .toList(growable: false);
}

List<math.Point<double>> _convexHull(List<math.Point<double>> points) {
  final sorted = [...points]
    ..sort((a, b) {
      final xCompare = a.x.compareTo(b.x);
      return xCompare == 0 ? a.y.compareTo(b.y) : xCompare;
    });
  if (sorted.length <= 1) {
    return sorted;
  }

  double cross(
    math.Point<double> origin,
    math.Point<double> a,
    math.Point<double> b,
  ) {
    return (a.x - origin.x) * (b.y - origin.y) -
        (a.y - origin.y) * (b.x - origin.x);
  }

  final lower = <math.Point<double>>[];
  for (final point in sorted) {
    while (lower.length >= 2 &&
        cross(lower[lower.length - 2], lower.last, point) <= 0) {
      lower.removeLast();
    }
    lower.add(point);
  }

  final upper = <math.Point<double>>[];
  for (final point in sorted.reversed) {
    while (upper.length >= 2 &&
        cross(upper[upper.length - 2], upper.last, point) <= 0) {
      upper.removeLast();
    }
    upper.add(point);
  }

  return [...lower.take(lower.length - 1), ...upper.take(upper.length - 1)];
}

math.Point<double> _latLngToWorldPixel(LatLng latLng, double zoom) {
  final scale = 256 * math.pow(2, zoom).toDouble();
  final sinLat = math.sin(latLng.latitude * math.pi / 180).clamp(-0.9999, 0.9999);
  final x = (latLng.longitude + 180) / 360 * scale;
  final y =
      (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) * scale;
  return math.Point(x, y);
}

LatLng _worldPixelToLatLng(math.Point<double> point, double zoom) {
  final scale = 256 * math.pow(2, zoom).toDouble();
  final longitude = point.x / scale * 360 - 180;
  final mercatorY = 2 * math.pi * (0.5 - point.y / scale);
  final latitude = math.atan(_sinh(mercatorY)) * 180 / math.pi;
  return LatLng(latitude, longitude);
}

double _sinh(double value) {
  return (math.exp(value) - math.exp(-value)) / 2;
}

class _DesktopPlanPreview extends StatelessWidget {
  const _DesktopPlanPreview({
    required this.plan,
    required this.groups,
    required this.selectedGroupIndex,
    required this.selectedPoint,
    required this.sidebarWidth,
    required this.rightPaneWidth,
    required this.mapHeight,
    required this.sortMode,
    required this.sortDescending,
    required this.showVirtualLocation,
    required this.onSelectGroup,
    required this.onSelectPoint,
    required this.onSetSortMode,
    required this.onToggleSortDirection,
    required this.onToggleVirtualLocation,
    required this.onResizeSidebar,
    required this.onResizeRightPane,
    required this.onResizeMap,
  });

  final PilgrimagePlan plan;
  final List<_PreviewGroup> groups;
  final int selectedGroupIndex;
  final PilgrimagePoint? selectedPoint;
  final double sidebarWidth;
  final double rightPaneWidth;
  final double mapHeight;
  final _PreviewSortMode sortMode;
  final bool sortDescending;
  final bool showVirtualLocation;
  final ValueChanged<int> onSelectGroup;
  final ValueChanged<PilgrimagePoint> onSelectPoint;
  final ValueChanged<_PreviewSortMode> onSetSortMode;
  final VoidCallback onToggleSortDirection;
  final VoidCallback onToggleVirtualLocation;
  final void Function(double deltaX, double viewportWidth) onResizeSidebar;
  final void Function(double deltaX, double viewportWidth) onResizeRightPane;
  final void Function(double deltaY, double paneHeight) onResizeMap;

  @override
  Widget build(BuildContext context) {
    final selectedGroup = groups[selectedGroupIndex];

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxSidebarWidth =
            constraints.maxWidth - rightPaneWidth - _desktopMinCenterWidth;
        final effectiveSidebarWidth = sidebarWidth.clamp(
          220.0,
          maxSidebarWidth < 220 ? 220.0 : maxSidebarWidth,
        );
        final maxRightPaneWidth =
            constraints.maxWidth - effectiveSidebarWidth - _desktopMinCenterWidth;
        final effectiveRightPaneWidth = rightPaneWidth.clamp(
          340.0,
          maxRightPaneWidth < 340 ? 340.0 : maxRightPaneWidth,
        );

        return Row(
          children: [
            SizedBox(
              width: effectiveSidebarWidth,
              child: _DesktopGroupSidebar(
                plan: plan,
                groups: groups,
                selectedIndex: selectedGroupIndex,
                onSelectGroup: onSelectGroup,
              ),
            ),
            _DesktopVerticalResizeHandle(
              onDrag: (deltaX) =>
                  onResizeSidebar(deltaX, constraints.maxWidth),
            ),
            Expanded(
              child: _DesktopPointWorkspace(
                plan: plan,
                group: selectedGroup,
                selectedPoint: selectedPoint,
                sortMode: sortMode,
                sortDescending: sortDescending,
                onSelectPoint: onSelectPoint,
                onSetSortMode: onSetSortMode,
                onToggleSortDirection: onToggleSortDirection,
              ),
            ),
            _DesktopVerticalResizeHandle(
              onDrag: (deltaX) =>
                  onResizeRightPane(deltaX, constraints.maxWidth),
            ),
            SizedBox(
              width: effectiveRightPaneWidth,
              child: _DesktopMapDetailPane(
                plan: plan,
                group: selectedGroup,
                selectedPoint: selectedPoint,
                mapHeight: mapHeight,
                showVirtualLocation: showVirtualLocation,
                onSelectPoint: onSelectPoint,
                onToggleVirtualLocation: onToggleVirtualLocation,
                onResizeMap: onResizeMap,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DesktopVerticalResizeHandle extends StatelessWidget {
  const _DesktopVerticalResizeHandle({required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        child: SizedBox(
          width: 8,
          height: double.infinity,
          child: Center(
            child: SizedBox(
              width: 1,
              height: double.infinity,
              child: ColoredBox(color: AppColors.border),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopHorizontalResizeHandle extends StatelessWidget {
  const _DesktopHorizontalResizeHandle({required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) => onDrag(details.delta.dy),
        child: SizedBox(
          height: 8,
          width: double.infinity,
          child: Center(
            child: SizedBox(
              height: 1,
              width: double.infinity,
              child: ColoredBox(color: AppColors.border),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanHeader extends StatelessWidget {
  const _PlanHeader({required this.plan, this.compact = false});

  final PilgrimagePlan plan;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final completed = plan.completedPointIds.length;
    final total = plan.points.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 12 : 20, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 22 : 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.more_horiz),
                tooltip: '计划操作',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(icon: Icons.place_outlined, label: plan.area),
              _InfoPill(icon: Icons.category_outlined, label: '${plan.groups.length} 个片区'),
              _InfoPill(icon: Icons.task_alt_outlined, label: '$completed / $total 完成'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MobileGroupSwitcher extends StatelessWidget {
  const _MobileGroupSwitcher({
    required this.groups,
    required this.selectedIndex,
    required this.onSelectGroup,
  });

  final List<_PreviewGroup> groups;
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
                trailing: Text('${group.completedCount} / ${group.points.length}'),
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

class _MobileGroupSummary extends StatelessWidget {
  const _MobileGroupSummary({required this.group});

  final _PreviewGroup group;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group.anchorLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _Metric(label: '点位', value: '${group.points.length}'),
                _Metric(label: '完成', value: '${group.completedCount}'),
                _Metric(label: '模式', value: group.orderModeLabel),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopGroupSidebar extends StatelessWidget {
  const _DesktopGroupSidebar({
    required this.plan,
    required this.groups,
    required this.selectedIndex,
    required this.onSelectGroup,
  });

  final PilgrimagePlan plan;
  final List<_PreviewGroup> groups;
  final int selectedIndex;
  final ValueChanged<int> onSelectGroup;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlanHeader(plan: plan),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add),
                    label: const Text('新建片区'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              itemCount: groups.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final group = groups[index];
                return _GroupSidebarTile(
                  group: group,
                  isSelected: index == selectedIndex,
                  onTap: () => onSelectGroup(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupSidebarTile extends StatelessWidget {
  const _GroupSidebarTile({
    required this.group,
    required this.isSelected,
    required this.onTap,
  });

  final _PreviewGroup group;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    group.isUngrouped
                        ? Icons.inventory_2_outlined
                        : Icons.folder_outlined,
                    size: 20,
                    color: isSelected
                        ? AppColors.accentDark
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  Text(
                    '${group.completedCount}/${group.points.length}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                group.anchorLabel,
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
      ),
    );
  }
}

class _DesktopPointWorkspace extends StatelessWidget {
  const _DesktopPointWorkspace({
    required this.plan,
    required this.group,
    required this.selectedPoint,
    required this.sortMode,
    required this.sortDescending,
    required this.onSelectPoint,
    required this.onSetSortMode,
    required this.onToggleSortDirection,
  });

  final PilgrimagePlan plan;
  final _PreviewGroup group;
  final PilgrimagePoint? selectedPoint;
  final _PreviewSortMode sortMode;
  final bool sortDescending;
  final ValueChanged<PilgrimagePoint> onSelectPoint;
  final ValueChanged<_PreviewSortMode> onSetSortMode;
  final VoidCallback onToggleSortDirection;

  @override
  Widget build(BuildContext context) {
    final displayPoints = _displayPointsForGroup(
      group,
      sortMode: sortMode,
      descending: sortDescending,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      group.anchorLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              _InfoPill(
                icon: Icons.task_alt_outlined,
                label: '${group.completedCount} / ${group.points.length}',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              SizedBox(width: 170, child: _SearchField()),
              const SizedBox(width: 8),
              SizedBox(
                width: 230,
                child: _SortOrderControl(
                  mode: sortMode,
                  descending: sortDescending,
                  onChanged: onSetSortMode,
                  onToggleDirection: onToggleSortDirection,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            itemCount: displayPoints.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final point = displayPoints[index];
              return _PointListTile(
                point: point,
                isSelected: point.id == selectedPoint?.id,
                isCompleted: plan.completedPointIds.contains(point.id),
                onTap: () => onSelectPoint(point),
                showDragHandle: true,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DesktopMapDetailPane extends StatelessWidget {
  const _DesktopMapDetailPane({
    required this.plan,
    required this.group,
    required this.selectedPoint,
    required this.mapHeight,
    required this.showVirtualLocation,
    required this.onSelectPoint,
    required this.onToggleVirtualLocation,
    required this.onResizeMap,
  });

  final PilgrimagePlan plan;
  final _PreviewGroup group;
  final PilgrimagePoint? selectedPoint;
  final double mapHeight;
  final bool showVirtualLocation;
  final ValueChanged<PilgrimagePoint> onSelectPoint;
  final VoidCallback onToggleVirtualLocation;
  final void Function(double deltaY, double paneHeight) onResizeMap;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final effectiveMapHeight = mapHeight.clamp(
            200.0,
            (constraints.maxHeight - 240).clamp(220.0, 620.0),
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _MobileMapPreview(
                  group: group,
                  completedPointIds: plan.completedPointIds,
                  selectedPointId: selectedPoint?.id,
                  showVirtualLocation: showVirtualLocation,
                  height: effectiveMapHeight,
                  onSelectPoint: onSelectPoint,
                  onToggleVirtualLocation: onToggleVirtualLocation,
                ),
              ),
              _DesktopHorizontalResizeHandle(
                onDrag: (deltaY) => onResizeMap(deltaY, constraints.maxHeight),
              ),
              Expanded(
                child: selectedPoint == null
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: _EmptyGroupPlaceholder(),
                      )
                    : _DesktopPointDetailBody(
                        point: selectedPoint!,
                        group: group,
                        status: _statusForPoint(plan, selectedPoint!),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DesktopPointDetailBody extends StatelessWidget {
  const _DesktopPointDetailBody({
    required this.point,
    required this.group,
    required this.status,
  });

  final PilgrimagePoint point;
  final _PreviewGroup group;
  final VisitStatus status;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PreviewReferencePreview(point: point, status: status),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PreviewStatusBadge(status: status),
                    const SizedBox(height: 8),
                    CopyableText(
                      text: point.name,
                      copyLabel: '点位名称',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${point.work.title} / ${point.subtitle}',
                      maxLines: 2,
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
          const SizedBox(height: 16),
          _PreviewInfoRow(
            icon: Icons.folder_outlined,
            label: '片区',
            value: group.name,
          ),
          const SizedBox(height: 8),
          _PreviewInfoRow(
            icon: Icons.local_movies_outlined,
            label: '场景',
            value: point.displayEpisodeLabel,
          ),
          const SizedBox(height: 8),
          _PreviewInfoRow(
            icon: Icons.location_on_outlined,
            label: '坐标',
            value:
                '${point.position.latitude.toStringAsFixed(5)}, ${point.position.longitude.toStringAsFixed(5)}',
          ),
          const SizedBox(height: 8),
          _PreviewInfoRow(
            icon: Icons.image_outlined,
            label: '参考',
            value: point.referenceLabel,
          ),
          const SizedBox(height: 8),
          _PreviewInfoRow(
            icon: Icons.source_outlined,
            label: '来源',
            value: switch (point.source) {
              PointSource.anitabi => 'Anitabi / ${point.referenceLabel}',
              PointSource.manual => '手动录入 / ${point.referenceLabel}',
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.near_me_outlined, size: 18),
                  label: const Text('导航'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('拍摄参考'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.drive_file_move_outlined, size: 18),
              label: const Text('移动到其他片区'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PointListTile extends StatelessWidget {
  const _PointListTile({
    required this.point,
    required this.isSelected,
    required this.isCompleted,
    required this.onTap,
    this.showDragHandle = false,
  });

  final PilgrimagePoint point;
  final bool isSelected;
  final bool isCompleted;
  final VoidCallback onTap;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.1)
              : AppColors.surface,
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.photo_outlined,
                    color: isCompleted ? AppColors.accentDark : AppColors.textSecondary,
                  ),
                ),
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
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        if (isCompleted)
                          Icon(
                            Icons.check_circle,
                            color: AppColors.accentDark,
                            size: 18,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      point.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      point.displayEpisodeLabel,
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
              if (showDragHandle) ...[
                const SizedBox(width: 8),
                const Icon(Icons.drag_handle, color: AppColors.textSecondary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
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

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextField(
        enabled: false,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search, size: 18),
          hintText: '搜索点位',
          hintStyle: const TextStyle(fontSize: 14),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
    );
  }
}

class _EmptyGroupPlaceholder extends StatelessWidget {
  const _EmptyGroupPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            '这个片区还没有点位',
            style: TextStyle(color: AppColors.textSecondary, letterSpacing: 0),
          ),
        ),
      ),
    );
  }
}

class _PreviewGroup {
  const _PreviewGroup({
    required this.id,
    required this.name,
    required this.points,
    required this.completedCount,
    this.group,
    this.isUngrouped = false,
  });

  final String id;
  final String name;
  final PilgrimagePlanGroup? group;
  final List<PilgrimagePoint> points;
  final int completedCount;
  final bool isUngrouped;

  bool get isManualOrder => group?.orderMode == PlanGroupOrderMode.manual;

  String get orderModeLabel {
    if (isUngrouped) {
      return '待整理';
    }
    return isManualOrder ? '手动' : '无序';
  }

  String get anchorLabel {
    if (isUngrouped) {
      return '等待分入片区';
    }
    final anchorName = group?.anchorName;
    if (anchorName == null || anchorName.trim().isEmpty) {
      return '未设置关键点';
    }
    return '关键点：$anchorName';
  }
}

List<_PreviewGroup> _previewGroups(PilgrimagePlan plan) {
  final sortedGroups = [...plan.groups]
    ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  final groups = [
    for (final group in sortedGroups)
      _PreviewGroup(
        id: group.id,
        name: group.name,
        group: group,
        points: _sortedPoints(
          plan.points.where((point) => point.groupId == group.id),
        ),
        completedCount: plan.points
            .where(
              (point) =>
                  point.groupId == group.id &&
                  plan.completedPointIds.contains(point.id),
            )
            .length,
      ),
  ];
  final ungroupedPoints = _sortedPoints(
    plan.points.where((point) => point.groupId == null),
  );
  groups.add(
    _PreviewGroup(
      id: 'ungrouped',
      name: '未分组',
      points: ungroupedPoints,
      completedCount: ungroupedPoints
          .where((point) => plan.completedPointIds.contains(point.id))
          .length,
      isUngrouped: true,
    ),
  );
  return groups;
}

List<PilgrimagePoint> _sortedPoints(Iterable<PilgrimagePoint> points) {
  final sorted = points.toList();
  sorted.sort((a, b) {
    final orderA = a.groupOrderIndex ?? 1 << 30;
    final orderB = b.groupOrderIndex ?? 1 << 30;
    final orderCompare = orderA.compareTo(orderB);
    if (orderCompare != 0) {
      return orderCompare;
    }
    return a.name.compareTo(b.name);
  });
  return sorted;
}

PilgrimagePlan _previewPlan() {
  const work = PilgrimageWork(
    id: 'hibike-euphonium',
    bangumiId: 115908,
    title: '吹响吧！上低音号',
    subtitle: '響け！ユーフォニアム',
    city: '宇治市',
    source: WorkSource.bangumi,
  );

  final base = samplePilgrimagePlan;
  final points = [
    ...base.points,
    const PilgrimagePoint(
      id: 'preview-uji-4',
      work: work,
      name: '宇治市观光中心',
      subtitle: '宇治市観光センター',
      position: LatLng(34.8906, 135.8069),
      episodeLabel: 'EP 4 / 6:20',
      referenceLabel: '用户添加',
      groupId: 'sample-group-uji-station',
      groupOrderIndex: 4,
    ),
    const PilgrimagePoint(
      id: 'preview-uji-5',
      work: work,
      name: '朝雾桥',
      subtitle: '朝霧橋',
      position: LatLng(34.8916, 135.8101),
      episodeLabel: 'EP 4 / 9:41',
      referenceLabel: '用户添加',
      groupId: 'sample-group-uji-station',
      groupOrderIndex: 5,
    ),
    const PilgrimagePoint(
      id: 'preview-uji-6',
      work: work,
      name: '宇治上神社参道',
      subtitle: '宇治上神社参道',
      position: LatLng(34.8911, 135.8112),
      episodeLabel: 'EP 6 / 12:05',
      referenceLabel: '用户添加',
      groupId: 'sample-group-uji-station',
      groupOrderIndex: 6,
    ),
    const PilgrimagePoint(
      id: 'preview-uji-7',
      work: work,
      name: '平等院表参道',
      subtitle: '平等院表参道',
      position: LatLng(34.8894, 135.8066),
      episodeLabel: 'EP 7 / 3:32',
      referenceLabel: '用户添加',
      groupId: 'sample-group-uji-station',
      groupOrderIndex: 7,
    ),
    const PilgrimagePoint(
      id: 'preview-uji-8',
      work: work,
      name: '宇治川中之岛',
      subtitle: '宇治川中の島',
      position: LatLng(34.8904, 135.8092),
      episodeLabel: 'EP 9 / 16:48',
      referenceLabel: '用户添加',
      groupId: 'sample-group-uji-station',
      groupOrderIndex: 8,
    ),
    const PilgrimagePoint(
      id: 'preview-uji-9',
      work: work,
      name: '县通路口',
      subtitle: '県通り入口',
      position: LatLng(34.8887, 135.8052),
      episodeLabel: 'EP 10 / 8:16',
      referenceLabel: '用户添加',
      groupId: 'sample-group-uji-station',
      groupOrderIndex: 9,
    ),
    const PilgrimagePoint(
      id: 'preview-ungrouped-1',
      work: work,
      name: '京阪宇治站前',
      subtitle: '京阪宇治駅',
      position: LatLng(34.8945, 135.8067),
      episodeLabel: 'EP 3 / 4:12',
      referenceLabel: '用户添加',
      groupOrderIndex: 0,
    ),
    const PilgrimagePoint(
      id: 'preview-ungrouped-2',
      work: work,
      name: '宇治川沿岸',
      subtitle: '宇治川',
      position: LatLng(34.8912, 135.8078),
      episodeLabel: 'EP 5 / 18:44',
      referenceLabel: '用户添加',
      groupOrderIndex: 1,
    ),
  ];

  return base.copyWith(
    name: '宇治巡礼计划预览',
    points: points,
    completedPointIds: {
      'anitabi-115908-7evkbmy2',
      'anitabi-115908-7gs3o1mm',
    },
    currentGroupId: 'sample-group-uji-station',
    currentPointId: 'anitabi-115908-3plnxvy',
  );
}
