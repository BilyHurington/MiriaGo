import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/plan/plan_insights.dart';
import '../../../application/plan_session.dart';
import '../../app/router.dart';
import '../../components/components.dart';

/// Asks whether the current workspace page may be left (e.g. the memo
/// editor with unsaved changes). Return false to stay.
typedef PlanLeaveGuard = Future<bool> Function();

class _PlanSection {
  const _PlanSection(this.label, this.icon, this.path);
  final String label;
  final IconData icon;
  final String path;
}

const _sections = [
  _PlanSection('概览', Symbols.dashboard_rounded, Routes.plan),
  _PlanSection('片区与点位', Symbols.folder_rounded, Routes.organize),
  _PlanSection('作品', Symbols.movie_rounded, Routes.works),
  _PlanSection('备忘录', Symbols.sticky_note_2_rounded, Routes.memo),
  _PlanSection('导入导出', Symbols.swap_vert_rounded, Routes.transfer),
];

/// Width of the secondary navigation column.
const double _navWidth = 232;

/// Wraps every page of the 计划 branch (`/plan/**`). On expanded+ windows
/// it adds the secondary navigation (概览 / 片区与点位 / 作品 / 备忘录 /
/// 导入导出); on compact it just returns [child].
/// OWNER: feature agent B (plan).
class PlanWorkspaceScaffold extends StatefulWidget {
  const PlanWorkspaceScaffold({
    required this.location,
    required this.child,
    super.key,
  });

  /// Current router location (e.g. `/plan/works`).
  final String location;
  final Widget child;

  /// Whether the secondary navigation is shown for this window.
  static bool showsSecondaryNav(BuildContext context) =>
      context.layout.windowClass >= WindowClass.expanded;

  @override
  State<PlanWorkspaceScaffold> createState() => _PlanWorkspaceScaffoldState();
}

class _PlanWorkspaceScaffoldState extends State<PlanWorkspaceScaffold> {
  final Set<PlanLeaveGuard> _guards = {};

  Future<void> _open(String path) async {
    // Re-selecting the current section root does nothing; from a sub page
    // it returns to the root, which disposes the sub page, so the guards
    // are asked just like for another section.
    if (widget.location == path) return;
    for (final guard in List.of(_guards)) {
      if (!await guard()) return;
    }
    if (!mounted) return;
    context.go(path);
  }

  bool _isSelected(String path) {
    final location = widget.location;
    if (path == Routes.plan) return location == Routes.plan;
    return location == path || location.startsWith('$path/');
  }

  @override
  Widget build(BuildContext context) {
    final showNav = PlanWorkspaceScaffold.showsSecondaryNav(context);
    final scoped = PlanWorkspaceScope._(
      leaveGuards: _guards,
      showsSecondaryNav: showNav,
      child: widget.child,
    );
    if (!showNav) return scoped;
    final c = context.colors;
    return ColoredBox(
      color: c.canvas,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _navWidth,
            child: _SecondaryNav(isSelected: _isSelected, onOpen: _open),
          ),
          VerticalDivider(width: 1, thickness: 1, color: c.hairline),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeLeft: true,
              child: scoped,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lets workspace pages register a [PlanLeaveGuard] consulted before the
/// secondary navigation switches sections, and tells them whether the
/// secondary navigation is visible (so they can hide their back button).
class PlanWorkspaceScope extends InheritedWidget {
  const PlanWorkspaceScope._({
    required this.leaveGuards,
    required this.showsSecondaryNav,
    required super.child,
  });

  /// Guards registered by the visible pages (see [addLeaveGuard]).
  final Set<PlanLeaveGuard> leaveGuards;
  final bool showsSecondaryNav;

  static PlanWorkspaceScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlanWorkspaceScope>();

  /// True when [context] is a top-level workspace section beside the
  /// secondary navigation (a back button would be redundant there).
  static bool hasSecondaryNav(BuildContext context) =>
      maybeOf(context)?.showsSecondaryNav ?? false;

  void addLeaveGuard(PlanLeaveGuard guard) => leaveGuards.add(guard);
  void removeLeaveGuard(PlanLeaveGuard guard) => leaveGuards.remove(guard);

  @override
  bool updateShouldNotify(PlanWorkspaceScope oldWidget) =>
      showsSecondaryNav != oldWidget.showsSecondaryNav;
}

class _SecondaryNav extends StatelessWidget {
  const _SecondaryNav({required this.isSelected, required this.onOpen});

  final bool Function(String path) isSelected;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final session = context.watch<PlanSession>();
    // The large-window sidebar already shows the plan switcher block.
    final plan = session.isReady && !context.layout.usesSidebar
        ? session.plan
        : null;
    return ColoredBox(
      color: c.canvas,
      child: SafeArea(
        right: false,
        left: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Space.x3,
            Space.x4,
            Space.x3,
            Space.x4,
          ),
          children: [
            if (plan != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.x3,
                  0,
                  Space.x3,
                  Space.x4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '计划',
                      style: text.labelMedium?.copyWith(color: c.textTertiary),
                    ),
                    const SizedBox(height: Space.x1),
                    Text(
                      plan.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plan.area,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.caption.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: Space.x2),
                    _MiniProgress(
                      completed: completedPointCount(plan),
                      total: plan.points.length,
                    ),
                  ],
                ),
              ),
            for (final section in _sections)
              _NavItem(
                section: section,
                selected: isSelected(section.path),
                onTap: () => onOpen(section.path),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniProgress extends StatelessWidget {
  const _MiniProgress({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: Radii.pillAll,
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : completed / total,
              minHeight: 4,
              color: c.primary,
              backgroundColor: c.surfaceMuted,
            ),
          ),
        ),
        const SizedBox(width: Space.x2),
        Text(
          '$completed/$total',
          style: context.text.caption.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final _PlanSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? c.primaryContainer : Colors.transparent,
        borderRadius: Radii.smAll,
        child: MiriaPressable(
          onTap: onTap,
          borderRadius: Radii.smAll,
          selected: selected,
          semanticLabel: section.label,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.x3,
                vertical: Space.x2,
              ),
              child: Row(
                children: [
                  Icon(
                    section.icon,
                    size: 20,
                    fill: selected ? 1 : 0,
                    color: selected ? c.onPrimaryContainer : c.textSecondary,
                  ),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: Text(
                      section.label,
                      style: text.labelLarge?.copyWith(
                        color: selected ? c.onPrimaryContainer : c.textPrimary,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
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
