import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../widgets/snackbar_helper.dart';
import '../camera_reference/camerawesome_reference_screen.dart';
import '../point_detail/point_detail_sheet.dart';
import '../plan/plan_group_utils.dart';
import '../plan/pilgrimage_models.dart';
import '../plan/pilgrimage_plan_controller.dart';
import '../widgets/copyable_text.dart';
import '../widgets/image_viewer_screen.dart';
import 'map_navigation_launcher.dart';
import '../widgets/reference_thumbnail_stub.dart'
    if (dart.library.io) '../widgets/reference_thumbnail_io.dart';

class PilgrimageMapScreen extends StatefulWidget {
  const PilgrimageMapScreen({
    required this.controller,
    required this.settings,
    super.key,
  });

  final PilgrimagePlanController controller;
  final AppSettings settings;

  @override
  State<PilgrimageMapScreen> createState() => _PilgrimageMapScreenState();
}

class _PilgrimageMapScreenState extends State<PilgrimageMapScreen> {
  final MapController _mapController = MapController();
  final Distance _distance = const Distance();
  final MapNavigationLauncher _navigationLauncher =
      const MapNavigationLauncher();

  LatLng? _currentLocation;
  bool _isLocating = false;
  int _selectedGroupIndex = 0;

  PilgrimagePlanController get _controller => widget.controller;

