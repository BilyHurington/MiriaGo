import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_theme.dart';
import '../map/map_tile_config.dart';
import 'pilgrimage_models.dart';

class GroupAnchorSelection {
  const GroupAnchorSelection({
    required this.name,
    required this.position,
    required this.pointId,
  });

  const GroupAnchorSelection.clear()
    : name = null,
      position = null,
      pointId = null;

  final String? name;
  final LatLng? position;
  final String? pointId;
}

class GroupAnchorPickerScreen extends StatefulWidget {
  const GroupAnchorPickerScreen({
    required this.group,
    required this.points,
    required this.groupNameForPoint,
    required this.settings,
    super.key,
  });

  final PilgrimagePlanGroup group;
  final List<PilgrimagePoint> points;
  final String Function(PilgrimagePoint point) groupNameForPoint;
  final AppSettings settings;

  @override
  State<GroupAnchorPickerScreen> createState() =>
      _GroupAnchorPickerScreenState();
}

class _GroupAnchorPickerScreenState extends State<GroupAnchorPickerScreen> {
  final MapController _mapController = MapController();
  PilgrimagePoint? _selectedPoint;
  LatLng? _manualPosition;
  var _manualPickMode = false;

  @override
  void initState() {
    super.initState();
    final anchorPointId = widget.group.anchorPointId;
    if (anchorPointId != null) {
      _selectedPoint = widget.points
          .where((point) => point.id == anchorPointId)
          .firstOrNull;
    }
    if (_selectedPoint == null &&
        widget.group.anchorLatitude != null &&
        widget.group.anchorLongitude != null) {
      _manualPosition = LatLng(
        widget.group.anchorLatitude!,
        widget.group.anchorLongitude!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedPosition = _selectedPoint?.position ?? _manualPosition;

    return Scaffold(
      appBar: AppBar(
        title: const Text('选择关键点'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const GroupAnchorSelection.clear()),
            child: const Text('清除'),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: selectedPosition ?? _pointsCenter,
              initialZoom: 15,
              minZoom: 4,
              maxZoom: 22,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (_, latLng) {
                if (!_manualPickMode) {
                  return;
                }
                setState(() {
                  _selectedPoint = null;
                  _manualPosition = latLng;
                });
              },
            ),
            children: [
              configuredMapTileLayer(widget.settings),
              MarkerLayer(
                markers: [
                  for (final point in widget.points)
                    Marker(
                      point: point.position,
                      width: 42,
                      height: 42,
                      child: _AnchorPointMarker(
                        selected: _selectedPoint?.id == point.id,
                        onTap: () => _selectPoint(point),
                      ),
                    ),
                  if (_manualPosition != null)
                    Marker(
                      point: _manualPosition!,
                      width: 46,
                      height: 46,
                      child: const _ManualAnchorMarker(),
                    ),
                ],
              ),
              configuredMapAttribution(widget.settings),
            ],
          ),
          Positioned(
            right: 12,
            top: 12,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _MapToolButton(
                    tooltip: _manualPickMode ? '关闭地图点选' : '在地图上选点',
                    selected: _manualPickMode,
                    onTap: () {
                      setState(() {
                        _manualPickMode = !_manualPickMode;
                      });
                    },
                    icon: Icons.ads_click_outlined,
                  ),
                  const SizedBox(height: 8),
                  _MapToolButton(
                    tooltip: '输入经纬度',
                    selected: false,
                    onTap: _showCoordinateInput,
                    icon: Icons.edit_location_alt_outlined,
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _AnchorSelectionCard(
              selectedPoint: _selectedPoint,
              manualPosition: _manualPosition,
              groupNameForPoint: widget.groupNameForPoint,
              manualPickMode: _manualPickMode,
              onSave: selectedPosition == null ? null : _saveSelection,
            ),
          ),
        ],
      ),
    );
  }

  LatLng get _pointsCenter {
    if (widget.points.isEmpty) {
      return const LatLng(35, 135);
    }
    final latitude =
        widget.points
            .map((point) => point.position.latitude)
            .reduce((a, b) => a + b) /
        widget.points.length;
    final longitude =
        widget.points
            .map((point) => point.position.longitude)
            .reduce((a, b) => a + b) /
        widget.points.length;
    return LatLng(latitude, longitude);
  }

