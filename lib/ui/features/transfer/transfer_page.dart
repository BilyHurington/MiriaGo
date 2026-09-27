import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/plan_session.dart';
import '../../../application/plans_store.dart';
import '../../../application/platform_capabilities.dart';
import '../../../application/transfer/plan_transfer_service.dart';
import '../../../data/pilgrimage_repository.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../../plan_transfer/plan_export_v2.dart';
import '../../app/router.dart';
import '../../components/components.dart';
import '../plan/plan_workspace.dart';
import 'import_preview_page.dart';
import 'transfer_notice_toast.dart';

/// 导入导出 (`/plan/transfer`, DESIGN §8.14): import a package, export the
/// MiriaGo data package or a Google My Maps CSV.
///
/// Exports the active plan unless the route names another one with
/// `?plan=<id>` (plan 「⋯」 → 导入导出 on a non-active plan, like the old
/// `ImportExportScreen(plan: plan)`); that never switches the active plan.
class TransferPage extends StatefulWidget {
  const TransferPage({this.backend, this.planId, super.key});

  /// Overridable for tests.
  final PlanTransferBackend? backend;

  /// Plan to export; defaults to `?plan=` of the current route, then to the
  /// active plan.
  final String? planId;

  /// Location of the page exporting [planId].
  static String locationFor(String planId) =>
      Uri(path: Routes.transfer, queryParameters: {'plan': planId}).toString();

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  late final PlanTransferController _controller = PlanTransferController(
    repository: context.read<PilgrimageRepository>(),
    backend: widget.backend ?? const PlanTransferBackend(),
    onNotice: (notice) {
      if (mounted) context.showTransferNotice(notice);
    },
  );
  String? _estimatedPlanKey;
  PlanWorkspaceScope? _workspace;

  /// Plan requested through [TransferPage.planId] / `?plan=`.
  String? _requestedPlanId;
  bool _requestedPlanResolved = false;

  /// The requested plan when it is not the active one (read from the
  /// repository; the active plan always comes from the session).
  PilgrimagePlan? _requestedPlan;
  Object? _requestedPlanError;
  int _requestedPlanGeneration = 0;

  /// Leaving through the plan secondary navigation cancels a running export
  /// just like the back button. Once the export is being delivered it can't
  /// be cancelled, so the page stays.
  Future<bool> _leaveGuard() async {
    if (_controller.delivering) return false;
    _controller.cancelExport();
    return true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final workspace = PlanWorkspaceScope.maybeOf(context);
    if (!identical(workspace, _workspace)) {
      _workspace?.removeLeaveGuard(_leaveGuard);
      _workspace = workspace?..addLeaveGuard(_leaveGuard);
    }
    final planId = widget.planId ?? _routePlanId();
    if (!_requestedPlanResolved || planId != _requestedPlanId) {
      _requestedPlanResolved = true;
      _requestedPlanId = planId;
      _requestedPlan = null;
      _requestedPlanError = null;
      _requestedPlanGeneration++;
      if (planId != null) unawaited(_loadRequestedPlan(planId));
    }
  }

  String? _routePlanId() {
    try {
      final id = GoRouterState.of(context).uri.queryParameters['plan'];
      return id == null || id.trim().isEmpty ? null : id;
    } on GoError {
      return null;
    }
  }

  Future<void> _loadRequestedPlan(String planId) async {
    final generation = ++_requestedPlanGeneration;
    if (_requestedPlanError != null) {
      setState(() => _requestedPlanError = null);
    }
    final repository = context.read<PilgrimageRepository>();
    try {
      final plans = await repository.loadPlans();
      final plan = plans.where((plan) => plan.id == planId).firstOrNull;
      if (!mounted || generation != _requestedPlanGeneration) return;
      setState(() {
        _requestedPlan = plan;
        _requestedPlanError = plan == null
            ? StateError('Plan $planId not found')
            : null;
      });
    } catch (error) {
      debugPrint('Failed to load plan $planId for export: $error');
      if (!mounted || generation != _requestedPlanGeneration) return;
      setState(() => _requestedPlanError = error);
    }
  }

  @override
  void dispose() {
    _workspace?.removeLeaveGuard(_leaveGuard);
    _controller.dispose();
    super.dispose();
  }

  /// Whether the requested plan is the active one (or none was requested).
  bool _exportsActivePlan(PlanSession session) {
    final requested = _requestedPlanId;
    return requested == null ||
        (session.isReady && session.plan.id == requested);
  }

