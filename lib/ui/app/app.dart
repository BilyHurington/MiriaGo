import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart' show AppUiScaleView, appTextScaler;
import '../../application/app_services.dart';
import '../../application/plan_session.dart';
import '../../application/plans_store.dart';
import '../../application/platform_capabilities.dart';
import '../../application/reference_cache_task.dart';
import '../../application/settings_store.dart';
import '../../data/anitabi_image_source_scope.dart';
import '../../data/pilgrimage_repository.dart';
import '../../desktop/tauri_bridge.dart';
import '../../map/map_tile_config.dart';
import '../../plan_transfer/incoming_plan_file.dart';
import '../../plan_transfer/plan_import_file_stub.dart'
    if (dart.library.io) '../../plan_transfer/plan_import_file_io.dart';
import '../../plan/pilgrimage_models.dart';
import '../../plan_transfer/plan_import_package.dart';
import '../design/theme.dart';
import '../features/transfer/import_preview_page.dart';
import 'router.dart';
import 'toast.dart';

/// Startup: loads the repository, settings and the active plan, then shows
/// [MiriaGoApp]. Loading and failure states match the old bootstrap.
class MiriaGoBootstrap extends StatefulWidget {
  const MiriaGoBootstrap({
    this.repositoryLoader = StartupService.createDefaultRepository,
    this.initialLocation,
    super.key,
  });

  final RepositoryLoader repositoryLoader;

  /// Override the first route (tests / layout lab).
  final String? initialLocation;

  @override
  State<MiriaGoBootstrap> createState() => _MiriaGoBootstrapState();
}

