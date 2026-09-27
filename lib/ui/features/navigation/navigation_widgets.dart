import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../application/navigation/navigation_session.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../components/components.dart';

/// Icons follow Valhalla's `DirectionsLeg.Maneuver.Type` numbering (the
/// same numbering the backend uses for the localized text).
IconData navigationManeuverIcon(int type) => switch (type) {
  4 || 5 || 6 => Symbols.flag_rounded,
  2 || 10 || 11 || 20 || 37 => Symbols.turn_right_rounded,
  3 || 14 || 15 || 21 || 38 => Symbols.turn_left_rounded,
  9 || 18 || 23 => Symbols.turn_slight_right_rounded,
  16 || 19 || 24 => Symbols.turn_slight_left_rounded,
  // 12 is a right U-turn, 13 a left one.
  12 => Symbols.u_turn_right_rounded,
  13 => Symbols.u_turn_left_rounded,
  26 || 27 => Symbols.roundabout_right_rounded,
  39 || 40 || 41 || 44 => Symbols.swap_vert_rounded,
  _ => Symbols.straight_rounded,
};

/// 片区 badge + name.
class NavigationGroupRow extends StatelessWidget {
  const NavigationGroupRow({
    required this.name,
    this.centered = false,
    super.key,
  });

  final String name;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: centered ? MainAxisSize.min : MainAxisSize.max,
      children: [
        const Tag(label: '片区', tone: MiriaTone.primary),
        const SizedBox(width: Space.x2),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodyMedium,
          ),
        ),
      ],
    );
  }
}

/// Maneuver card: icon, distance and instruction; swipe through the steps.
/// Dots show at most 9 pages plus 「i / n」.
class ManeuverCard extends StatelessWidget {
  const ManeuverCard({
    required this.steps,
    required this.controller,
    required this.index,
    required this.liveIndex,
    required this.liveDistanceMeters,
    required this.onPageChanged,
    this.groupName,
    super.key,
  });

  final List<NavigationStep> steps;
  final PageController controller;
  final int index;
  final int liveIndex;
  final double? liveDistanceMeters;
  final ValueChanged<int> onPageChanged;
  final String? groupName;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final zone = groupName?.trim() ?? '';
    final pageHeight = MediaQuery.textScalerOf(
      context,
    ).scale(72).clamp(72.0, 132.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (zone.isNotEmpty)
          Padding(
            key: const ValueKey('in-app-navigation-top-zone'),
            padding: const EdgeInsets.only(bottom: Space.x2),
            child: Center(
              child: NavigationGroupRow(name: zone, centered: true),
            ),
          ),
        SizedBox(
          height: pageHeight,
          child: PageView.builder(
            key: const ValueKey('in-app-navigation-steps'),
            controller: controller,
            onPageChanged: onPageChanged,
            itemCount: steps.length,
            itemBuilder: (context, pageIndex) {
              final step = steps[pageIndex];
              final live = pageIndex == liveIndex ? liveDistanceMeters : null;
              final distance = live == null
                  ? step.distanceLabel
                  : navigationDistanceLabel(live / 1000);
              return Row(
                children: [
                  Icon(
                    navigationManeuverIcon(step.maneuverType),
                    size: 48,
                    color: c.textPrimary,
                  ),
                  const SizedBox(width: Space.x4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          distance,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                            fontFeatures: MiriaFonts.tabular,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          step.instruction,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          locale: MiriaFonts.japanese,
                          style: context.text.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: Space.x2),
        StepDots(count: steps.length, index: index),
      ],
    );
  }
}

/// Page dots for the instruction pager. Long routes show a window of dots
/// around the current page plus an 「n / total」 counter.
class StepDots extends StatelessWidget {
  const StepDots({required this.count, required this.index, super.key});

  static const maxDots = 9;

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (count <= 1) return const SizedBox(height: 6);
    final current = index.clamp(0, count - 1);
    final visible = math.min(count, maxDots);
    final first = (current - visible ~/ 2).clamp(0, count - visible);
    return Row(
      key: const ValueKey('in-app-navigation-step-dots'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = first; i < first + visible; i++)
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == current ? c.textPrimary : c.hairlineStrong,
            ),
          ),
        if (count > maxDots) ...[
          const SizedBox(width: Space.x2),
          Text(
            '${current + 1} / $count',
            style: context.text.labelSmall?.copyWith(
              color: c.textSecondary,
              fontFeatures: MiriaFonts.tabular,
            ),
          ),
        ],
      ],
    );
  }
}

