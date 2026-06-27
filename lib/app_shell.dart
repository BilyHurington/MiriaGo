import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'data/pilgrimage_repository.dart';
import 'data/sample_pilgrimage_repository.dart';
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
import 'plan_transfer/plan_import_preview_screen.dart';
import 'records/records_screen.dart';
import 'settings/settings_screen.dart';

class AppShell extends StatefulWidget {
  AppShell({PilgrimageRepository? repository, super.key})
    : repository = repository ?? SamplePilgrimageRepository();

  final PilgrimageRepository repository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  PilgrimagePlanController? _planController;
  AppSettings _settings = const AppSettings();
  Object? _loadError;
  int _selectedIndex = 0;
  final _incomingPlanFiles = const IncomingPlanFileChannel();

  @override
  void initState() {
    super.initState();
    _incomingPlanFiles.listen(_importPlanFromPath);
    _initializeApp();
  }

  @override
  void dispose() {
    _planController?.dispose();
    super.dispose();
  }

  Future<void> _loadActivePlan() async {
    setState(() {
      _loadError = null;
    });

    try {
      final plan = await widget.repository.loadActivePlan();
      final settings = await widget.repository.loadAppSettings();
      if (!mounted) {
        return;
      }

      _planController?.dispose();
      setState(() {
        _planController = PilgrimagePlanController(
          plan: plan,
          visitRepository: widget.repository,
        );
        _settings = settings;
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
    await _loadInitialIncomingPlanFile();
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
  }

  Future<void> _openAddPoints() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AddPointsScreen(
          plan: _planController?.plan,
          repository: widget.repository,
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
        builder: (_) =>
            PointManagerScreen(plan: plan, repository: widget.repository),
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
      if (mounted) {
        setState(() {
          _selectedIndex = 0;
        });
      }
    }
  }

  Future<void> _saveSettings(AppSettings settings) async {
    setState(() {
      _settings = settings;
    });
    await widget.repository.saveAppSettings(settings);
  }

  Future<void> _loadInitialIncomingPlanFile() async {
    final path = await _incomingPlanFiles.getInitialPath();
    if (path == null || path.isEmpty) {
      return;
    }
    await _importPlanFromPath(path);
  }

  Future<void> _importPlanFromPath(String path) async {
    try {
      final importPackage = await readPlanImportPackageFromPath(path);
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
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedIndex = 0;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('计划文件导入失败')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _planController;
    AppColors.palette = _settings.themePalette;
    AppColors.customAccentValue = _settings.customThemeColorValue;

    if (controller == null) {
      return _PlanLoadState(error: _loadError, onRetry: _loadActivePlan);
    }

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: appTextScaler(_settings.fontScale)),
          child: AppUiScaleView(
            scale: _settings.uiScale,
            child: Theme(
              data: AppTheme.light(
                palette: _settings.themePalette,
                customAccentValue: _settings.customThemeColorValue,
              ),
              child: Scaffold(
                body: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    PlanScreen(
                      controller: controller,
                      settings: _settings,
                      repository: widget.repository,
                      onOpenMap: _openMap,
                      onOpenPlanManager: _openPlanManager,
                      onOpenAddPoints: _openAddPoints,
                      onOpenPointManager: _openPointManager,
                      onOpenImportExport: _openImportExport,
                    ),
                    PilgrimageMapScreen(
                      controller: controller,
                      settings: _settings,
                    ),
                    RecordsScreen(controller: controller),
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

                      return const IconThemeData(color: AppColors.textPrimary);
                    }),
                    labelTextStyle: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        );
                      }

                      return const TextStyle(
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
                        icon: Icon(Icons.checklist_outlined),
                        selectedIcon: Icon(Icons.checklist),
                        label: '计划',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.map_outlined),
                        selectedIcon: Icon(Icons.map),
                        label: '地图',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.collections_bookmark_outlined),
                        selectedIcon: Icon(Icons.collections_bookmark),
                        label: '记录',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: '设置',
                      ),
                    ],
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
                hasError ? Icons.error_outline : Icons.route_outlined,
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
                style: const TextStyle(
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
                  style: const TextStyle(
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
                  icon: const Icon(Icons.refresh, size: 18),
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