  void _selectPoint(PilgrimagePoint point) {
    setState(() {
      _selectedPoint = point;
      _manualPosition = null;
      _manualPickMode = false;
    });
    _mapController.move(point.position, 16);
  }

  Future<void> _showCoordinateInput() async {
    final current =
        _manualPosition ?? _selectedPoint?.position ?? _pointsCenter;
    final latitudeController = TextEditingController(
      text: current.latitude.toStringAsFixed(6),
    );
    final longitudeController = TextEditingController(
      text: current.longitude.toStringAsFixed(6),
    );
    final result = await showDialog<LatLng>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('输入经纬度'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: latitudeController,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: '纬度'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: longitudeController,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: '经度'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final latitude = double.tryParse(
                  latitudeController.text.trim(),
                );
                final longitude = double.tryParse(
                  longitudeController.text.trim(),
                );
                if (latitude == null ||
                    longitude == null ||
                    latitude < -90 ||
                    latitude > 90 ||
                    longitude < -180 ||
                    longitude > 180) {
                  return;
                }
                Navigator.of(context).pop(LatLng(latitude, longitude));
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    latitudeController.dispose();
    longitudeController.dispose();
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      _selectedPoint = null;
      _manualPosition = result;
      _manualPickMode = false;
    });
    _mapController.move(result, 16);
  }

  void _saveSelection() {
    final selectedPoint = _selectedPoint;
    if (selectedPoint != null) {
      Navigator.of(context).pop(
        GroupAnchorSelection(
          name: selectedPoint.name,
          position: selectedPoint.position,
          pointId: selectedPoint.id,
        ),
      );
      return;
    }
    final manualPosition = _manualPosition;
    if (manualPosition == null) {
      return;
    }
    Navigator.of(context).pop(
      GroupAnchorSelection(
        name: '手动关键点',
        position: manualPosition,
        pointId: null,
      ),
    );
  }
}

class _AnchorPointMarker extends StatelessWidget {
  const _AnchorPointMarker({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '选择点位',
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: selected ? AppColors.accent : AppColors.surface,
        foregroundColor: selected ? Colors.white : AppColors.accent,
        side: BorderSide(
          color: selected ? AppColors.warning : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      icon: const Icon(Icons.place, size: 21),
    );
  }
}

class _ManualAnchorMarker extends StatelessWidget {
  const _ManualAnchorMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.warning,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: const Icon(Icons.add_location_alt, color: Colors.white),
    );
  }
}

class _MapToolButton extends StatelessWidget {
  const _MapToolButton({
    required this.tooltip,
    required this.selected,
    required this.onTap,
    required this.icon,
  });

  final String tooltip;
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accent : AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon),
        color: selected ? Colors.white : AppColors.textPrimary,
      ),
    );
  }
}

class _AnchorSelectionCard extends StatelessWidget {
  const _AnchorSelectionCard({
    required this.selectedPoint,
    required this.manualPosition,
    required this.groupNameForPoint,
    required this.manualPickMode,
    required this.onSave,
  });

  final PilgrimagePoint? selectedPoint;
  final LatLng? manualPosition;
  final String Function(PilgrimagePoint point) groupNameForPoint;
  final bool manualPickMode;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final point = selectedPoint;
    final position = point?.position ?? manualPosition;
    final title = point?.name ?? (position == null ? '尚未选择关键点' : '手动关键点');
    final subtitle = point == null
        ? (manualPickMode ? '点击地图任意位置设置关键点' : '可点选点位、地图或输入经纬度')
        : '${groupNameForPoint(point)} / ${point.subtitle}';

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.flag_outlined, color: AppColors.accent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  position == null
                      ? subtitle
                      : '$subtitle\n${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
                  maxLines: 2,
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
          FilledButton(onPressed: onSave, child: const Text('保存')),
        ],
      ),
    );
  }
}
