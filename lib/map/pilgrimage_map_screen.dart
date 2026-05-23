import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';

class PilgrimagePoint {
  const PilgrimagePoint({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.position,
  });

  final String id;
  final String name;
  final String subtitle;
  final LatLng position;
}

const _samplePoints = [
  PilgrimagePoint(
    id: 'uji-bridge',
    name: '宇治桥',
    subtitle: '示例点位 / Uji, Kyoto',
    position: LatLng(34.8917, 135.8077),
  ),
  PilgrimagePoint(
    id: 'agata-dori',
    name: 'あがた通り',
    subtitle: '示例点位 / Uji, Kyoto',
    position: LatLng(34.8899, 135.8081),
  ),
  PilgrimagePoint(
    id: 'uji-station',
    name: 'JR 宇治站',
    subtitle: '示例点位 / Uji, Kyoto',
    position: LatLng(34.8905, 135.8008),
  ),
];

class PilgrimageMapScreen extends StatefulWidget {
  const PilgrimageMapScreen({super.key});

  @override
  State<PilgrimageMapScreen> createState() => _PilgrimageMapScreenState();
}

class _PilgrimageMapScreenState extends State<PilgrimageMapScreen> {
  final MapController _mapController = MapController();
  final Distance _distance = const Distance();

  PilgrimagePoint _selectedPoint = _samplePoints.first;
  LatLng? _currentLocation;
  bool _isLocating = false;

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

  Future<void> _openGoogleMaps(PilgrimagePoint point) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${point.position.latitude},${point.position.longitude}',
      'travelmode': 'walking',
    });

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      _showSnackBar('无法打开 Google Maps。');
    }
  }

  void _selectPoint(PilgrimagePoint point) {
    setState(() {
      _selectedPoint = point;
    });
    _mapController.move(point.position, 16);
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('地图'),
        actions: [
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
              initialCenter: _selectedPoint.position,
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
                  for (final point in _samplePoints)
                    Marker(
                      point: point.position,
                      width: 44,
                      height: 44,
                      child: _PointMarker(
                        selected: point.id == _selectedPoint.id,
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
          Align(
            alignment: Alignment.bottomCenter,
            child: _PointCard(
              point: _selectedPoint,
              distanceMeters: _distanceToSelectedPoint(),
              onOpenNavigation: () => _openGoogleMaps(_selectedPoint),
            ),
          ),
        ],
      ),
    );
  }

  double? _distanceToSelectedPoint() {
    final currentLocation = _currentLocation;
    if (currentLocation == null) {
      return null;
    }

    return _distance(currentLocation, _selectedPoint.position);
  }
}

class _PointMarker extends StatelessWidget {
  const _PointMarker({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '巡礼点',
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: selected ? AppColors.accent : AppColors.surface,
        foregroundColor: selected ? Colors.white : AppColors.accentDark,
        side: const BorderSide(color: AppColors.border),
      ),
      icon: const Icon(Icons.place, size: 24),
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
    required this.distanceMeters,
    required this.onOpenNavigation,
  });

  final PilgrimagePoint point;
  final double? distanceMeters;
  final VoidCallback onOpenNavigation;

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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.place_outlined,
              color: AppColors.accentDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onOpenNavigation,
            icon: const Icon(Icons.near_me_outlined, size: 18),
            label: const Text('导航'),
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
      return '${point.subtitle} / $coordinate';
    }

    if (distance >= 1000) {
      return '${point.subtitle} / ${(distance / 1000).toStringAsFixed(1)} km';
    }

    return '${point.subtitle} / ${distance.round()} m';
  }
}
