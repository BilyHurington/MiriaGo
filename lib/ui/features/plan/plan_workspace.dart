import 'package:flutter/material.dart';

/// Wraps every page of the 计划 branch (`/plan/**`). On expanded+ windows
/// it adds the secondary navigation (概览 / 片区与点位 / 作品 / 备忘录 /
/// 导入导出); on compact it just returns [child].
/// OWNER: feature agent B (plan).
class PlanWorkspaceScaffold extends StatelessWidget {
  const PlanWorkspaceScaffold({
    required this.location,
    required this.child,
    super.key,
  });

  /// Current router location (e.g. `/plan/works`).
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