class _MiriaGoBootstrapState extends State<MiriaGoBootstrap> {
  AppServices? _services;
  SettingsStore? _settings;
  PlanSession? _session;
  DesktopLauncherInfo? _launcherInfo;
  Object? _error;
  StackTrace? _stackTrace;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
      _stackTrace = null;
    });
    try {
      _launcherInfo = await StartupService.loadLauncherInfo();
      final repository = await widget.repositoryLoader();
      final settings = SettingsStore(repository: repository);
      await settings.load();
      final session = PlanSession(repository: repository);
      await session.load();
      StartupService.runStartupSideEffects(repository);
      if (!mounted) return;
      setState(() {
        _services = AppServices(
          repository: repository,
          capabilities: PlatformCapabilities.current(),
          launcherInfo: _launcherInfo,
        );
        _settings = settings;
        _session = session;
        _loading = false;
      });
    } catch (error, stackTrace) {
      unawaited(
        StartupService.writeDesktopError('startup failed', error, stackTrace),
      );
      if (!mounted) return;
      setState(() {
        _error = error;
        _stackTrace = stackTrace;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = _services;
    if (services != null) {
      return MiriaGoApp(
        services: services,
        settings: _settings!,
        session: _session!,
        initialLocation: widget.initialLocation,
      );
    }
    final colors = MiriaColors.light;
    return MaterialApp(
      title: 'MiriaGo',
      debugShowCheckedModeBanner: false,
      theme: buildMiriaTheme(colors),
      home: Scaffold(
        body: SafeArea(
          child: _loading
              ? const _StartupLoading()
              : _StartupError(
                  error: _error,
                  stackTrace: _stackTrace,
                  launcherInfo: _launcherInfo,
                  onRetry: _start,
                ),
        ),
      ),
    );
  }
}

class _StartupLoading extends StatefulWidget {
  const _StartupLoading();

  @override
  State<_StartupLoading> createState() => _StartupLoadingState();
}

class _StartupLoadingState extends State<_StartupLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: Radii.lgAll,
            child: Image.asset(
              'icon.jpg',
              width: 72,
              height: 72,
              cacheWidth: 216,
            ),
          ),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _dots,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ((_dots.value * 3).floor() % 3) >= i
                            ? c.spot
                            : c.hairlineStrong,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('正在加载 MiriaGo...', style: context.text.bodyMedium),
        ],
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({
    required this.error,
    required this.stackTrace,
    required this.launcherInfo,
    required this.onRetry,
  });

  final Object? error;
  final StackTrace? stackTrace;
  final DesktopLauncherInfo? launcherInfo;
  final Future<void> Function() onRetry;

  Future<void> _openDirectory(BuildContext context, String target) async {
    try {
      await openDesktopDirectory(target: target);
    } catch (openError) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法打开目录：$openError')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final details = [
      if (error != null) error.toString(),
      if (stackTrace != null) stackTrace.toString(),
    ].join('\n');
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.error_rounded, size: 52, color: c.danger),
              const SizedBox(height: 16),
              Text('MiriaGo 启动失败', style: context.text.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                '用户数据没有被删除。请重试，或打开日志目录查看 startup.log。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const ValueKey('desktop-startup-retry'),
                onPressed: onRetry,
                icon: const Icon(Symbols.refresh_rounded),
                label: const Text('重试'),
              ),
              if (launcherInfo != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _openDirectory(context, 'logs'),
                      icon: const Icon(Symbols.description_rounded),
                      label: const Text('打开日志目录'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openDirectory(context, 'data'),
                      icon: const Icon(Symbols.folder_open_rounded),
                      label: const Text('打开数据目录'),
                    ),
                  ],
                ),
              ],
              if (details.isNotEmpty) ...[
                const SizedBox(height: 20),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('错误详情'),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: c.surfaceMuted,
                      child: SelectionArea(
                        child: Text(details, style: context.text.bodySmall),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The running app: providers, theme, router, global overlays.
class MiriaGoApp extends StatefulWidget {
  const MiriaGoApp({
    required this.services,
    required this.settings,
    required this.session,
    this.initialLocation,
    super.key,
  });

  final AppServices services;
  final SettingsStore settings;
  final PlanSession session;
  final String? initialLocation;

  @override
  State<MiriaGoApp> createState() => _MiriaGoAppState();
}

class _MiriaGoAppState extends State<MiriaGoApp> with WidgetsBindingObserver {
  late final PlansStore _plans = PlansStore(
    repository: widget.services.repository,
    session: widget.session,
  );
  late final ReferenceCacheCenter _cache = ReferenceCacheCenter(
    repository: widget.services.repository,
    session: widget.session,
  );
  final ToastController _toasts = ToastController();
  late final GoRouter _router = buildRouter(
    initialLocation: widget.initialLocation ?? _initialLocation(),
  );
  final _incoming = const IncomingPlanFileChannel();
  final Map<ReferenceCacheTask, bool> _wasRunning = {};

  String _initialLocation() {
    final session = widget.session;
    if (session.isReady && session.plan.points.isNotEmpty) return Routes.go;
    return Routes.plan;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_plans.refresh());
    _cache.addListener(_onCacheChanged);
    _incoming.listen(_importFromPath, onError: _showIncomingError);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadInitialIncomingFile());
      final settings = widget.settings.settings;
      warmConfiguredMapStyle(
        settings,
        dark:
            widget.settings.resolvedBrightness(
              WidgetsBinding.instance.platformDispatcher.platformBrightness,
            ) ==
            Brightness.dark,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cache.removeListener(_onCacheChanged);
    _router.dispose();
    _plans.dispose();
    _cache.dispose();
    _toasts.dispose();
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    widget.settings.platformBrightnessChanged();
  }

  void _onCacheChanged() {
    for (final task in _cache.tasks) {
      final was = _wasRunning[task] ?? false;
      _wasRunning[task] = task.isRunning;
      if (was && !task.isRunning) {
        final progress = task.progress;
        final status = task.status;
        _toasts.show(
          ToastData(
            kind: switch (status) {
              ReferenceCacheStatus.success => ToastKind.success,
              ReferenceCacheStatus.partial => ToastKind.warning,
              _ => ToastKind.error,
            },
            title:
                status == ReferenceCacheStatus.success ||
                    status == ReferenceCacheStatus.partial
                ? '参考图缓存完成'
                : '参考图缓存失败',
            message: status == ReferenceCacheStatus.interrupted
                ? '缓存中断，请重试；已保存的图片不会删除。'
                : progress == null
                ? null
                : status == ReferenceCacheStatus.success
                ? '${progress.succeeded} / ${progress.total} 张成功，已保存到本地'
                : '${progress.succeeded} / ${progress.total} 张成功 · ${progress.failed} 张失败',
            action: status == ReferenceCacheStatus.success
                ? null
                : ToastAction(label: '重试', onPressed: task.retry),
          ),
        );
      }
    }
  }

  Future<void> _loadInitialIncomingFile() async {
    final String? path;
    try {
      path = await _incoming.getInitialPath();
    } on IncomingPlanFileException catch (error) {
      _showIncomingError(error);
      return;
    }
    if (path == null || path.isEmpty) return;
    await _importFromPath(path);
  }

  void _showIncomingError(IncomingPlanFileException error) {
    _toasts.show(ToastData(kind: ToastKind.error, title: error.userMessage));
  }

  Future<void> _importFromPath(String path) async {
    try {
      final PlanImportPackage package;
      try {
        package = await readPlanImportPackageFromPath(path);
      } finally {
        unawaited(_incoming.release(path));
      }
      final navigatorContext = rootNavigatorKey.currentContext;
      if (navigatorContext == null || !navigatorContext.mounted) return;
      final imported = await openImportPreview(navigatorContext, package);
      if (!imported) return;
      await widget.session.load();
      await _plans.refresh();
      _router.go(Routes.plan);
    } catch (error) {
      _toasts.show(
        ToastData(
          kind: ToastKind.error,
          title: error is PlanImportLimitException ? error.message : '计划文件导入失败',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppServices>.value(value: widget.services),
        Provider<PilgrimageRepository>.value(value: widget.services.repository),
        Provider<PlatformCapabilities>.value(
          value: widget.services.capabilities,
        ),
        ChangeNotifierProvider<SettingsStore>.value(value: widget.settings),
        ChangeNotifierProvider<PlanSession>.value(value: widget.session),
        ChangeNotifierProvider<PlansStore>.value(value: _plans),
        ChangeNotifierProvider<ReferenceCacheCenter>.value(value: _cache),
        ChangeNotifierProvider<ToastController>.value(value: _toasts),
      ],
      child: Consumer<SettingsStore>(
        builder: (context, store, _) {
          final settings = store.settings;
          final light = resolveMiriaColors(
            brightness: Brightness.light,
            palette: settings.themePalette,
            customAccentValue: settings.customThemeColorValue,
          );
          final dark = resolveMiriaColors(
            brightness: Brightness.dark,
            palette: settings.themePalette,
            customAccentValue: settings.customThemeColorValue,
          );
          return MaterialApp.router(
            title: 'MiriaGo',
            debugShowCheckedModeBanner: false,
            theme: buildMiriaTheme(light),
            darkTheme: buildMiriaTheme(dark),
            themeMode: switch (settings.themeMode) {
              AppThemeMode.light => ThemeMode.light,
              AppThemeMode.dark => ThemeMode.dark,
              AppThemeMode.system => ThemeMode.system,
            },
            themeAnimationDuration: Motion.standard,
            locale: const Locale('zh', 'CN'),
            supportedLocales: const [
              Locale('zh', 'CN'),
              Locale('ja', 'JP'),
              Locale('en', 'US'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: _router,
            builder: (context, child) {
              final media = MediaQuery.of(context);
              final system = media.textScaler.scale(1);
              final app = appTextScaler(settings.fontScale).scale(1);
              return MediaQuery(
                data: media.copyWith(
                  textScaler: TextScaler.linear(math.min(system * app, 2.0)),
                ),
                child: AnitabiImageSourceScope(
                  source: settings.anitabiImageSource,
                  child: AppUiScaleView(
                    scale: settings.uiScale,
                    child: ToastHost(child: child ?? const SizedBox.shrink()),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
