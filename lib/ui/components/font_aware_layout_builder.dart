import 'package:flutter/material.dart';

/// A [LayoutBuilder] that also rebuilds when system / fallback fonts
/// finish loading (web downloads CJK fallback fonts lazily), so decisions
/// based on measured text widths stay correct.
///
/// Use it instead of [LayoutBuilder] whenever the builder measures text
/// with a [TextPainter].
class FontAwareLayoutBuilder extends StatefulWidget {
  const FontAwareLayoutBuilder({required this.builder, super.key});

  final Widget Function(BuildContext context, BoxConstraints constraints)
  builder;

  @override
  State<FontAwareLayoutBuilder> createState() => _FontAwareLayoutBuilderState();
}

class _FontAwareLayoutBuilderState extends State<FontAwareLayoutBuilder> {
  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_onFonts);
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_onFonts);
    super.dispose();
  }

  void _onFonts() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // A new LayoutBuilder instance re-runs its builder on the next layout.
    return LayoutBuilder(builder: widget.builder);
  }
}
