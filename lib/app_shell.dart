import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'app_theme.dart';
import 'data/anitabi_endpoint_sync.dart';
import 'data/anitabi_image_source_scope.dart';
import 'data/anitabi_service_config.dart';
import 'data/reference_image_cache_stub.dart'
    if (dart.library.io) 'data/reference_image_cache_io.dart';
import 'data/pilgrimage_repository.dart';
import 'data/sample_pilgrimage_repository.dart';
import 'data/work_cover_backfill.dart';
import 'map/map_tile_config.dart';
import 'map/pilgrimage_map_screen.dart';
import 'plan/add_points_screen.dart';
import 'plan/plan_manager_screen.dart';
import 'plan/pilgrimage_models.dart';
import 'plan/pilgrimage_plan_controller.dart';
import 'plan/plan_screen.dart';
import 'plan/point_manager_screen.dart';
import 'plan_transfer/import_export_screen.dart';
import 'plan_transfer/incoming_plan_file.dart';
import 'plan_transfer/plan_import_file_stub.dart'
    if (dart.library.io) 'plan_transfer/plan_import_file_io.dart';
import 'plan_transfer/plan_export_spool_sweep_stub.dart'
    if (dart.library.io) 'plan_transfer/plan_export_spool_sweep_io.dart';
import 'plan_transfer/plan_import_preview_screen.dart';
import 'plan_transfer/plan_import_package.dart';
import 'widgets/snackbar_helper.dart';
import 'records/comparison_export_temp_stub.dart'
    if (dart.library.io) 'records/comparison_export_temp_io.dart';
import 'records/records_screen.dart';
import 'records/comparison_export_config_migration.dart';
import 'settings/settings_screen.dart';
import 'widgets/app_scaled_route.dart';

class AppShell extends StatefulWidget {
  AppShell({
    PilgrimageRepository? repository,
    this.onSettingsChanged,
    super.key,
  }) : repository = repository ?? SamplePilgrimageRepository();

  final PilgrimageRepository repository;
  final ValueChanged<AppSettings>? onSettingsChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  PilgrimagePlanController? _planController;
  AppSettings _settings = const AppSettings();
  var _settingsLoaded = false;
  late final AnitabiEndpointSync _anitabiSync;
  Object? _loadError;
  int _selectedIndex = 0;
  final _incomingPlanFiles = const IncomingPlanFileChannel();

  @override
  void initState() {
    super.initState();
    _anitabiSync = AnitabiEndpointSync(
      loadSettings: () async =>
          _settingsLoaded ? _settings : widget.repository.loadAppSettings(),
      saveSettings: _storeSettings,
    );
    AnitabiEndpointSync.active = _anitabiSync;
    AnitabiEndpointRecovery.handler = _anitabiSync.recoverAfterFailure;
    _incomingPlanFiles.listen(
      _importPlanFromPath,
      onError: _showIncomingPlanFileError,
    );
    _initializeApp();
    unawaited(prepareReferenceCacheStorage());
    unawaited(sweepStaleComparisonExports(repository: widget.repository));
    unawaited(sweepStaleExportSpools());
  }

  @override
  void dispose() {
    if (identical(AnitabiEndpointSync.active, _anitabiSync)) {
      AnitabiEndpointSync.active = null;
      AnitabiEndpointRecovery.handler = null;
    }
    _planController?.dispose();
    super.dispose();
  }

