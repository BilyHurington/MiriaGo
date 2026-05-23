import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'data/pilgrimage_repository.dart';
import 'data/sample_pilgrimage_repository.dart';
import 'map/pilgrimage_map_screen.dart';
import 'plan/add_points_screen.dart';
import 'plan/plan_manager_screen.dart';
import 'plan/pilgrimage_plan_controller.dart';
import 'plan/plan_screen.dart';
import 'records/records_screen.dart';

class AppShell extends StatefulWidget {
  AppShell({PilgrimageRepository? repository, super.key})
    : repository = repository ?? SamplePilgrimageRepository();

  final PilgrimageRepository repository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  PilgrimagePlanController? _planController;
  Object? _loadError;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadActivePlan();
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
      if (!mounted) {
        return;
      }

      _planController?.dispose();
      setState(() {
        _planController = PilgrimagePlanController(plan: plan);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadError = error;
      });
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
  }

  Future<void> _openAddPoints() async {
    final didUpdate = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AddPointsScreen(
          plan: _planController?.plan,
          repository: widget.repository,
        ),
      ),
    );
    if (didUpdate == true) {
      await _loadActivePlan();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _planController;

    if (controller == null) {
      return _PlanLoadState(error: _loadError, onRetry: _loadActivePlan);
    }

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Scaffold(
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              PlanScreen(
                controller: controller,
                onOpenMap: _openMap,
                onOpenPlanManager: _openPlanManager,
                onOpenAddPoints: _openAddPoints,
              ),
              PilgrimageMapScreen(controller: controller),
              RecordsScreen(controller: controller),
            ],
          ),
          bottomNavigationBar: NavigationBarTheme(
            data: NavigationBarThemeData(
              indicatorColor: AppColors.accent,
              iconTheme: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const IconThemeData(color: Colors.white);
                }

                return const IconThemeData(color: AppColors.textPrimary);
              }),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(
                    color: AppColors.accentDark,
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
              ],
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