  /// Re-estimates when the exported plan (or its content) changes.
  void _ensureEstimate(PilgrimagePlan plan, String key) {
    if (key == _estimatedPlanKey) return;
    _estimatedPlanKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_controller.refreshSizeEstimate(plan));
    });
  }

  void _handleBack() {
    // A delivered export (share sheet / save dialog / file write) can't be
    // cancelled any more: ignore back until it finishes.
    if (_controller.delivering) return;
    _controller.cancelExport();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.plan);
    }
  }

  Future<void> _import() async {
    final capabilities = context.read<PlatformCapabilities>();
    if (capabilities.planImportMode == PlanImportMode.openInFromOtherApp) {
      await _showIosImportHelp();
      return;
    }
    final package = await _controller.pickImportPackage();
    if (package == null || !mounted) return;
    final imported = await openImportPreview(context, package);
    if (!imported || !mounted) return;
    final session = context.read<PlanSession>();
    final plans = context.read<PlansStore>();
    final router = GoRouter.of(context);
    await session.load();
    await plans.refresh();
    router.go(Routes.plan);
  }

  Future<void> _showIosImportHelp() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => MiriaDialog(
        title: IosImportHelpCopy.title,
        content: Text(
          IosImportHelpCopy.message,
          style: dialogContext.text.bodyMedium,
        ),
        actions: MiriaButton(
          label: IosImportHelpCopy.confirmLabel,
          expand: true,
          autofocus: true,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    );
  }

  Future<void> _exportPackage(PilgrimagePlan plan) {
    return _controller.exportPackage(
      plan,
      confirmMissingAssets: (messages) => showConfirmDialog(
        context,
        title: '部分本地资源缺失',
        message: messages.join('\n'),
        confirmLabel: '继续导出',
        notice: '缺失资源不会进入数据包，导入后对应图片可能无法显示',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PlanSession>();
    final capabilities = context.read<PlatformCapabilities>();
    final PilgrimagePlan? plan;
    final Object? loadError;
    final VoidCallback retry;
    if (_exportsActivePlan(session)) {
      plan = session.isReady ? session.plan : null;
      loadError = session.loadError;
      retry = () => unawaited(session.load());
      if (plan != null) _ensureEstimate(plan, '${plan.id}:${session.revision}');
    } else {
      plan = _requestedPlan;
      loadError = _requestedPlanError;
      retry = () => unawaited(_loadRequestedPlan(_requestedPlanId!));
      if (plan != null) _ensureEstimate(plan, '${plan.id}:requested');
    }
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final exporting = _controller.exporting;
        return PopScope(
          canPop: !exporting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _handleBack();
          },
          child: MiriaPageScaffold(
            title: '导入导出',
            automaticallyImplyLeading: !PlanWorkspaceScope.hasSecondaryNav(
              context,
            ),
            slivers: [
              SliverContentColumn(
                top: Space.x2,
                sliver: SliverToBoxAdapter(
                  child: plan != null
                      ? _content(context, plan, capabilities)
                      : loadError != null
                      ? ErrorState(
                          key: const ValueKey('transfer-load-error'),
                          title: '计划加载失败',
                          detail: kDebugMode ? '请稍后重试。\n$loadError' : '请稍后重试。',
                          onRetry: retry,
                        )
                      : const _LoadingPlaceholder(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _content(
    BuildContext context,
    PilgrimagePlan plan,
    PlatformCapabilities capabilities,
  ) {
    final iosImport =
        capabilities.planImportMode == PlanImportMode.openInFromOtherApp;
    final busy = _controller.busy;
    final importing = _controller.importing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PlanSummary(plan: plan),
        const SizedBox(height: Space.x5),
        _SectionTitle(
          icon: Symbols.download_rounded,
          title: '导入',
          subtitle: iosImport
              ? '从文件、聊天、浏览器或网盘等位置用 MiriaGo 打开 .sjhplan。'
              : '选择 .sjhplan 文件，先预览内容再导入。',
        ),
        const SizedBox(height: Space.x2 + 2),
        _ActionCard(
          key: const ValueKey('transfer-import'),
          icon: importing
              ? Symbols.hourglass_empty_rounded
              : iosImport
              ? Symbols.open_in_new_rounded
              : Symbols.file_open_rounded,
          title: importing
              ? '读取中...'
              : iosImport
              ? '从其他 App 打开 .sjhplan'
              : '导入 MiriaGo 文件',
          subtitle: iosImport
              ? '在文件、聊天、浏览器下载页或网盘中选择 .sjhplan，然后分享或用 MiriaGo 打开。'
              : '支持 v2 数据包和旧版 v1 JSON 计划包。',
          loading: importing,
          enabled: !busy,
          onTap: _import,
        ),
        const SizedBox(height: Space.x6),
        const _SectionTitle(
          icon: Symbols.inventory_2_rounded,
          title: 'MiriaGo 数据包',
          subtitle: '新版 .sjhplan，内部为 zip，包含 manifest.json。',
        ),
        const SizedBox(height: Space.x2 + 2),
        _PackageOptions(
          controller: _controller,
          plan: plan,
          onExport: () => _exportPackage(plan),
          onCancel: _controller.cancelExport,
        ),
        const SizedBox(height: Space.x6),
        const _SectionTitle(
          icon: Symbols.map_rounded,
          title: 'Google My Maps',
          subtitle: '导出点位 CSV。图片写成链接，可按 Type 列设置样式。',
        ),
        const SizedBox(height: Space.x2 + 2),
        _ActionCard(
          key: const ValueKey('transfer-my-maps'),
          icon: _controller.exporting
              ? Symbols.hourglass_empty_rounded
              : Symbols.table_view_rounded,
          title: '导出 My Maps CSV',
          subtitle: '前 6 列贴近示例格式，作品、集数、来源等拆成独立列。',
          enabled: !busy,
          onTap: () => _controller.exportMyMapsCsv(plan),
        ),
        const SizedBox(height: Space.x6),
      ],
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      Skeleton.box(height: 72),
      SizedBox(height: Space.x4),
      Skeleton.box(height: 160),
    ],
  );
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.plan});

  final PilgrimagePlan plan;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return MiriaCard(
      padding: const EdgeInsets.all(Space.x3 + 2),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.primaryContainer,
              borderRadius: Radii.smAll,
            ),
            child: Icon(Symbols.archive_rounded, color: c.onPrimaryContainer),
          ),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${plan.groups.length} 个片区 / ${plan.points.length} 个点位',
                  style: text.bodySmall?.copyWith(
                    color: c.textSecondary,
                    fontFeatures: MiriaFonts.tabular,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return Semantics(
      header: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 20, color: c.primaryText),
          ),
          const SizedBox(width: Space.x2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: text.bodySmall?.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
    this.loading = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return MiriaCard(
      padding: EdgeInsets.zero,
      color: enabled ? null : c.surfaceMuted,
      child: ListRow(
        leading: loading
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, color: enabled ? c.primaryText : c.textDisabled),
        title: title,
        titleStyle: text.titleSmall?.copyWith(
          color: enabled ? c.textPrimary : c.textSecondary,
        ),
        subtitle: subtitle,
        subtitleMaxLines: 4,
        showChevron: true,
        enabled: enabled,
        borderRadius: Radii.mdAll,
        onTap: enabled ? onTap : null,
      ),
    );
  }
}

class _PackageOptions extends StatelessWidget {
  const _PackageOptions({
    required this.controller,
    required this.plan,
    required this.onExport,
    required this.onCancel,
  });

  final PlanTransferController controller;
  final PilgrimagePlan plan;
  final VoidCallback onExport;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final busy = controller.busy;
    final exporting = controller.exporting;
    return MiriaCard(
      padding: const EdgeInsets.all(Space.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedControl<PlanExportV2Mode>(
            key: const ValueKey('export-mode'),
            semanticLabel: '导出内容',
            collapseToIcons: false,
            options: const [
              SegmentOption(
                value: PlanExportV2Mode.planOnly,
                label: '纯计划',
                icon: Symbols.route_rounded,
              ),
              SegmentOption(
                value: PlanExportV2Mode.planWithRecords,
                label: '计划+记录',
                icon: Symbols.folder_copy_rounded,
              ),
            ],
            value: controller.mode,
            onChanged: busy ? null : (mode) => controller.setMode(mode, plan),
          ),
          const SizedBox(height: Space.x2),
          SwitchRow(
            key: const ValueKey('export-include-reference-cache'),
            padding: const EdgeInsets.symmetric(vertical: Space.x2),
            title: '包含完整参考图缓存',
            subtitle: '开启后才会把完整参考图写入数据包；默认仍会包含缩略图和用户自己添加的参考图。',
            value: controller.includeFullReferenceCache,
            onChanged: busy
                ? null
                : (value) =>
                      controller.setIncludeFullReferenceCache(value, plan),
          ),
          const SizedBox(height: Space.x1),
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (controller.estimatingSize)
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  Icon(
                    Symbols.inventory_2_rounded,
                    size: 18,
                    color: c.textSecondary,
                  ),
                const SizedBox(width: Space.x2),
                Expanded(
                  child: Text(
                    controller.sizeEstimateLabel,
                    key: const ValueKey('export-size-estimate'),
                    style: text.bodySmall?.copyWith(
                      color: c.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.x3),
          MiriaButton(
            key: const ValueKey('export-package-button'),
            label: exporting ? '导出中...' : '导出 MiriaGo 数据包',
            icon: Symbols.ios_share_rounded,
            loading: exporting,
            expand: true,
            onPressed: busy ? null : onExport,
          ),
          if (exporting) ...[
            const SizedBox(height: Space.x2),
            MiriaButton.ghost(
              key: const ValueKey('export-cancel-button'),
              label: '取消导出',
              icon: Symbols.close_rounded,
              expand: true,
              onPressed: controller.canCancelExport ? onCancel : null,
            ),
          ],
        ],
      ),
    );
  }
}
