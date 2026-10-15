import 'dart:async';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/pilgrimage_repository.dart';
import '../data/reference_cache_cleanup.dart';
import '../plan/pilgrimage_models.dart';
import '../widgets/app_back_button.dart';
import '../widgets/confirm_action_dialog.dart';
import '../widgets/snackbar_helper.dart';

class ReferenceCacheCleanupPage extends StatefulWidget {
  const ReferenceCacheCleanupPage({required this.repository, super.key});

  final PilgrimageRepository repository;

  @override
  State<ReferenceCacheCleanupPage> createState() =>
      _ReferenceCacheCleanupPageState();
}

class _ReferenceCacheCleanupPageState extends State<ReferenceCacheCleanupPage> {
  /// Nothing is selected at first: cleaning deletes files, so the user
  /// chooses what to include.
  final _selectedPlanIds = <String>{};

  /// Cache size per plan, filled in the background after the list shows.
  final _planBytes = <String, int>{};

  /// File size reads of this load, finished or not; selection changes reuse
  /// them. A new map per load, so a read from before a cleanup cannot land
  /// in it.
  var _fileSizes = <String, Future<int>>{};
  late Future<List<PilgrimagePlan>> _plansFuture;
  Future<ReferenceCacheUsage?>? _usage;
  Future<ReferenceCacheScan>? _selectionScan;
  List<PilgrimagePlan> _plans = [];
  var _loading = true;
  var _busy = false;
  var _completed = 0;
  var _total = 0;
  var _loadGeneration = 0;

  Color get _accent => AppColors.accent;
  Color get _secondary => AppColors.textSecondary;

  @override
  void initState() {
    super.initState();
    _plansFuture = _loadPlans();
  }

  Future<List<PilgrimagePlan>> _loadPlans() async {
    final generation = ++_loadGeneration;
    final plans = await widget.repository.loadPlans();
    if (!mounted) return plans;
    // After a cleanup the files on disk changed; read sizes and usage again.
    _fileSizes = {};
    final usage = _loadUsage();
    setState(() {
      _plans = plans;
      _planBytes.clear();
      final ids = plans.map((plan) => plan.id).toSet();
      _selectedPlanIds.removeWhere((id) => !ids.contains(id));
      _loading = false;
      _usage = usage;
      _selectionScan = _startSelectionScan();
    });
    unawaited(_measurePlans(plans, generation));
    return plans;
  }