/// Trip panel: headline, expand toggle, 到达 / 小时 / 公里 and — expanded —
/// destination, 全部点位, 已到达, 结束路线.
class TripPanel extends StatelessWidget {
  const TripPanel({
    required this.target,
    required this.isLast,
    required this.stopCount,
    required this.metrics,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onShowAllStops,
    required this.onArrive,
    required this.onEndRoute,
    this.collapsible = true,
    super.key,
  });

  final PilgrimagePoint target;
  final bool isLast;
  final int stopCount;
  final NavigationTripMetrics metrics;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onShowAllStops;
  final VoidCallback onArrive;
  final VoidCallback onEndRoute;
  final bool collapsible;

  @override
  Widget build(BuildContext context) {
    final showDetails = expanded || !collapsible;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                navigationStopHeadline(target, isLast: isLast),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                locale: MiriaFonts.japanese,
                style: context.text.titleMedium,
              ),
            ),
            if (collapsible) ...[
              const SizedBox(width: Space.x3),
              MiriaIconButton(
                key: ValueKey(
                  expanded
                      ? 'in-app-navigation-collapse'
                      : 'in-app-navigation-expand',
                ),
                icon: expanded
                    ? Symbols.expand_more_rounded
                    : Symbols.expand_less_rounded,
                tooltip: expanded ? '收起' : '展开',
                variant: MiriaIconButtonVariant.filled,
                onPressed: onToggleExpanded,
              ),
            ],
          ],
        ),
        const SizedBox(height: Space.x3),
        _TripSummary(metrics: metrics),
        if (showDetails) ...[
          const SizedBox(height: Space.x4),
          NavigationInfoRow(
            icon: Symbols.location_on_rounded,
            tone: MiriaTone.danger,
            title: target.name,
            subtitle: navigationDestinationSubtitle(target),
          ),
          const SizedBox(height: Space.x2),
          NavigationInfoRow(
            key: const ValueKey('in-app-navigation-all-stops'),
            icon: Symbols.list_rounded,
            title: '全部点位',
            subtitle: stopCount == 0 ? null : '共 $stopCount 个',
            onTap: onShowAllStops,
          ),
          const SizedBox(height: Space.x4),
          MiriaButton.secondary(
            key: const ValueKey('in-app-navigation-arrive'),
            label: '已到达',
            icon: Symbols.flag_rounded,
            size: MiriaButtonSize.lg,
            expand: true,
            onPressed: onArrive,
          ),
          const SizedBox(height: Space.x2),
          MiriaButton.danger(
            key: const ValueKey('in-app-navigation-end-route'),
            label: '结束路线',
            size: MiriaButtonSize.lg,
            expand: true,
            onPressed: onEndRoute,
          ),
        ],
      ],
    );
  }
}

class _TripSummary extends StatelessWidget {
  const _TripSummary({required this.metrics});

  final NavigationTripMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('in-app-navigation-trip-summary'),
      children: [
        _Metric(value: metrics.arrivalText, label: '到达'),
        _Metric(value: metrics.durationText, label: '小时'),
        _Metric(value: metrics.distanceText, label: '公里'),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: MiriaFonts.tabular,
            ),
          ),
          Text(
            label,
            style: context.text.labelMedium?.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Icon disc, title, subtitle; tappable when [onTap] is set.
class NavigationInfoRow extends StatelessWidget {
  const NavigationInfoRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.tone = MiriaTone.neutral,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final MiriaTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (fill, onFill) = switch (tone) {
      MiriaTone.danger => (c.danger, c.onPrimary),
      MiriaTone.primary => (c.primary, c.onPrimary),
      _ => (c.surfaceMuted, c.textPrimary),
    };
    return ListRow(
      title: title,
      subtitle: subtitle,
      titleLocale: MiriaFonts.japanese,
      showChevron: onTap != null,
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: onFill),
      ),
    );
  }
}

