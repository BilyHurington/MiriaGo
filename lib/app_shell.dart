import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'map/pilgrimage_map_screen.dart';
import 'plan/pilgrimage_plan_controller.dart';
import 'plan/plan_screen.dart';
import 'records/records_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final PilgrimagePlanController _planController = PilgrimagePlanController();

  int _selectedIndex = 0;

  @override
  void dispose() {
    _planController.dispose();
    super.dispose();
  }

  void _openMap() {
    setState(() {
      _selectedIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _planController,
      builder: (context, _) {
        return Scaffold(
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              PlanScreen(controller: _planController, onOpenMap: _openMap),
              PilgrimageMapScreen(controller: _planController),
              RecordsScreen(controller: _planController),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.accent.withValues(alpha: 0.14),
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
        );
      },
    );
  }
}
