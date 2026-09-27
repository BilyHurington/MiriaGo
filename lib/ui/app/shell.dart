import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../design/theme.dart';
import '../features/plans/plan_switcher.dart';
import '../layout/window_class.dart';
import 'task_indicator.dart';
import 'toast.dart';

class _Destination {
  const _Destination(this.label, this.icon);
  final String label;
  final IconData icon;
}

const _destinations = [
  _Destination('计划', Symbols.event_note_rounded),
  _Destination('巡礼', Symbols.explore_rounded),
  _Destination('记录', Symbols.photo_library_rounded),
  _Destination('设置', Symbols.settings_rounded),
];

/// Adaptive navigation shell: bottom bar (compact), rail (medium /
/// expanded / short), sidebar (large+). See DESIGN §5.2.
class AppShell extends StatefulWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _sidebarCollapsed = false;

  void _select(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final c = context.colors;
    final index = widget.navigationShell.currentIndex;
    final toasts = context.read<ToastController>();

    if (layout.usesBottomBar) {
      final bottomInset = 68.0;
      toasts.bottomInset = bottomInset;
      return Scaffold(
        body: Stack(
          children: [
            widget.navigationShell,
            const Positioned(
              right: 12,
              bottom: 12,
              child: TaskIndicator(variant: TaskIndicatorVariant.floating),
            ),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.hairline)),
          ),
          child: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: _select,
            destinations: [
              for (final d in _destinations)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.icon, fill: 1),
                  label: d.label,
                ),
            ],
          ),
        ),
      );
    }

    toasts.bottomInset = 0;
    final useSidebar = layout.usesSidebar && !_sidebarCollapsed;
    return Scaffold(
      body: Row(
        children: [
          if (useSidebar)
            _Sidebar(
              selectedIndex: index,
              onSelect: _select,
              onCollapse: () => setState(() => _sidebarCollapsed = true),
            )
          else
            _Rail(
              selectedIndex: index,
              onSelect: _select,
              onExpand: layout.usesSidebar
                  ? () => setState(() => _sidebarCollapsed = false)
                  : null,
            ),
          VerticalDivider(width: 1, thickness: 1, color: c.hairline),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeLeft: true,
              child: widget.navigationShell,
            ),
          ),
        ],
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.selectedIndex,
    required this.onSelect,
    this.onExpand,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final short = context.layout.isShort;
    return ColoredBox(
      color: c.surface,
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: 80,
          child: Column(
            children: [
              SizedBox(height: short ? 4 : 12),
              if (onExpand != null)
                IconButton(
                  tooltip: '展开侧边栏',
                  onPressed: onExpand,
                  icon: const Icon(Symbols.left_panel_open_rounded),
                ),
              const PlanSwitcherButton(variant: PlanSwitcherVariant.rail),
              SizedBox(height: short ? 0 : 8),
              Expanded(
                child: NavigationRail(
                  backgroundColor: Colors.transparent,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onSelect,
                  labelType: short
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  minWidth: 80,
                  groupAlignment: -1,
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.icon, fill: 1),
                        label: Text(d.label),
                      ),
                  ],
                ),
              ),
              const TaskIndicator(variant: TaskIndicatorVariant.rail),
              SizedBox(height: short ? 4 : 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.onSelect,
    required this.onCollapse,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return ColoredBox(
      color: c.surface,
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: 256,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: Radii.xsAll,
                      child: Image.asset(
                        'icon.jpg',
                        width: 26,
                        height: 26,
                        cacheWidth: 78,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text('MiriaGo', style: text.titleMedium)),
                    IconButton(
                      tooltip: '收起侧边栏',
                      onPressed: onCollapse,
                      icon: Icon(
                        Symbols.left_panel_close_rounded,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: PlanSwitcherButton(variant: PlanSwitcherVariant.sidebar),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _destinations.length; i++)
                _SidebarItem(
                  destination: _destinations[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelect(i),
                ),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: TaskIndicator(variant: TaskIndicatorVariant.sidebar),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? c.primaryContainer : Colors.transparent,
        borderRadius: Radii.smAll,
        child: InkWell(
          borderRadius: Radii.smAll,
          onTap: onTap,
          child: Semantics(
            selected: selected,
            button: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    destination.icon,
                    size: 22,
                    fill: selected ? 1 : 0,
                    color: selected ? c.onPrimaryContainer : c.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    destination.label,
                    style: text.labelLarge?.copyWith(
                      color: selected ? c.onPrimaryContainer : c.textPrimary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