/// Body of the arrival sheet (到达点位).
class ArrivalSheetContent extends StatelessWidget {
  const ArrivalSheetContent({
    required this.arrival,
    required this.onOpenCamera,
    this.onGoNext,
    this.onFinish,
    super.key,
  });

  final NavigationArrival arrival;
  final VoidCallback onOpenCamera;
  final VoidCallback? onGoNext;
  final VoidCallback? onFinish;

  @override
  Widget build(BuildContext context) {
    final next = arrival.nextStop;
    return Column(
      key: const ValueKey('in-app-navigation-arrival-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NavigationInfoRow(
          icon: Symbols.flag_rounded,
          tone: arrival.isLast ? MiriaTone.danger : MiriaTone.primary,
          title: arrival.arrived.name,
          subtitle: navigationDestinationSubtitle(arrival.arrived),
        ),
        const SizedBox(height: Space.x2),
        NavigationInfoRow(
          key: const ValueKey('in-app-navigation-open-camera'),
          icon: Symbols.photo_camera_rounded,
          title: '打开相机',
          subtitle: '第 ${arrival.stopNumber} / ${arrival.remainingCount} 个剩余点位',
          onTap: onOpenCamera,
        ),
        if (next != null) ...[
          const SizedBox(height: Space.x2),
          NavigationInfoRow(
            icon: Symbols.arrow_forward_rounded,
            title: next.name,
            subtitle: '下一点位 · ${navigationDestinationSubtitle(next)}',
          ),
        ],
        if (onGoNext != null) ...[
          const SizedBox(height: Space.x4),
          MiriaButton(
            key: const ValueKey('in-app-navigation-arrival-next'),
            label: '前往下一点',
            icon: Symbols.arrow_forward_rounded,
            size: MiriaButtonSize.lg,
            expand: true,
            onPressed: onGoNext,
          ),
        ],
        if (onFinish != null) ...[
          const SizedBox(height: Space.x4),
          MiriaButton.danger(
            key: const ValueKey('in-app-navigation-arrival-finish'),
            label: '结束路线',
            size: MiriaButtonSize.lg,
            expand: true,
            onPressed: onFinish,
          ),
        ],
      ],
    );
  }
}

/// Body of the 全部点位 sheet.
class AllStopsSheetContent extends StatelessWidget {
  const AllStopsSheetContent({
    required this.stops,
    required this.startIndex,
    this.groupName,
    super.key,
  });

  final List<PilgrimagePoint> stops;
  final int startIndex;
  final String? groupName;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final zone = groupName?.trim() ?? '';
    return Column(
      key: const ValueKey('in-app-navigation-all-stops-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (zone.isNotEmpty) ...[
          NavigationGroupRow(name: zone),
          const SizedBox(height: Space.x3),
        ],
        for (var index = 0; index < stops.length; index++) ...[
          if (index > 0) const SizedBox(height: Space.x1),
          _StopTile(
            index: index,
            stop: stops[index],
            isLast: index == stops.length - 1,
            skipped: index < startIndex,
            colors: c,
          ),
        ],
      ],
    );
  }
}

class _StopTile extends StatelessWidget {
  const _StopTile({
    required this.index,
    required this.stop,
    required this.isLast,
    required this.skipped,
    required this.colors,
  });

  final int index;
  final PilgrimagePoint stop;
  final bool isLast;
  final bool skipped;
  final MiriaColors colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final fill = skipped
        ? c.surfaceMuted
        : isLast
        ? c.danger
        : c.primary;
    return KeyedSubtree(
      key: skipped
          ? ValueKey('in-app-navigation-stop-skipped-${stop.id}')
          : null,
      child: ListRow(
        title: skipped
            ? stop.name
            : navigationStopHeadline(stop, isLast: isLast),
        subtitle: navigationDestinationSubtitle(stop),
        titleLocale: MiriaFonts.japanese,
        titleMaxLines: 1,
        subtitleMaxLines: 1,
        titleStyle: skipped
            ? context.text.titleSmall?.copyWith(color: c.textSecondary)
            : null,
        leading: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
          child: Text(
            '${index + 1}',
            style: context.text.labelMedium?.copyWith(
              color: skipped ? c.textSecondary : c.onPrimary,
              fontWeight: FontWeight.w800,
              fontFeatures: MiriaFonts.tabular,
            ),
          ),
        ),
      ),
    );
  }
}
