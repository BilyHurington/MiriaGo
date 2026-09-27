import 'dart:math' as math;

import 'package:flutter/material.dart';

class ConstrainedMenuAnchor extends StatelessWidget {
  const ConstrainedMenuAnchor({
    required this.builder,
    required this.menuChildrenBuilder,
    this.minMenuWidth = 180,
    this.maxMenuWidth = 320,
    this.maxMenuHeight = 360,
    this.screenPadding = const EdgeInsets.symmetric(horizontal: 16),
    super.key,
  });

  final Widget Function(
    BuildContext context,
    MenuController controller,
    Widget? child,
  )
  builder;
  final List<Widget> Function(BuildContext context, double itemWidth)
  menuChildrenBuilder;
  final double minMenuWidth;
  final double maxMenuWidth;
  final double maxMenuHeight;
  final EdgeInsets screenPadding;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final availableWidth = math.max(
      120.0,
      screenSize.width - screenPadding.horizontal,
    );
    final availableHeight = math.max(96.0, screenSize.height * 0.45);

    return LayoutBuilder(
      builder: (context, constraints) {
        final anchorWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : math.min(maxMenuWidth, availableWidth);
        final effectiveMaxWidth = math.min(maxMenuWidth, availableWidth);
        final effectiveMinWidth = math.min(minMenuWidth, effectiveMaxWidth);
        final menuWidth = anchorWidth
            .clamp(effectiveMinWidth, effectiveMaxWidth)
            .toDouble();
        final menuHeight = math.min(maxMenuHeight, availableHeight);

        final itemWidth = math.max(0.0, menuWidth - 32);

        return MenuAnchor(
          alignmentOffset: Offset((anchorWidth - menuWidth) / 2, 0),
          builder: builder,
          menuChildren: [
            SizedBox(
              width: menuWidth,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: menuHeight),
                child: SingleChildScrollView(
                  primary: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: menuChildrenBuilder(context, itemWidth),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
