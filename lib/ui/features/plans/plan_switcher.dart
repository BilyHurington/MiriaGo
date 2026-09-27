import 'package:flutter/material.dart';

enum PlanSwitcherVariant {
  /// Title chip used in page headers (「示例计划 ▾」).
  chip,

  /// Header block at the top of the desktop sidebar.
  sidebar,

  /// Compact icon button for the navigation rail.
  rail,
}

/// Opens the plan switcher (sheet on compact, popover/dialog on wide).
/// OWNER: feature agent B (plan).
Future<void> showPlanSwitcher(BuildContext context) async {}

/// Entry point to the plan switcher, shown in page headers and the shell.
/// OWNER: feature agent B (plan).
class PlanSwitcherButton extends StatelessWidget {
  const PlanSwitcherButton({
    this.variant = PlanSwitcherVariant.chip,
    super.key,
  });

  final PlanSwitcherVariant variant;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
