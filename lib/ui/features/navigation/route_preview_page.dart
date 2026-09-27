import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/navigation/route_planner.dart';
import '../../../application/plan_session.dart';
import '../../../application/settings_store.dart';
import '../../../map/map_navigation_launcher.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../../plan/plan_group_utils.dart';
import '../../app/router.dart';
import '../../app/toast.dart';
import '../../components/components.dart';
import '../../map/map.dart';
import 'navigation_entry.dart';
import 'navigation_services.dart';

/// 确认路线 (DESIGN §8.4): the walking route for a point (or its whole
/// group), then in-app navigation or an external map as fallback.
class RoutePreviewPage extends StatefulWidget {
  const RoutePreviewPage({required this.pointId, super.key});

  final String pointId;

  @override
  State<RoutePreviewPage> createState() => _RoutePreviewPageState();
}

class _RoutePreviewPageState extends State<RoutePreviewPage> {
  RoutePlanner? _planner;
  final PlanMapController _map = PlanMapController();
  List<LatLng> _fittedPoints = const [];
  bool _starting = false;
  bool _initialized = false;
  bool _pointMissing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final session = context.read<PlanSession?>();
    final point = session != null && session.isReady
        ? session.controller.pointById(widget.pointId)
        : null;
    if (point == null || session == null) {
      _pointMissing = true;
      return;
    }
    final services = NavigationServices.maybeOf(context);
    final settings =
        context.read<SettingsStore?>()?.settings ?? const AppSettings();
    final planner = RoutePlanner.forPoint(
      point: point,
      settings: settings,
      buckets: planGroupBuckets(
        session.controller.plan,
        session.controller.completedPointIds,
      ),
      routeClient: services?.routeClient,
      locationResolver: services?.locationResolver,
      externalNavigationLauncher:
          services?.externalNavigationLauncher ?? const MapNavigationLauncher(),
    )..addListener(_changed);
    _planner = planner;
    unawaited(planner.start());
  }

  @override
  void dispose() {
    _planner
      ?..removeListener(_changed)
      ..dispose();
    _map.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    final points = _planner?.routePoints ?? const <LatLng>[];
    if (points.isNotEmpty && !_samePoints(points, _fittedPoints)) {
      _fittedPoints = points;
      // The route (and the start position) usually arrives after the first
      // build; initial fitting only applies once.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_map.isReady) return;
        unawaited(
          _map.fitPoints(
            points,
            padding: const EdgeInsets.fromLTRB(40, 28, 40, 28),
            maxZoom: 17,
          ),
        );
      });
    }
  }

  static bool _samePoints(List<LatLng> a, List<LatLng> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _start({required bool chainZone}) async {
    final planner = _planner;
    if (planner == null || _starting) return;
    setState(() => _starting = true);
    final args = await planner.startNavigation(chainZone: chainZone);
    if (!mounted) return;
    setState(() => _starting = false);
    if (args == null) return;
    context.pushReplacement(Routes.navigate, extra: args);
  }

  Future<void> _openExternal() async {
    final planner = _planner;
    if (planner == null) return;
    final opened = await planner.openExternalNavigation();
    if (!opened && mounted) {
      context.showToast('无法打开外部地图', kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final planner = _planner;
    return MiriaPageScaffold(
      key: const ValueKey('navigation-route-confirm-screen'),
      title: '确认路线',
      leading: navigationRouteLeading(context),
      body: planner == null
          ? (_pointMissing
                ? const EmptyState(
                    icon: Symbols.location_off_rounded,
                    title: '找不到这个点位',
                    message: '它可能已被删除或不在当前计划中。',
                  )
                : const Center(child: ProgressRing()))
          : _buildBody(context, planner),
    );
  }

  Widget _buildBody(BuildContext context, RoutePlanner planner) {
    final layout = context.layout;
    final side = layout.usesSidePanel;
    final map = _RoutePreviewMap(
      controller: _map,
      planner: planner,
      disableTiles:
          NavigationServices.maybeOf(context)?.disableMapTiles ?? false,
    );
    final panel = _RoutePanel(
      planner: planner,
      starting: _starting,
      onStart: (chainZone) => unawaited(_start(chainZone: chainZone)),
      onRetry: () => unawaited(planner.retry()),
      onExternal: () => unawaited(_openExternal()),
    );
    final c = context.colors;
    if (side) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: map),
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(left: BorderSide(color: c.hairline)),
            ),
            child: SizedBox(
              width: layout.isShort ? kMapSidePanelShortWidth : 380,
              child: SafeArea(
                left: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(Space.x5),
                  child: panel,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Expanded(child: map),
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: Radii.sheetTop,
            boxShadow: Elevations.level2(c),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: layout.height * 0.6),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  layout.gutter + Space.x1,
                  Space.x4,
                  layout.gutter + Space.x1,
                  Space.x4,
                ),
                child: panel,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoutePreviewMap extends StatelessWidget {
  const _RoutePreviewMap({
    required this.controller,
    required this.planner,
    required this.disableTiles,
  });

  final PlanMapController controller;
  final RoutePlanner planner;
  final bool disableTiles;

  @override
  Widget build(BuildContext context) {
    final points = planner.routePoints;
    final stops = planner.remainingStops;
    final point = planner.point;
    return PlanMap(
      controller: controller,
      initialFitPoints: points.length >= 2 ? points : null,
      initialFitPadding: const EdgeInsets.fromLTRB(40, 28, 40, 28),
      initialFitMaxZoom: 17,
      initialCenter: point.hasCoordinate ? point.position : null,
      allowRotation: true,
      disableTiles: disableTiles,
      layers: [
        RouteLayer(
          route: points,
          stops: [for (final stop in stops) stop.position],
          stopNames: [for (final stop in stops) stop.name],
        ),
      ],
    );
  }
}

class _RoutePanel extends StatelessWidget {
  const _RoutePanel({
    required this.planner,
    required this.starting,
    required this.onStart,
    required this.onRetry,
    required this.onExternal,
  });

  final RoutePlanner planner;
  final bool starting;
  final ValueChanged<bool> onStart;
  final VoidCallback onRetry;
  final VoidCallback onExternal;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final groupName = planner.groupName?.trim() ?? '';
    final app = planner.settings.navigationApp;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (groupName.isNotEmpty) ...[
          Row(
            children: [
              const Tag(label: '片区', tone: MiriaTone.primary),
              const SizedBox(width: Space.x2),
              Expanded(
                child: Text(
                  groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.x3),
        ],
        Text(planner.title, style: context.text.titleLarge),
        const SizedBox(height: Space.x1),
        Text(
          planner.subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          locale: MiriaFonts.japanese,
          style: context.text.bodyMedium?.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: Space.x4),
        switch (planner.status) {
          RoutePlannerStatus.loading => Column(
            key: const ValueKey('navigation-route-loading'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: Radii.pillAll,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: c.primary,
                  backgroundColor: c.surfaceMuted,
                ),
              ),
              const SizedBox(height: Space.x2),
              Text(
                '正在获取当前位置并规划步行路线…',
                style: context.text.bodyMedium?.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
          RoutePlannerStatus.error => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                planner.errorMessage,
                style: context.text.bodyMedium?.copyWith(color: c.danger),
              ),
              const SizedBox(height: Space.x3),
              Row(
                children: [
                  Expanded(
                    child: MiriaButton.secondary(
                      key: const ValueKey('navigation-route-retry'),
                      label: '重试',
                      icon: Symbols.refresh_rounded,
                      semanticLabel: '重新规划路线',
                      expand: true,
                      onPressed: onRetry,
                    ),
                  ),
                  const SizedBox(width: Space.x2),
                  Expanded(
                    child: MiriaButton.secondary(
                      key: const ValueKey('navigation-route-external-fallback'),
                      label: app.label,
                      shortLabel: '外部导航',
                      icon: Symbols.open_in_new_rounded,
                      semanticLabel: '使用 ${app.label} 导航',
                      expand: true,
                      onPressed: onExternal,
                    ),
                  ),
                ],
              ),
            ],
          ),
          RoutePlannerStatus.ready =>
            planner.canChainZone
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MiriaButton(
                        key: const ValueKey('navigation-route-confirm-zone'),
                        label: '串联整个片区导航',
                        shortLabel: '开始导航',
                        icon: Symbols.route_rounded,
                        size: MiriaButtonSize.lg,
                        expand: true,
                        loading: starting,
                        onPressed: starting ? null : () => onStart(true),
                      ),
                      const SizedBox(height: Space.x2),
                      MiriaButton.secondary(
                        key: const ValueKey('navigation-route-confirm-point'),
                        label: '仅导航到选中点',
                        shortLabel: '仅导航到点位',
                        icon: Symbols.location_on_rounded,
                        size: MiriaButtonSize.lg,
                        expand: true,
                        onPressed: starting ? null : () => onStart(false),
                      ),
                    ],
                  )
                : MiriaButton(
                    key: const ValueKey('navigation-route-confirm-point'),
                    label: '开始导航',
                    icon: Symbols.navigation_rounded,
                    size: MiriaButtonSize.lg,
                    expand: true,
                    loading: starting,
                    onPressed: starting ? null : () => onStart(false),
                  ),
        },
      ],
    );
  }
}