  Future<void> _loadActivePlan() async {
    setState(() {
      _loadError = null;
    });

    try {
      final plan = await widget.repository.loadActivePlan();
      final loadedSettings = await widget.repository.loadAppSettings();
      final settings = await migrateComparisonExportConfigSettings(
        repository: widget.repository,
        settings: loadedSettings,
      );
      if (!mounted) {
        return;
      }

      _applyAnitabiServiceConfig(settings);
      _publishSettingsAfterLoad(settings);
      warmConfiguredMapStyle(
        settings,
        dark:
            resolvedAppBrightness(
              settings,
              platformBrightness: MediaQuery.platformBrightnessOf(context),
            ) ==
            Brightness.dark,
      );
      _planController?.dispose();
      setState(() {
        _planController = PilgrimagePlanController(
          plan: plan,
          visitRepository: widget.repository,
        );
        _settings = settings;
        _storedSettings = settings;
        _settingsLoaded = true;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to load active pilgrimage plan: $error');
      debugPrint(stackTrace.toString());
      if (!mounted) {
        return;
      }

      setState(() {
        _loadError = error;
      });
    }
  }

  Future<void> _initializeApp() async {
    await _loadActivePlan();
    _scheduleWorkCoverBackfill();
    await _loadInitialIncomingPlanFile();
  }

  /// Looks up missing work covers in the background, e.g. after a plan
  /// package without covers was imported.
  void _scheduleWorkCoverBackfill() {
    if (!WorkCoverBackfill.automaticEnabled) {
      return;
    }
    unawaited(_backfillWorkCovers());
  }

  Future<void> _backfillWorkCovers() async {
    try {
      final updated = await WorkCoverBackfill(
        repository: widget.repository,
      ).run();
      final controller = _planController;
      if (!mounted || controller == null) {
        return;
      }
      final works = updated[controller.plan.id];
      if (works != null) {
        controller.refreshWorks(works);
      }
    } on Object catch (error) {
      debugPrint('Work cover backfill failed: $error');
    }
  }

  void _openMap() {
    setState(() {
      _selectedIndex = 1;
    });
  }

  Future<void> _openPlanManager() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlanManagerScreen(repository: widget.repository),
      ),
    );
    await _loadActivePlan();
    _scheduleWorkCoverBackfill();
  }

  Future<void> _openAddPoints() async {
    await Navigator.of(context).push<bool>(
      appScaledMaterialPageRoute<bool>(
        settings: _settings,
        builder: (_) => AddPointsScreen(
          plan: _planController?.plan,
          repository: widget.repository,
          settings: _settings,
        ),
      ),
    );
    if (mounted) {
      await _loadActivePlan();
    }
  }

  Future<void> _openPointManager() async {
    final plan = _planController?.plan;
    if (plan == null) {
      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PointManagerScreen(
          plan: plan,
          repository: widget.repository,
          settings: _settings,
        ),
      ),
    );
    if (mounted) {
      await _loadActivePlan();
    }
  }

  Future<void> _openImportExport() async {
    final plan = _planController?.plan;
    if (plan == null) {
      return;
    }
    final imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            ImportExportScreen(plan: plan, repository: widget.repository),
      ),
    );
    if (imported == true) {
      await _loadActivePlan();
      _scheduleWorkCoverBackfill();
      if (mounted) {
        setState(() {
          _selectedIndex = 0;
        });
      }
    }
  }

  /// Settings edited in the UI. The address sync state is owned by
  /// [AnitabiEndpointSync], so a page holding an older copy of the settings
  /// never rolls it back. Resolves to false when saving failed; the previous
  /// settings are then shown again and the user is told.
  Future<bool> _saveSettings(AppSettings settings) async {
    try {
      await _storeSettings(
        settings.copyWith(
          anitabiRemoteStateJson: _settings.anitabiRemoteStateJson,
        ),
      );
      return true;
    } on Object catch (error) {
      debugPrint('Failed to save settings: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showStatusSnack(
          kind: AppStatusBannerKind.error,
          title: '设置保存失败',
          subtitle: '修改未能保存，请稍后重试',
        );
      }
      return false;
    }
  }

  var _settingsRevision = 0;

  /// The settings last confirmed as stored (loaded or saved).
  AppSettings? _storedSettings;

  /// Applies [settings] right away and stores them. If storing fails, the
  /// last stored settings are applied again, unless a newer change has been
  /// made since (its own save decides what is stored), and the error is
  /// rethrown. Saves complete in the order they were made.
  Future<void> _storeSettings(AppSettings settings) async {
    if (!mounted) {
      await widget.repository.saveAppSettings(settings);
      return;
    }
    final fallback = _storedSettings ?? _settings;
    final revision = ++_settingsRevision;
    _applySettings(settings);
    try {
      await widget.repository.saveAppSettings(settings);
      _storedSettings = settings;
    } on Object {
      if (mounted && revision == _settingsRevision) {
        _applySettings(_storedSettings ?? fallback);
      }
      rethrow;
    }
  }

  void _applySettings(AppSettings settings) {
    _applyAnitabiServiceConfig(settings);
    applyAppColorsFromSettings(
      settings,
      platformBrightness: currentPlatformBrightness(),
    );
    widget.onSettingsChanged?.call(settings);
    setState(() {
      _settings = settings;
    });
  }

  void _publishSettingsAfterLoad(AppSettings settings) {
    final callback = widget.onSettingsChanged;
    if (callback == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      callback(settings);
    });
  }

  void _applyAnitabiServiceConfig(AppSettings settings) {
    AnitabiServiceConfig.current = settings.anitabiServiceConfig;
  }

  Future<void> _loadInitialIncomingPlanFile() async {
    final String? path;
    try {
      path = await _incomingPlanFiles.getInitialPath();
    } on IncomingPlanFileException catch (error) {
      _showIncomingPlanFileError(error);
      return;
    }
    if (path == null || path.isEmpty) {
      return;
    }
    await _importPlanFromPath(path);
  }

  void _showIncomingPlanFileError(IncomingPlanFileException error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showStatusSnack(
      kind: AppStatusBannerKind.error,
      title: error.userMessage,
    );
  }

  Future<void> _importPlanFromPath(String path) async {
    try {
      final PlanImportPackage importPackage;
      try {
        importPackage = await readPlanImportPackageFromPath(path);
      } finally {
        // The package is fully in memory now (or failed); drop the native
        // temporary copy so incoming files do not pile up in the cache.
        unawaited(_incomingPlanFiles.release(path));
      }
      if (!mounted) {
        return;
      }
      final imported = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => PlanImportPreviewScreen(
            importPackage: importPackage,
            repository: widget.repository,
          ),
        ),
      );
      if (imported != true) {
        return;
      }
      await _loadActivePlan();
      _scheduleWorkCoverBackfill();
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedIndex = 0;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showStatusSnack(
        kind: AppStatusBannerKind.error,
        title: error is PlanImportLimitException ? error.message : '计划文件导入失败',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _planController;
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    applyAppColorsFromSettings(
      _settings,
      platformBrightness: platformBrightness,
    );
    final brightness = resolvedAppBrightness(
      _settings,
      platformBrightness: platformBrightness,
    );

    if (controller == null) {
      return Theme(
        data: appThemeFor(
          _settings,
          platformBrightness: MediaQuery.platformBrightnessOf(context),
        ),
        child: _PlanLoadState(error: _loadError, onRetry: _loadActivePlan),
      );
    }

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: appTextScalerFor(context, _settings.fontScale),
          ),
          child: AnitabiImageSourceScope(
            source: _settings.anitabiImageSource,
            child: AppUiScaleView(
              scale: _settings.uiScale,
              child: Theme(
                data: AppTheme.of(
                  brightness: brightness,
                  palette: _settings.themePalette,
                  customAccentValue: _settings.customThemeColorValue,
                ),
                child: Scaffold(
                  backgroundColor: AppColors.background,
                  body: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      PlanScreen(
                        isActive: _selectedIndex == 0,
                        controller: controller,
                        settings: _settings,
                        repository: widget.repository,
                        onOpenMap: _openMap,
                        onOpenPlanManager: _openPlanManager,
                        onOpenAddPoints: _openAddPoints,
                        onOpenPointManager: _openPointManager,
                        onOpenImportExport: _openImportExport,
                      ),
                      TickerMode(
                        enabled: _selectedIndex == 1,
                        child: PilgrimageMapScreen(
                          isActive: _selectedIndex == 1,
                          controller: controller,
                          settings: _settings,
                        ),
                      ),
                      RecordsScreen(
                        controller: controller,
                        settings: _settings,
                      ),
                      SettingsScreen(
                        settings: _settings,
                        repository: widget.repository,
                        onChanged: _saveSettings,
                      ),
                    ],
                  ),
                  bottomNavigationBar: NavigationBarTheme(
                    data: NavigationBarThemeData(
                      indicatorColor: AppColors.accent,
                      iconTheme: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return IconThemeData(color: AppColors.onAccent);
                        }

                        return IconThemeData(color: AppColors.textPrimary);
                      }),
                      labelTextStyle: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          );
                        }

                        return TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                        );
                      }),
                    ),
                    child: NavigationBar(
                      selectedIndex: _selectedIndex,
                      backgroundColor: AppColors.surface,
                      onDestinationSelected: (index) {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(LucideIcons.listTodo),
                          selectedIcon: Icon(LucideIcons.listTodo),
                          label: '计划',
                          tooltip: '',
                        ),
                        NavigationDestination(
                          icon: Icon(LucideIcons.map),
                          selectedIcon: Icon(LucideIcons.map),
                          label: '地图',
                          tooltip: '',
                        ),
                        NavigationDestination(
                          icon: Icon(LucideIcons.images),
                          selectedIcon: Icon(LucideIcons.images),
                          label: '记录',
                          tooltip: '',
                        ),
                        NavigationDestination(
                          icon: Icon(LucideIcons.settings),
                          selectedIcon: Icon(LucideIcons.settings),
                          label: '设置',
                          tooltip: '',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlanLoadState extends StatelessWidget {
  const _PlanLoadState({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasError ? LucideIcons.circleAlert : LucideIcons.route,
                color: hasError ? AppColors.error : AppColors.accent,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                hasError ? '计划加载失败' : '正在加载巡礼计划',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasError ? '请稍后重试。' : '准备今日点位和当前目标。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  letterSpacing: 0,
                ),
              ),
              if (hasError && kDebugMode) ...[
                const SizedBox(height: 10),
                SelectableText(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (hasError)
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                  label: const Text('重试'),
                )
              else
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
