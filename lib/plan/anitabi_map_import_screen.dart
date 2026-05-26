import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../widgets/snackbar_helper.dart';
import '../data/anitabi_client.dart';
import '../data/anitabi_image_url.dart';
import '../data/pilgrimage_repository.dart';
import '../data/reference_image_cache_stub.dart'
    if (dart.library.io) '../data/reference_image_cache_io.dart'
    as reference_image_cache;
import '../widgets/copyable_info.dart';
import '../widgets/image_viewer_screen.dart';
import 'pilgrimage_models.dart';

class AnitabiMapImportScreen extends StatefulWidget {
  AnitabiMapImportScreen({
    required this.plan,
    required this.repository,
    AnitabiClient? anitabiClient,
    super.key,
  }) : anitabiClient = anitabiClient ?? AnitabiClient();

  final PilgrimagePlan plan;
  final PilgrimageRepository repository;
  final AnitabiClient anitabiClient;

  @override
  State<AnitabiMapImportScreen> createState() => _AnitabiMapImportScreenState();
}

class _AnitabiMapImportScreenState extends State<AnitabiMapImportScreen> {
  final MapController _mapController = MapController();
  late final Set<String> _importedPointIds;
  PilgrimageWork? _selectedWork;
  AnitabiBangumiLite? _lite;
  List<AnitabiPoint> _points = const [];
  AnitabiPoint? _selectedPoint;
  Object? _error;
  bool _isLoading = false;
  bool _isImporting = false;
  bool _didImportPoints = false;