  Future<void> _locateUser() async {
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
      final location = LatLng(position.latitude, position.longitude);

      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocation = location;
      });
      _mapController.move(location, 16);
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

  Future<void> _openNavigation(PilgrimagePoint point) async {
    final opened = await _navigationLauncher.openGoogleMapsWalking(point);
    if (!opened) {
      _showSnackBar('无法打开 Google Maps。');
    }
  }

  void _selectPoint(PilgrimagePoint point) {
    final groups = planGroupBuckets(
      _controller.plan,
      _controller.completedPointIds,
    );
    final groupIndex = groups.indexWhere((group) {
      if (point.groupId == null) {
        return group.isUngrouped;
      }
      return group.id == point.groupId;
    });
    if (groupIndex >= 0) {
      setState(() {
        _selectedGroupIndex = groupIndex;
      });
    }
    _controller.selectPoint(point);
    _mapController.move(point.position, 16);
  }

  void _selectGroup(int index, List<PlanGroupBucket> groups) {
    final nextIndex = index.clamp(0, groups.length - 1);
    final group = groups[nextIndex];
    setState(() {
      _selectedGroupIndex = nextIndex;
    });
    if (group.points.isNotEmpty) {
      _mapController.move(groupMapCenter(group), 15);
    }
  }

  void _moveToCurrentTarget() {
    final currentPoint = _controller.currentPoint;
    if (currentPoint == null) {
      _showSnackBar('当前计划还没有点位。');
      return;
    }

    _selectPoint(currentPoint);
  }

  void _openCamera(PilgrimagePoint point) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CamerawesomeReferenceScreen(
          point: point,
          controller: _controller,
          settings: widget.settings,
        ),
      ),
    );
  }

  void _showPointDetail(PilgrimagePoint point) {
    PointDetailSheet.show(
      context,
      point: point,
      status: _controller.statusFor(point),
      onSetCurrent: () => _controller.setCurrentPoint(point),
      onOpenCamera: () => _openCamera(point),
      onComplete: () => _controller.completePoint(point),
      onReplaceReference: (point, image) => _controller.updatePointImageCache(
        point,
        referenceThumbnailPath: image.thumbnailPath,
        referenceFullImagePath: image.fullImagePath,
      ),
      groups: _controller.plan.groups,
      onMoveToGroup: _controller.movePointToGroup,
      records: _controller.recordsForPoint(point.id),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showReplacingSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final groups = planGroupBuckets(
      _controller.plan,
      _controller.completedPointIds,
    );
    if (_selectedGroupIndex >= groups.length) {
      _selectedGroupIndex = groups.isEmpty ? 0 : groups.length - 1;
    }
    final selectedGroup = groups.isEmpty ? null : groups[_selectedGroupIndex];
    final selectedPoint =
        _controller.points.any(
          (point) => point.id == _controller.selectedPoint?.id,
        )
        ? _controller.selectedPoint
        : null;
    final initialCenter = selectedGroup == null
        ? _fallbackCenter
        : groupMapCenter(selectedGroup);
    final selectedGroupId = selectedGroup?.id ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 15,
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
              PolygonLayer(
                polygons: groupAreaPolygons(
                  groups,
                  selectedGroupId: selectedGroupId,
                ),
              ),
              MarkerLayer(
                markers: [
                  for (final point in _controller.points)
                    Marker(
                      point: point.position,
                      width: 44,
                      height: 44,
                      child: _PointMarker(
                        selected: point.id == selectedPoint?.id,
                        status: _controller.statusFor(point),
                        onTap: () => _selectPoint(point),
                      ),
                    ),
                  if (_currentLocation != null)
                    Marker(
                      point: _currentLocation!,
                      width: 44,
                      height: 44,
                      child: const _CurrentLocationMarker(),
                    ),
                ],
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () {
                      launchUrl(
                        Uri.parse('https://www.openstreetmap.org/copyright'),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          if (selectedGroup != null)
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: SafeArea(
                bottom: false,
                child: _MapGroupFilterBar(
                  group: selectedGroup,
                  onTap: () => _showGroupPicker(context, groups),
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
                    tooltip: '定位',
                    onTap: _isLocating ? null : _locateUser,
                    child: _isLocating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location, size: 20),
                  ),
                  const SizedBox(height: 8),
                  _MapFloatingIconButton(
                    tooltip: '当前目标',
                    onTap: _moveToCurrentTarget,
                    child: const Icon(Icons.flag_outlined, size: 20),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: selectedPoint == null
                ? const _EmptyMapCard()
                : _PointCard(
                    point: selectedPoint,
                    status: _controller.statusFor(selectedPoint),
                    recordCount: _controller
                        .recordsForPoint(selectedPoint.id)
                        .length,
                    distanceMeters: _distanceToSelectedPoint(selectedPoint),
                    onSetCurrent: () =>
                        _controller.setCurrentPoint(selectedPoint),
                    onOpenDetail: () => _showPointDetail(selectedPoint),
                    onOpenNavigation: () => _openNavigation(selectedPoint),
                    onOpenCamera: () => _openCamera(selectedPoint),
                    onComplete: () => _controller.completePoint(selectedPoint),
                  ),
          ),
        ],
      ),
    );
  }

  LatLng get _fallbackCenter {
    return const LatLng(34.9671, 135.7727);
  }

  double? _distanceToSelectedPoint(PilgrimagePoint point) {
    final currentLocation = _currentLocation;
    if (currentLocation == null) {
      return null;
    }

    return _distance(currentLocation, point.position);
  }

  void _showGroupPicker(BuildContext context, List<PlanGroupBucket> groups) {
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
                selected: index == _selectedGroupIndex,
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
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _selectGroup(index, groups);
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _MapGroupFilterBar extends StatelessWidget {
  const _MapGroupFilterBar({required this.group, required this.onTap});

  final PlanGroupBucket group;
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
            children: [
              const Icon(Icons.folder_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${group.name} · ${group.completedCount}/${group.points.length}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const Icon(Icons.expand_more, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapFloatingIconButton extends StatelessWidget {
  const _MapFloatingIconButton({
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  final String tooltip;
  final VoidCallback? onTap;
  final Widget child;

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
          child: SizedBox(width: 38, height: 38, child: Center(child: child)),
        ),
      ),
    );
  }
}

class _PointMarker extends StatelessWidget {
  const _PointMarker({
    required this.selected,
    required this.status,
    required this.onTap,
  });

  final bool selected;
  final VisitStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final markerColors = switch (status) {
      VisitStatus.current => (AppColors.accent, Colors.white),
      VisitStatus.completed => (
        AppColors.surfaceMuted,
        AppColors.textSecondary,
      ),
      VisitStatus.pending => (AppColors.surface, AppColors.accentDark),
    };

    return IconButton(
      tooltip: '巡礼点',
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: markerColors.$1,
        foregroundColor: markerColors.$2,
        side: BorderSide(
          color: selected ? AppColors.warning : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      icon: Icon(
        status == VisitStatus.completed ? Icons.check : Icons.place,
        size: 24,
      ),
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
      ),
    );
  }
}

class _PointCard extends StatelessWidget {
  const _PointCard({
    required this.point,
    required this.status,
    required this.recordCount,
    required this.distanceMeters,
    required this.onSetCurrent,
    required this.onOpenDetail,
    required this.onOpenNavigation,
    required this.onOpenCamera,
    required this.onComplete,
  });

  final PilgrimagePoint point;
  final VisitStatus status;
  final int recordCount;
  final double? distanceMeters;
  final VoidCallback onSetCurrent;
  final VoidCallback onOpenDetail;
  final VoidCallback onOpenNavigation;
  final VoidCallback onOpenCamera;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PointThumbnail(point: point),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _StatusBadge(status: status),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CopyableText(
                            text: point.name,
                            copyLabel: '点位名称',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    CopyableText(
                      text: _metaText,
                      copyText: _copySummary,
                      copyLabel: '点位信息',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        letterSpacing: 0,
                      ),
                    ),
                    if (point.referenceImageUrl != null) ...[
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
                  ],
                ),
              ),
            ],
          ),
          if (recordCount > 0) ...[
            const SizedBox(height: 8),
            _MapRecordBadge(count: recordCount),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpenNavigation,
                  icon: const Icon(Icons.near_me_outlined, size: 18),
                  label: const Text('导航'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: '拍摄参考',
                onPressed: onOpenCamera,
                icon: const Icon(Icons.photo_camera_outlined),
              ),
              const SizedBox(width: 4),
              IconButton.outlined(
                tooltip: '标记完成',
                onPressed: onComplete,
                icon: const Icon(Icons.check_outlined),
              ),
              if (status != VisitStatus.current) ...[
                const SizedBox(width: 4),
                IconButton.outlined(
                  tooltip: '设为当前目标',
                  onPressed: onSetCurrent,
                  icon: const Icon(Icons.flag_outlined),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String get _metaText {
    final distance = distanceMeters;
    final coordinate =
        '${point.position.latitude.toStringAsFixed(4)}, ${point.position.longitude.toStringAsFixed(4)}';

    if (distance == null) {
      return '${point.work.title} / ${point.subtitle} / $coordinate';
    }

    if (distance >= 1000) {
      return '${point.work.title} / ${(distance / 1000).toStringAsFixed(1)} km';
    }

    return '${point.work.title} / ${distance.round()} m';
  }

  String get _copySummary {
    return [
      point.name,
      '${point.work.title} / ${point.work.subtitle}',
      point.subtitle,
      point.displayEpisodeLabel,
      '${point.position.latitude.toStringAsFixed(5)},${point.position.longitude.toStringAsFixed(5)}',
    ].where((value) => value.trim().isNotEmpty).join('\n');
  }
}

class _PointThumbnail extends StatelessWidget {
  const _PointThumbnail({required this.point});

  final PilgrimagePoint point;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => ImageViewerScreen.show(
        context,
        filePath: point.referenceFullImagePath,
        imageUrl: point.referenceImageUrl,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 64,
          height: 64,
          color: AppColors.surfaceMuted,
          child: ReferenceThumbnail(
            localPath: point.referenceThumbnailPath,
            imageUrl: point.referenceImageUrl,
            placeholder: Icon(
              Icons.image_outlined,
              color: AppColors.accentDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _MapRecordBadge extends StatelessWidget {
  const _MapRecordBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 15,
            color: AppColors.accentDark,
          ),
          const SizedBox(width: 5),
          Text(
            '已拍 $count',
            style: TextStyle(
              color: AppColors.accentDark,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMapCard extends StatelessWidget {
  const _EmptyMapCard();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.map_outlined, color: AppColors.accent),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '当前计划还没有点位。添加点位后会在地图上显示标记。',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final VisitStatus status;

  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      VisitStatus.current => '当前',
      VisitStatus.completed => '完成',
      VisitStatus.pending => '待访',
    };

    final color = switch (status) {
      VisitStatus.current => AppColors.accent,
      VisitStatus.completed => AppColors.textSecondary,
      VisitStatus.pending => AppColors.warning,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
