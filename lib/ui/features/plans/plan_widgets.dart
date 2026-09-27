import 'package:flutter/material.dart';

import '../../../application/plan/plan_insights.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../components/components.dart';

/// Up to three work tags plus 「+N」, or 「暂无作品」 (old `_PlanWorkTags`).
class PlanWorkTags extends StatelessWidget {
  const PlanWorkTags({required this.plan, super.key});

  final PilgrimagePlan plan;

  static const visibleCount = 3;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final works = planCardWorks(plan);
    if (works.isEmpty) {
      return Text(
        '暂无作品',
        style: context.text.labelSmall?.copyWith(color: c.textTertiary),
      );
    }
    final visible = works.take(visibleCount).toList(growable: false);
    final remaining = works.length - visible.length;
    return Wrap(
      spacing: Space.x1 + 2,
      runSpacing: Space.x1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < visible.length; i++)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Tag(
              label: visible[i].title,
              color: c.groupColor(i),
              locale: MiriaFonts.japanese,
            ),
          ),
        if (remaining > 0)
          Text(
            '+$remaining',
            style: context.text.labelSmall?.copyWith(
              color: c.textSecondary,
              fontFeatures: MiriaFonts.tabular,
            ),
          ),
      ],
    );
  }
}

/// Thin progress bar with 「完成数/总数」.
class PlanProgressBar extends StatelessWidget {
  const PlanProgressBar({required this.plan, this.dense = false, super.key});

  final PilgrimagePlan plan;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final completed = completedPointCount(plan);
    final total = plan.points.length;
    return Semantics(
      label: '已完成 $completed/$total',
      excludeSemantics: true,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: Radii.pillAll,
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : completed / total,
                minHeight: dense ? 3 : 4,
                color: completed == total && total > 0 ? c.success : c.primary,
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
      ),
    );
  }
}