  List<PilgrimageWork> get _bangumiWorks => widget.plan.works
      .where((work) => work.bangumiId != null)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _importedPointIds = widget.plan.points.map((point) => point.id).toSet();
    final works = _bangumiWorks;
    if (works.isNotEmpty) {
      _selectedWork = works.first;
      _loadPoints(works.first);
    }
  }

  Future<void> _loadPoints(PilgrimageWork work) async {
    final bangumiId = work.bangumiId;
    if (bangumiId == null) {
      return;
    }

    setState(() {
      _selectedWork = work;
      _isLoading = true;
      _error = null;
      _points = const [];
      _selectedPoint = null;
    });

    try {
      final lite = await widget.anitabiClient.fetchBangumiLite(bangumiId);
      final points = await widget.anitabiClient.fetchPoints(bangumiId);
      if (!mounted) {
        return;
      }

      setState(() {
        _lite = lite;
        _points = points;
        _selectedPoint = points.firstOrNull;
      });
      _mapController.move(lite.center, lite.zoom);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _selectPoint(AnitabiPoint point) {
    setState(() {
      _selectedPoint = point;
    });
  }

  Future<void> _importSelectedPoint() async {
    final work = _selectedWork;
    final point = _selectedPoint;
    if (work == null || point == null || _isImporting) {
      return;
    }

    final pilgrimagePoint = point.toPilgrimagePoint(work);
    if (_importedPointIds.contains(pilgrimagePoint.id)) {
      return;
    }

    setState(() {
      _isImporting = true;
    });

    try {
      var importedPlan = await widget.repository.addPointToPlan(
        planId: widget.plan.id,
        point: pilgrimagePoint,
      );
      final thumbnailPath = await reference_image_cache.cacheReferenceThumbnail(
        pilgrimagePoint,
      );
      if (thumbnailPath != null) {
        importedPlan = await widget.repository.updatePointImageCache(
          planId: widget.plan.id,
          pointId: pilgrimagePoint.id,
          referenceThumbnailPath: thumbnailPath,
          referenceFullImagePath: importedPlan.points
              .firstWhere((point) => point.id == pilgrimagePoint.id)
              .referenceFullImagePath,
        );
      }
      if (!mounted) {
        return;
      }

      setState(() {
        _importedPointIds.add(pilgrimagePoint.id);
        _didImportPoints = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showReplacingSnackBar(const SnackBar(content: Text('已加入计划，可继续选择点位。')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showReplacingSnackBar(const SnackBar(content: Text('点位导入失败，请稍后重试。')));
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final works = _bangumiWorks;
    final selectedPoint = _selectedPoint;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }

        Navigator.of(context).pop(_didImportPoints);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('从作品地图导入'),
          bottom: works.isEmpty
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(58),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: DropdownButtonFormField<PilgrimageWork>(
                      initialValue: _selectedWork,
                      decoration: const InputDecoration(labelText: '作品'),
                      items: [
                        for (final work in works)
                          DropdownMenuItem<PilgrimageWork>(
                            value: work,
                            child: Text(work.title),
                          ),
                      ],
                      onChanged: (work) {
                        if (work != null) {
                          _loadPoints(work);
                        }
                      },
                    ),
                  ),
                ),
        ),
        body: Builder(
          builder: (context) {
            if (works.isEmpty) {
              return const _EmptyImportState();
            }

            if (_error != null) {
              return _ImportErrorState(onRetry: () => _loadPoints(works.first));
            }

            return Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _lite?.center ?? const LatLng(35.0, 135.0),
                    initialZoom: _lite?.zoom ?? 12,
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
                    MarkerLayer(
                      markers: [
                        for (final point in _points)
                          Marker(
                            point: point.position,
                            width: 40,
                            height: 40,
                            child: _ImportMarker(
                              selected: selectedPoint?.id == point.id,
                              imported: _importedPointIds.contains(
                                point.toPilgrimagePoint(_selectedWork!).id,
                              ),
                              onTap: () => _selectPoint(point),
                            ),
                          ),
                      ],
                    ),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                          'OpenStreetMap contributors',
                          onTap: () {
                            launchUrl(
                              Uri.parse(
                                'https://www.openstreetmap.org/copyright',
                              ),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: _ImportSummary(
                    isLoading: _isLoading,
                    importedCount: _points
                        .where(
                          (point) => _importedPointIds.contains(
                            point.toPilgrimagePoint(_selectedWork!).id,
                          ),
                        )
                        .length,
                    totalCount: _points.length,
                    expectedCount: _lite?.pointsLength,
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: selectedPoint == null
                      ? const _NoPointSelectedCard()
                      : _AnitabiPointCard(
                          point: selectedPoint,
                          imported: _importedPointIds.contains(
                            selectedPoint.toPilgrimagePoint(_selectedWork!).id,
                          ),
                          isImporting: _isImporting,
                          onImport: _importSelectedPoint,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ImportMarker extends StatelessWidget {
  const _ImportMarker({
    required this.selected,
    required this.imported,
    required this.onTap,
  });

  final bool selected;
  final bool imported;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: imported ? '已导入点位' : '可导入点位',
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: imported ? AppColors.surfaceMuted : AppColors.surface,
        foregroundColor: imported ? AppColors.textSecondary : AppColors.accent,
        side: BorderSide(
          color: selected ? AppColors.warning : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      icon: Icon(imported ? Icons.check : Icons.place, size: 22),
    );
  }
}

class _ImportSummary extends StatelessWidget {
  const _ImportSummary({
    required this.isLoading,
    required this.importedCount,
    required this.totalCount,
    required this.expectedCount,
  });

  final bool isLoading;
  final int importedCount;
  final int totalCount;
  final int? expectedCount;

  @override
  Widget build(BuildContext context) {
    final expected = expectedCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(Icons.map_outlined, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isLoading
                  ? '正在加载 Anitabi 点位'
                  : '已导入 $importedCount / 当前显示 $totalCount${expected == null ? '' : ' / 共 $expected'}',
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
}

class _AnitabiPointCard extends StatelessWidget {
  const _AnitabiPointCard({
    required this.point,
    required this.imported,
    required this.isImporting,
    required this.onImport,
  });

  final AnitabiPoint point;
  final bool imported;
  final bool isImporting;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final imageUrl = _anitabiThumbnailUrl(point.referenceImageUrl);
    final fullImageUrl = anitabiFullResolutionImageUrl(point.referenceImageUrl);

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Material(
              color: AppColors.surfaceMuted,
              child: InkWell(
                onTap: fullImageUrl == null
                    ? null
                    : () => ImageViewerScreen.show(
                        context,
                        imageUrl: fullImageUrl,
                      ),
                child: SizedBox(
                  width: 86,
                  height: 86,
                  child: imageUrl == null
                      ? const Icon(Icons.image_outlined)
                      : Image.network(imageUrl, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    CopyValueButton(
                      label: '点位名称',
                      value: point.name,
                      iconSize: 17,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${point.subtitle} / ${point.episodeLabel}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    CopyValueButton(
                      label: '点位信息',
                      value: _copySummary,
                      iconSize: 17,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  point.origin,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: imported || isImporting ? null : onImport,
                  icon: Icon(
                    imported ? Icons.check : Icons.add_location_alt_outlined,
                    size: 18,
                  ),
                  label: Text(imported ? '已加入计划' : '加入计划'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _copySummary {
    return [
      point.name,
      point.subtitle,
      point.episodeLabel,
      point.origin,
      '${point.position.latitude.toStringAsFixed(5)},${point.position.longitude.toStringAsFixed(5)}',
    ].where((value) => value.trim().isNotEmpty).join('\n');
  }
}

class _NoPointSelectedCard extends StatelessWidget {
  const _NoPointSelectedCard();

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
          Icon(Icons.touch_app_outlined, color: AppColors.accent),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '点击地图上的点位查看缩略图和详情。',
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

String? _anitabiThumbnailUrl(String? url) {
  final fullUrl = anitabiFullResolutionImageUrl(url);
  if (fullUrl == null || fullUrl.isEmpty) {
    return fullUrl;
  }

  final uri = Uri.tryParse(fullUrl);
  if (uri == null || uri.host != 'image.anitabi.cn') {
    return fullUrl;
  }

  return uri
      .replace(queryParameters: {...uri.queryParameters, 'plan': 'h160'})
      .toString();
}

class _EmptyImportState extends StatelessWidget {
  const _EmptyImportState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          '当前计划还没有 Bangumi 作品。请先到作品管理添加 Bangumi 作品。',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _ImportErrorState extends StatelessWidget {
  const _ImportErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('重新加载 Anitabi 点位'),
      ),
    );
  }
}