  /// Fills in each plan's cache size without holding up the list.
  Future<void> _measurePlans(List<PilgrimagePlan> plans, int generation) async {
    for (final plan in plans) {
      final scan = await scanDownloadedReferenceCaches([
        plan,
      ], sizeCache: _fileSizes);
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _planBytes[plan.id] = scan.byteCount);
    }
  }

  /// Which plans and records use each cache file; null when it could not be
  /// read. Nothing may be waiting for it yet (nothing is selected at first),
  /// so it never fails itself: the selection scan reports the failure.
  Future<ReferenceCacheUsage?> _loadUsage() async {
    try {
      return await loadReferenceCacheUsage(widget.repository);
    } on Object catch (error) {
      debugPrint('Reading reference cache usage failed: $error');
      return null;
    }
  }

  /// The footer's FutureBuilder only listens from the next frame, and a scan
  /// can fail before that; a handler is attached at once so the failure is
  /// not reported as unhandled. The footer still shows it.
  Future<ReferenceCacheScan> _startSelectionScan() {
    final scan = _scanSelection();
    unawaited(scan.then((_) {}, onError: (Object _) {}));
    return scan;
  }

  Future<ReferenceCacheScan> _scanSelection() async {
    final selected = _plans
        .where((plan) => _selectedPlanIds.contains(plan.id))
        .toList();
    if (selected.isEmpty) {
      return const ReferenceCacheScan(fileCount: 0, byteCount: 0, paths: {});
    }
    final pending = _usage ??= _loadUsage();
    final usage = await pending;
    if (usage == null) {
      // Read it again on the next change or retry.
      if (identical(_usage, pending)) _usage = null;
      throw StateError('Reference cache usage could not be read.');
    }
    return scanDownloadedReferenceCaches(
      selected,
      retainedPaths: usage.retainedFor(selected.map((plan) => plan.id)),
      sizeCache: _fileSizes,
    );
  }

  void _select(void Function() change) {
    setState(() {
      change();
      _selectionScan = _startSelectionScan();
    });
  }

  TextStyle _text(double size, {bool bold = false, bool secondary = false}) =>
      TextStyle(
        fontSize: size,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        color: secondary ? _secondary : AppColors.textPrimary,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 56,
        titleSpacing: 0,
        leading: const AppBackButton(),
        title: Text('清理参考图缓存', style: _text(20, bold: true)),
      ),
      body: FutureBuilder<List<PilgrimagePlan>>(
        future: _plansFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('计划列表或缓存大小读取失败'),
                  TextButton(
                    onPressed: () => setState(() {
                      _loading = true;
                      _plansFuture = _loadPlans();
                    }),
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }
          final plans = snapshot.data!;
          final allSelected =
              plans.isNotEmpty && _selectedPlanIds.length == plans.length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Material(
                color: AppColors.surface,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.65),
                  ),
                ),
                child: Column(
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                16,
                                12,
                                14,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('选择计划', style: _text(18, bold: true)),
                                  Text(
                                    '已选 ${_selectedPlanIds.length} 个，共 ${plans.length} 个',
                                    style: _text(14, secondary: true),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _busy || plans.isEmpty
                                ? null
                                : () => _select(() {
                                    _selectedPlanIds.clear();
                                    if (!allSelected) {
                                      _selectedPlanIds.addAll(
                                        plans.map((plan) => plan.id),
                                      );
                                    }
                                  }),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.accentForeground,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: const RoundedRectangleBorder(),
                            ),
                            child: Text(
                              allSelected ? '取消全选' : '全选',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (plans.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('暂无计划', style: _text(14, secondary: true)),
                      ),
                    for (final plan in plans) ...[
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.border.withValues(alpha: 0.65),
                      ),
                      _planRow(plan),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.border.withValues(alpha: 0.65)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: FutureBuilder<ReferenceCacheScan>(
              future: _selectionScan,
              builder: (context, snapshot) {
                final ready =
                    !_loading &&
                    snapshot.connectionState == ConnectionState.done &&
                    !snapshot.hasError &&
                    snapshot.hasData;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '已选 ${_selectedPlanIds.length} 个计划',
                            style: _text(14),
                          ),
                        ),
                        Text(
                          snapshot.hasError ? '空间计算失败' : '可释放约 ',
                          style: _text(14),
                        ),
                        if (snapshot.hasError)
                          TextButton(
                            key: const ValueKey('cache-cleanup-retry'),
                            onPressed: _busy ? null : () => _select(() {}),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.accentForeground,
                            ),
                            child: const Text('重试'),
                          ),
                        if (!snapshot.hasError)
                          Text(
                            ready
                                ? _formatByteSize(snapshot.data!.byteCount)
                                : '…',
                            style: _text(18, bold: true),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '仅清理完整参考图，保留缩略图。\n再次查看完整图片需重新下载。',
                      style: _text(14, secondary: true).copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: AppColors.onAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: !ready || _selectedPlanIds.isEmpty || _busy
                            ? null
                            : () => _confirmAndClean(
                                _plans.where(
                                  (plan) => _selectedPlanIds.contains(plan.id),
                                ),
                              ),
                        child: Text(
                          _busy
                              ? (_total > 0
                                    ? '正在清理 $_completed / $_total'
                                    : '正在扫描…')
                              : '清理缓存',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _planRow(PilgrimagePlan plan) {
    final selected = _selectedPlanIds.contains(plan.id);
    void toggle() => _select(() {
      if (selected) {
        _selectedPlanIds.remove(plan.id);
      } else {
        _selectedPlanIds.add(plan.id);
      }
    });
    return InkWell(
      onTap: _busy ? null : toggle,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 80),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 24,
                child: Transform.scale(
                  scale: 4 / 3,
                  child: Checkbox(
                    value: selected,
                    onChanged: _busy ? null : (_) => toggle(),
                    activeColor: _accent,
                    checkColor: AppColors.onAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(width: 26),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(plan.name, style: _text(16, bold: true)),
                          Text(
                            '${plan.area} · ${plan.points.length} 个点位',
                            style: _text(14, secondary: true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // The plan's downloaded full-size references (what
                    // cleaning removes; thumbnails stay). Files shared with
                    // other plans count here but are only freed when all
                    // their plans are cleaned (the total below).
                    Text('完整图 ', style: _text(13, secondary: true)),
                    Text(
                      _planBytes.containsKey(plan.id)
                          ? _formatByteSize(_planBytes[plan.id]!)
                          : '…',
                      style: _text(16, bold: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndClean(Iterable<PilgrimagePlan> selected) async {
    setState(() => _busy = true);
    final plans = selected.toList(growable: false);
    late ReferenceCacheScan scan;
    try {
      scan = await scanDownloadedReferenceCaches(
        plans,
        retainedPaths: await referenceCachePathsInUseElsewhere(
          repository: widget.repository,
          planIds: plans.map((plan) => plan.id),
        ),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showStatusSnack(
          kind: AppStatusBannerKind.error,
          title: '缓存扫描失败',
          subtitle: error.toString(),
        );
      }
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (scan.fileCount == 0) {
      ScaffoldMessenger.of(context).showStatusSnack(
        kind: AppStatusBannerKind.success,
        title: '所选计划没有可清理的下载缓存',
      );
      return;
    }
    final confirmed = await showConfirmActionDialog(
      context,
      title: '清理参考图缓存？',
      message:
          '将删除 ${scan.fileCount} 个完整参考图缓存，约 ${_formatByteSize(scan.byteCount)}。',
      notice: '保留缩略图、本地上传图片和计划包导入图片。完整参考图可重新下载。',
      emphasizedValues: ['${scan.fileCount}', _formatByteSize(scan.byteCount)],
      confirmLabel: '清理缓存',
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _completed = 0;
      _total = scan.paths.length;
    });
    try {
      final result = await cleanupDownloadedReferenceCaches(
        repository: widget.repository,
        plans: plans,
        onProgress: (completed, total) {
          if (!mounted) return;
          setState(() {
            _completed = completed;
            _total = total;
          });
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showStatusSnack(
        kind: result.failedFileCount == 0
            ? AppStatusBannerKind.success
            : AppStatusBannerKind.warning,
        title: '已清理 ${result.deletedFileCount} 个缓存文件',
        subtitle: result.failedFileCount == 0
            ? '释放 ${_formatByteSize(result.reclaimedBytes)}'
            : '${result.failedFileCount} 个文件清理失败',
      );
      setState(() {
        _loading = true;
        _plansFuture = _loadPlans();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _completed = 0;
          _total = 0;
        });
      }
    }
  }
}

String _formatByteSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final units = ['KB', 'MB', 'GB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final number = value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  return '$number ${units[unit]}';
}
