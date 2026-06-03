import 'dart:math' as math;

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
import '../widgets/copyable_text.dart';
import '../widgets/image_viewer_screen.dart';
import '../widgets/reference_thumbnail_stub.dart'
    if (dart.library.io) '../widgets/reference_thumbnail_io.dart';
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
  late PilgrimagePlan _importedPlan = widget.plan;
  PilgrimageWork? _selectedWork;
  AnitabiBangumiLite? _lite;
  List<AnitabiPoint> _points = const [];
  AnitabiPoint? _selectedPoint;
  Object? _error;
  bool _isLoading = false;
  bool _isImporting = false;
  bool _didImportPoints = false;
  bool _isBoxSelecting = false;
  Offset? _selectionStart;
  Offset? _selectionEnd;

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

  PilgrimagePoint? _importedPointFor(AnitabiPoint point) {
    final importedPointId = point.toPilgrimagePoint(_selectedWork!).id;
    for (final importedPoint in _importedPlan.points) {
      if (importedPoint.id == importedPointId) {
        return importedPoint;
      }
    }
    return null;
  }

  List<AnitabiPoint> get _availablePoints {
    final work = _selectedWork;
    if (work == null) {
      return const [];
    }
    return _points
        .where(
          (point) => !_importedPointIds.contains(
            point.toPilgrimagePoint(work).id,
          ),
        )
        .toList(growable: false);
  }

  Rect? get _selectionRect {
    final start = _selectionStart;
    final end = _selectionEnd;
    if (start == null || end == null) {
      return null;
    }
    return Rect.fromPoints(start, end);
  }

  List<AnitabiPoint> _pointsInSelection() {
    final rect = _selectionRect;
    final work = _selectedWork;
    if (rect == null || work == null) {
      return const [];
    }

    return _availablePoints
        .where((point) {
          final offset = _mapController.camera.latLngToScreenOffset(
            point.position,
          );
          return rect.contains(offset);
        })
        .toList(growable: false);
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

    await _importPoints(
      [point],
      successMessage: '已加入计划，可继续选择点位。',
      failureMessage: '点位导入失败，请稍后重试。',
    );
  }

  Future<void> _importAllAvailablePoints() async {
    await _importPoints(
      _availablePoints,
      successMessage: '已添加所有未加入的点位。',
      failureMessage: '批量导入失败，请稍后重试。',
    );
  }

  Future<void> _importSelectedBoxPoints() async {
    final points = _pointsInSelection();
    if (points.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showReplacingSnackBar(const SnackBar(content: Text('框选范围内没有可添加点位')));
      return;
    }

    await _importPoints(
      points,
      successMessage: '已添加框选点位。',
      failureMessage: '框选点位导入失败，请稍后重试。',
    );
  }

  Future<void> _importPoints(
    List<AnitabiPoint> points, {
    required String successMessage,
    required String failureMessage,
  }) async {
    final work = _selectedWork;
    if (work == null || points.isEmpty || _isImporting) {
      return;
    }

    final pilgrimagePoints = points
        .map((point) => point.toPilgrimagePoint(work))
        .where((point) => !_importedPointIds.contains(point.id))
        .toList(growable: false);
    if (pilgrimagePoints.isEmpty) {
      return;
    }

    setState(() {
      _isImporting = true;
    });

    try {
      var importedPlan = pilgrimagePoints.length == 1
          ? await widget.repository.addPointToPlan(
              planId: widget.plan.id,
              point: pilgrimagePoints.single,
            )
          : await widget.repository.addPointsToPlan(
              planId: widget.plan.id,
              points: pilgrimagePoints,
            );

      for (final pilgrimagePoint in pilgrimagePoints) {
        final thumbnailPath = await reference_image_cache.cacheReferenceThumbnail(
          pilgrimagePoint,
        );
        if (thumbnailPath == null) {
          continue;
        }
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
        _importedPlan = importedPlan;
        _importedPointIds.addAll(
          pilgrimagePoints.map((point) => point.id),
        );
        _didImportPoints = true;
        _selectionStart = null;
        _selectionEnd = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showReplacingSnackBar(SnackBar(content: Text(successMessage)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showReplacingSnackBar(SnackBar(content: Text(failureMessage)));
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  void _toggleBoxSelection() {
    setState(() {
      _isBoxSelecting = !_isBoxSelecting;
      _selectionStart = null;
      _selectionEnd = null;
    });
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
                            child: Text(
                              work.displayBangumiSubjectType == null
                                  ? work.title
                                  : '${work.title} · ${work.displayBangumiSubjectType!.label}',
                              overflow: TextOverflow.ellipsis,
                            ),
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
              return _ImportErrorState(
                message: _errorMessageFor(_error),
                detail: _errorDetailFor(_error),
                onRetry: () => _loadPoints(_selectedWork ?? works.first),
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final selectedBoxCount = _pointsInSelection().length;

                return Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter:
                            _lite?.center ?? const LatLng(35.0, 135.0),
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
                    if (_isBoxSelecting)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: (details) {
                            setState(() {
                              _selectionStart = details.localPosition;
                              _selectionEnd = details.localPosition;
                            });
                          },
                          onPanUpdate: (details) {
                            setState(() {
                              _selectionEnd = details.localPosition;
                            });
                          },
                          child: CustomPaint(
                            painter: _SelectionRectPainter(_selectionRect),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 12,
                      left: 16,
                      right: 16,
                      child: _ImportSummary(
                        isLoading: _isLoading,
                        isImporting: _isImporting,
                        importedCount: _points
                            .where(
                              (point) => _importedPointIds.contains(
                                point.toPilgrimagePoint(_selectedWork!).id,
                              ),
                            )
                            .length,
                        totalCount: _points.length,
                        expectedCount: _lite?.pointsLength,
                        availableCount: _availablePoints.length,
                        boxSelectionEnabled: _isBoxSelecting,
                        selectedBoxCount: selectedBoxCount,
                        onToggleBoxSelection: _toggleBoxSelection,
                        onImportAll: _importAllAvailablePoints,
                        onImportSelection: _importSelectedBoxPoints,
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: selectedPoint == null
                          ? _NoPointSelectedCard(
                              hasPoints: _points.isNotEmpty,
                              expectedCount: _lite?.pointsLength,
                            )
                          : _AnitabiPointCard(
                              point: selectedPoint,
                              importedPoint: _importedPointFor(selectedPoint),
                              imported: _importedPointIds.contains(
                                selectedPoint.toPilgrimagePoint(
                                  _selectedWork!,
                                ).id,
                              ),
                              isImporting: _isImporting,
                              onImport: _importSelectedPoint,
                            ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _errorMessageFor(Object? error) {
    if (error is AnitabiException && error.statusCode == 404) {
      return '这个 Bangumi 条目暂无 Anitabi 地图数据';
    }

    return 'Anitabi 点位加载失败';
  }

  String _errorDetailFor(Object? error) {
    if (error is AnitabiException && error.statusCode == 404) {
      return '可以尝试在作品管理中添加同名的原作、游戏或其他关联条目。';
    }

    return '请检查网络后重试，或稍后再重新加载。';
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
    required this.isImporting,
    required this.importedCount,
    required this.totalCount,
    required this.expectedCount,
    required this.availableCount,
    required this.boxSelectionEnabled,
    required this.selectedBoxCount,
    required this.onToggleBoxSelection,
    required this.onImportAll,
    required this.onImportSelection,
  });

  final bool isLoading;
  final bool isImporting;
  final int importedCount;
  final int totalCount;
  final int? expectedCount;
  final int availableCount;
  final bool boxSelectionEnabled;
  final int selectedBoxCount;
  final VoidCallback onToggleBoxSelection;
  final VoidCallback onImportAll;
  final VoidCallback onImportSelection;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (isLoading || isImporting)
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
          if (!isLoading) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton.outlined(
                    tooltip: '添加所有点位',
                    onPressed: isImporting || availableCount == 0
                        ? null
                        : onImportAll,
                    icon: const Icon(Icons.playlist_add_check, size: 18),
                    style: _summaryIconButtonStyle(false),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton.outlined(
                    tooltip: boxSelectionEnabled ? '退出框选' : '框选点位',
                    isSelected: boxSelectionEnabled,
                    onPressed: isImporting ? null : onToggleBoxSelection,
                    icon: const Icon(Icons.select_all_outlined, size: 18),
                    selectedIcon: const Icon(Icons.select_all, size: 18),
                    style: _summaryIconButtonStyle(boxSelectionEnabled),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: FilledButton.icon(
                      onPressed:
                          isImporting ||
                              !boxSelectionEnabled ||
                              selectedBoxCount == 0
                          ? null
                          : onImportSelection,
                      icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      label: Text(
                        selectedBoxCount == 0
                            ? '添加框选'
                            : '添加 $selectedBoxCount 个',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  ButtonStyle _summaryIconButtonStyle(bool selected) {
    return IconButton.styleFrom(
      backgroundColor: selected
          ? AppColors.accent.withValues(alpha: 0.12)
          : AppColors.surface,
      foregroundColor: selected ? AppColors.accentDark : AppColors.textPrimary,
      disabledBackgroundColor: AppColors.surfaceMuted,
      disabledForegroundColor: AppColors.textSecondary,
      fixedSize: const Size.square(36),
      minimumSize: const Size.square(36),
      padding: EdgeInsets.zero,
      side: BorderSide(
        color: selected ? AppColors.accent : AppColors.border,
        width: selected ? 2 : 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _SelectionRectPainter extends CustomPainter {
  const _SelectionRectPainter(this.rect);

  final Rect? rect;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = this.rect;
    if (rect == null) {
      return;
    }

    final normalized = Rect.fromLTRB(
      math.min(rect.left, rect.right),
      math.min(rect.top, rect.bottom),
      math.max(rect.left, rect.right),
      math.max(rect.top, rect.bottom),
    );
    final fillPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(normalized, fillPaint);
    canvas.drawRect(normalized, strokePaint);
  }

  @override
  bool shouldRepaint(_SelectionRectPainter oldDelegate) {
    return oldDelegate.rect != rect;
  }
}

class _AnitabiPointCard extends StatelessWidget {
  const _AnitabiPointCard({
    required this.point,
    required this.importedPoint,
    required this.imported,
    required this.isImporting,
    required this.onImport,
  });

  final AnitabiPoint point;
  final PilgrimagePoint? importedPoint;
  final bool imported;
  final bool isImporting;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final imageUrl = _anitabiThumbnailUrl(point.referenceImageUrl);
    final fullImageUrl = anitabiFullResolutionImageUrl(point.referenceImageUrl);
    final localThumbnailPath = importedPoint?.referenceThumbnailPath;
    final localFullPath = importedPoint?.referenceFullImagePath;
    void openFullImage() {
      if (fullImageUrl == null) {
        return;
      }
      ImageViewerScreen.show(
        context,
        filePath: localFullPath,
        imageUrl: fullImageUrl,
      );
    }

    void openDetail() {
      _AnitabiPointDetailSheet.show(
        context,
        point: point,
        imageUrl: imageUrl,
        fullImageUrl: fullImageUrl,
        localThumbnailPath: localThumbnailPath,
        localFullPath: localFullPath,
        imported: imported,
        isImporting: isImporting,
        onImport: onImport,
      );
    }

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Material(
              color: AppColors.surfaceMuted,
              child: InkWell(
                onTap: fullImageUrl == null ? null : openFullImage,
                child: SizedBox(
                  width: 86,
                  height: 86,
                  child: ReferenceThumbnail(
                    localPath: localThumbnailPath,
                    imageUrl: imageUrl,
                    placeholder: const Icon(Icons.image_outlined),
                  ),
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
                CopyableText(
                  text: point.name,
                  copyLabel: '点位名称',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                CopyableText(
                  text: '${point.subtitle} / ${point.episodeLabel}',
                  copyText: _copySummary,
                  copyLabel: '点位信息',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                CopyableText(
                  text: point.origin,
                  copyLabel: '来源',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed: openDetail,
                        icon: const Icon(Icons.image_outlined, size: 17),
                        label: const Text('详情'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: FilledButton.icon(
                          onPressed: imported || isImporting ? null : onImport,
                          icon: Icon(
                            imported
                                ? Icons.check
                                : Icons.add_location_alt_outlined,
                            size: 18,
                          ),
                          label: Text(imported ? '已加入' : '加入计划'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                        ),
                      ),
                    ),
                  ],
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

class _AnitabiPointDetailSheet extends StatelessWidget {
  const _AnitabiPointDetailSheet({
    required this.point,
    required this.imageUrl,
    required this.fullImageUrl,
    required this.localThumbnailPath,
    required this.localFullPath,
    required this.imported,
    required this.isImporting,
    required this.onImport,
  });

  final AnitabiPoint point;
  final String? imageUrl;
  final String? fullImageUrl;
  final String? localThumbnailPath;
  final String? localFullPath;
  final bool imported;
  final bool isImporting;
  final VoidCallback onImport;

  static Future<void> show(
    BuildContext context, {
    required AnitabiPoint point,
    required String? imageUrl,
    required String? fullImageUrl,
    required String? localThumbnailPath,
    required String? localFullPath,
    required bool imported,
    required bool isImporting,
    required VoidCallback onImport,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => _AnitabiPointDetailSheet(
        point: point,
        imageUrl: imageUrl,
        fullImageUrl: fullImageUrl,
        localThumbnailPath: localThumbnailPath,
        localFullPath: localFullPath,
        imported: imported,
        isImporting: isImporting,
        onImport: onImport,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                                filePath: localFullPath,
                                imageUrl: fullImageUrl,
                              ),
                        child: SizedBox(
                          width: 112,
                          height: 112,
                          child: ReferenceThumbnail(
                            localPath: localThumbnailPath,
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: const Icon(Icons.image_outlined),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CopyableText(
                          text: point.name,
                          copyLabel: '点位名称',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _AnitabiDetailInfoLine(
                          icon: Icons.local_movies_outlined,
                          label: '场景',
                          value: '${point.subtitle} / ${point.episodeLabel}',
                        ),
                        const SizedBox(height: 6),
                        _AnitabiDetailInfoLine(
                          icon: Icons.source_outlined,
                          label: '来源',
                          value: point.origin,
                        ),
                        const SizedBox(height: 6),
                        _AnitabiDetailInfoLine(
                          icon: Icons.location_on_outlined,
                          label: '坐标',
                          value:
                              '${point.position.latitude.toStringAsFixed(5)}, ${point.position.longitude.toStringAsFixed(5)}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton.icon(
                  onPressed: imported || isImporting
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          onImport();
                        },
                  icon: Icon(
                    imported ? Icons.check : Icons.add_location_alt_outlined,
                    size: 18,
                  ),
                  label: Text(imported ? '已加入计划' : '加入计划'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnitabiDetailInfoLine extends StatelessWidget {
  const _AnitabiDetailInfoLine({
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
        Icon(icon, color: AppColors.textSecondary, size: 18),
        const SizedBox(width: 8),
        SizedBox(
          width: 38,
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

class _NoPointSelectedCard extends StatelessWidget {
  const _NoPointSelectedCard({
    required this.hasPoints,
    required this.expectedCount,
  });

  final bool hasPoints;
  final int? expectedCount;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final message = hasPoints
        ? '点击地图上的点位查看缩略图和详情。'
        : expectedCount == null || expectedCount == 0
        ? '当前作品没有可导入的 Anitabi 点位。'
        : '当前作品共有 $expectedCount 个点位，但没有可导入的带图参考点位。';

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
              message,
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
  const _ImportErrorState({
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  final String message;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, color: AppColors.textSecondary, size: 32),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重新加载 Anitabi 点位'),
            ),
          ],
        ),
      ),
    );
  }
}
