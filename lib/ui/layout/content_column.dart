import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'window_class.dart';

/// Single reading column (DESIGN §5.3 "单栏阅读").
///
/// Full width with the window gutter on phones; centred with a maximum
/// width of [WindowLayout.readingWidth] (720) on wider windows. Use it for
/// forms, settings sub-pages, import/export and memo reading.
///
/// ```dart
/// ContentColumn(child: Column(children: [...]))
/// ```
///
/// Inside a [CustomScrollView] use [SliverContentColumn] instead.
class ContentColumn extends StatelessWidget {
  const ContentColumn({
    required this.child,
    this.maxWidth = WindowLayout.readingWidth,
    this.padding = EdgeInsets.zero,
    this.gutter,
    super.key,
  });

  final Widget child;

  /// Maximum content width (gutters excluded).
  final double maxWidth;

  /// Extra padding around the column (usually vertical).
  final EdgeInsets padding;

  /// Horizontal gutter; defaults to `context.layout.gutter`.
  final double? gutter;

  @override
  Widget build(BuildContext context) {
    final side = gutter ?? context.layout.gutter;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth + side * 2),
        child: Padding(
          padding: padding.add(EdgeInsets.symmetric(horizontal: side)),
          child: child,
        ),
      ),
    );
  }
}

/// Sliver version of [ContentColumn]: centres [sliver] with a maximum
/// width and the window gutter.
///
/// ```dart
/// CustomScrollView(slivers: [
///   SliverContentColumn(sliver: SliverList.list(children: rows)),
/// ])
/// ```
class SliverContentColumn extends StatelessWidget {
  const SliverContentColumn({
    required this.sliver,
    this.maxWidth = WindowLayout.readingWidth,
    this.gutter,
    this.top = 0,
    this.bottom = 0,
    super.key,
  });

  final Widget sliver;
  final double maxWidth;
  final double? gutter;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final side = gutter ?? context.layout.gutter;
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final horizontal = math.max(
          side,
          (constraints.crossAxisExtent - maxWidth) / 2,
        );
        return SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom),
          sliver: sliver,
        );
      },
    );
  }
}
