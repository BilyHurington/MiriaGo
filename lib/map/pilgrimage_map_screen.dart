import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../camera_reference/camerawesome_reference_screen.dart';
import '../point_detail/point_detail_sheet.dart';
import '../plan/pilgrimage_models.dart';
import '../plan/pilgrimage_plan_controller.dart';
import 'map_navigation_launcher.dart';

class PilgrimageMapScreen extends StatefulWidget {
  const PilgrimageMapScreen({required this.controller, super.key});

  final PilgrimagePlanController controller;

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
  String? _selectedWorkId;

  PilgrimagePlanController get _controller => widget.controller;

  List<PilgrimagePoint> get _visiblePoints {
    final selectedWorkId = _selectedWorkId;
    if (selectedWorkId == null) {
      return _controller.points;
    }

    return _controller.points
        .where((point) => point.work.id == selectedWorkId)
        .toList(growable: false);
  }

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
    _controller.selectPoint(point);
    _mapController.move(point.position, 16);
  }

  void _selectWorkFilter(String? workId) {
    setState(() {
      _selectedWorkId = workId;
    });
  }

  void _moveToCurrentTarget() {
    final currentPoint = _controller.currentPoint;
    if (currentPoint == null) {
      _showSnackBar('当前计划还没有点位。');
      return;
    }

    setState(() {
      _selectedWorkId = null;
    });
    _controller.selectPoint(currentPoint);
    _mapController.move(currentPoint.position, 16);
  }

  void _openCamera(PilgrimagePoint point) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CamerawesomeReferenceScreen(point: point, controller: _controller),
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
      records: _controller.recordsForPoint(point.id),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final visiblePoints = _visiblePoints;
    final selectedPoint =
        visiblePoints.any((point) => point.id == _controller.selectedPoint?.id)
        ? _controller.selectedPoint
        : null;
    final initialCenter = _controller.currentPoint?.position ?? _fallbackCenter;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_controller.plan.area),
        actions: [
          IconButton(
            tooltip: '当前目标',
            onPressed: _moveToCurrentTarget,
            icon: const Icon(Icons.flag_outlined),
          ),
          IconButton(
            tooltip: '定位',
            onPressed: _isLocating ? null : _locateUser,
            icon: _isLocating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
          ),
        ],
      ),
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
                userAgentPackageName: 'app.seichijunrei.seichi_junrei_helper',
              ),
              MarkerLayer(
                markers: [
                  for (final point in visiblePoints)
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
          if (_worksForPlan(_controller.plan).length > 1)
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: _MapWorkFilterBar(
                works: _worksForPlan(_controller.plan),
                selectedWorkId: _selectedWorkId,
                visiblePointCount: visiblePoints.length,
                onWorkSelected: _selectWorkFilter,
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

  double? _distanceToSelectedPoint(PilgrimagePoint point) {
    final currentLocation = _currentLocation;
    if (currentLocation == null) {
      return null;
    }

    return _distance(currentLocation, point.position);
  }
}

class _MapWorkFilterBar extends StatelessWidget {
  const _MapWorkFilterBar({
    required this.works,
    required this.selectedWorkId,
    required this.visiblePointCount,
    required this.onWorkSelected,
  });

  final List<PilgrimageWork> works;
  final String? selectedWorkId;
  final int visiblePointCount;
  final ValueChanged<String?> onWorkSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _MapFilterChip(
                    label: '全部',
                    selected: selectedWorkId == null,
                    onSelected: () => onWorkSelected(null),
                  ),
                  for (final work in works) ...[
                    const SizedBox(width: 8),
                    _MapFilterChip(
                      label: work.title,
                      selected: selectedWorkId == work.id,
                      onSelected: () => onWorkSelected(work.id),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$visiblePointCount 点',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapFilterChip extends StatelessWidget {
  const _MapFilterChip({
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
          fontSize: 12,
          fontWeight: FontWeight.w800,
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
                          child: Text(
                            point.name,
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
                    Text(
                      _metaText,
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
          if (point.referenceImageUrl != null) ...[
            const SizedBox(height: 8),
            Text(
              point.episodeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                letterSpacing: 0,
              ),
            ),
          ],
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
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenDetail,
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('详情'),
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
}

class _PointThumbnail extends StatelessWidget {
  const _PointThumbnail({required this.point});

  final PilgrimagePoint point;

  @override
  Widget build(BuildContext context) {
    final imageUrl = point.referenceImageUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 64,
        height: 64,
        color: AppColors.surfaceMuted,
        child: imageUrl == null
            ? const Icon(Icons.image_outlined, color: AppColors.accentDark)
            : Image.network(imageUrl, fit: BoxFit.cover),
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
          const Icon(
            Icons.photo_library_outlined,
            size: 15,
            color: AppColors.accentDark,
          ),
          const SizedBox(width: 5),
          Text(
            '已拍 $count',
            style: const TextStyle(
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
      child: const Row(
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
