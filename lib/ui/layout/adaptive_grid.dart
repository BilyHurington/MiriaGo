import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../design/tokens.dart';
import 'window_class.dart';

/// Minimum tile width for grids: 168 on compact windows, 220 otherwise.
double adaptiveMinTileWidth(WindowClass windowClass) =>
    windowClass == WindowClass.compact ? 168 : 220;

/// Column count for a grid of [width]: `width / minTileWidth`, at least
/// [minColumns] (DESIGN §5.3 "网格").
int adaptiveColumnCount(
  double width, {
  required double minTileWidth,
  double spacing = Space.x3,
  int minColumns = 2,
}) {
  if (!width.isFinite || width <= 0) return minColumns;
  final count = ((width + spacing) / (minTileWidth + spacing)).floor();
  return math.max(minColumns, count);
}

/// A non-lazy responsive grid for a handful of tiles (settings cards,
/// dashboard stats). Tiles keep their natural height; tiles of the same row
/// are top-aligned. For long lists use [SliverAdaptiveGrid].
///
/// ```dart
/// AdaptiveGrid(children: [for (final w in works) WorkCard(w)])
/// ```
class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    required this.children,
    this.minTileWidth,
    this.spacing = Space.x3,
    this.runSpacing,
    this.minColumns = 2,
    this.childAspectRatio,
    super.key,
  });

  final List<Widget> children;

  /// Defaults to [adaptiveMinTileWidth] of the current window.
  final double? minTileWidth;
  final double spacing;
  final double? runSpacing;
  final int minColumns;

  /// When set, every tile gets this width / height ratio.
  final double? childAspectRatio;

  @override
  Widget build(BuildContext context) {
    final minTile = minTileWidth ?? adaptiveMinTileWidth(context.windowClass);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = adaptiveColumnCount(
          constraints.maxWidth,
          minTileWidth: minTile,
          spacing: spacing,
          minColumns: minColumns,
        );
        final rows = <Widget>[];
        for (var start = 0; start < children.length; start += columns) {
          if (rows.isNotEmpty) {
            rows.add(SizedBox(height: runSpacing ?? spacing));
          }
          rows.add(
            _GridRow(
              columns: columns,
              spacing: spacing,
              aspectRatio: childAspectRatio,
              children: children.sublist(
                start,
                math.min(start + columns, children.length),
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: rows,
        );
      },
    );
  }
}

/// Lazy responsive grid sliver. Columns = available width / min tile width
/// (168 compact, 220 otherwise), at least 2.
///
/// Without [childAspectRatio] / [mainAxisExtent] tiles keep their natural
/// height (rows are built lazily); with one of them a regular [SliverGrid]
/// is used.
///
/// ```dart
/// SliverAdaptiveGrid(
///   itemCount: records.length,
///   itemBuilder: (context, i) => RecordCard(records[i]),
/// )
/// ```
class SliverAdaptiveGrid extends StatelessWidget {
  const SliverAdaptiveGrid({
    required this.itemCount,
    required this.itemBuilder,
    this.minTileWidth,
    this.spacing = Space.x3,
    this.runSpacing,
    this.minColumns = 2,
    this.childAspectRatio,
    this.mainAxisExtent,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double? minTileWidth;
  final double spacing;
  final double? runSpacing;
  final int minColumns;
  final double? childAspectRatio;
  final double? mainAxisExtent;

  @override
  Widget build(BuildContext context) {
    final minTile = minTileWidth ?? adaptiveMinTileWidth(context.windowClass);
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = adaptiveColumnCount(
          constraints.crossAxisExtent,
          minTileWidth: minTile,
          spacing: spacing,
          minColumns: minColumns,
        );
        if (childAspectRatio != null || mainAxisExtent != null) {
          return SliverGrid.builder(
            itemCount: itemCount,
            itemBuilder: itemBuilder,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: spacing,
              mainAxisSpacing: runSpacing ?? spacing,
              childAspectRatio: childAspectRatio ?? 1,
              mainAxisExtent: mainAxisExtent,
            ),
          );
        }
        final rowCount = (itemCount / columns).ceil();
        return SliverList.builder(
          itemCount: rowCount,
          itemBuilder: (context, row) {
            final start = row * columns;
            final end = math.min(start + columns, itemCount);
            return Padding(
              padding: EdgeInsets.only(
                top: row == 0 ? 0 : (runSpacing ?? spacing),
              ),
              child: _GridRow(
                columns: columns,
                spacing: spacing,
                children: [
                  for (var i = start; i < end; i++) itemBuilder(context, i),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _GridRow extends StatelessWidget {
  const _GridRow({
    required this.columns,
    required this.spacing,
    required this.children,
    this.aspectRatio,
  });

  final int columns;
  final double spacing;
  final double? aspectRatio;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[];
    for (var i = 0; i < columns; i++) {
      if (i > 0) cells.add(SizedBox(width: spacing));
      Widget cell = i < children.length ? children[i] : const SizedBox.shrink();
      if (aspectRatio != null) {
        cell = AspectRatio(aspectRatio: aspectRatio!, child: cell);
      }
      cells.add(Expanded(child: cell));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: cells);
  }
}
