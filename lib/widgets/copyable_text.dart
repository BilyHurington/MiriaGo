import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

OverlayEntry? _activeCopyOverlay;

final NavigatorObserver copyOverlayNavigatorObserver =
    _CopyOverlayNavigatorObserver();

class CopyableText extends StatefulWidget {
  const CopyableText({
    required this.text,
    required this.copyLabel,
    this.copyText,
    this.style,
    this.maxLines,
    this.overflow,
    super.key,
  });

  final String text;
  final String copyLabel;
  final String? copyText;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  State<CopyableText> createState() => _CopyableTextState();
}

class _CopyableTextState extends State<CopyableText> {
  @override
  void dispose() {
    hideActiveCopyOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => hideActiveCopyOverlay(),
      onLongPress: _showCopyOverlay,
      child: Text(
        widget.text,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
        style: widget.style,
      ),
    );
  }

  void _showCopyOverlay() {
    hideActiveCopyOverlay();

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return;
    }

    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (overlayBox == null || !overlayBox.hasSize) {
      return;
    }

    final targetTopLeft = renderBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final targetSize = renderBox.size;
    final textWidth = _visibleTextWidth(context, maxWidth: targetSize.width);
    final anchorWidth = textWidth.clamp(0.0, targetSize.width);
    final overlaySize = overlayBox.size;
    const buttonWidth = 82.0;
    const buttonHeight = 42.0;
    final top = (targetTopLeft.dy - buttonHeight - 6).clamp(
      8.0,
      overlaySize.height - buttonHeight - 8,
    );
    final left = (targetTopLeft.dx + (anchorWidth - buttonWidth) / 2).clamp(
      8.0,
      overlaySize.width - buttonWidth - 8,
    );

    _activeCopyOverlay = OverlayEntry(
      builder: (overlayContext) => _CopyOverlay(
        left: left,
        top: top,
        onDismiss: hideActiveCopyOverlay,
        onCopy: () {
          hideActiveCopyOverlay();
          copyValue(value: widget.copyText ?? widget.text);
        },
      ),
    );
    overlay.insert(_activeCopyOverlay!);
  }

  double _visibleTextWidth(BuildContext context, {required double maxWidth}) {
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final defaultStyle = DefaultTextStyle.of(context);
    final painter = TextPainter(
      text: TextSpan(
        text: widget.text,
        style: defaultStyle.style.merge(widget.style),
      ),
      maxLines: widget.maxLines,
      textDirection: direction,
      ellipsis: widget.overflow == TextOverflow.ellipsis ? '...' : null,
    )..layout(maxWidth: maxWidth);
    return painter.width;
  }
}

class _CopyOverlay extends StatelessWidget {
  const _CopyOverlay({
    required this.left,
    required this.top,
    required this.onDismiss,
    required this.onCopy,
  });

  final double left;
  final double top;
  final VoidCallback onDismiss;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => onDismiss(),
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) {},
            child: Material(
              color: Colors.transparent,
              child: FilledButton.tonalIcon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: const Text('复制'),
                style: FilledButton.styleFrom(
                  fixedSize: const Size(82, 42),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

void hideActiveCopyOverlay() {
  _activeCopyOverlay?.remove();
  _activeCopyOverlay = null;
}

Future<void> copyValue({required String value}) async {
  await Clipboard.setData(ClipboardData(text: value));
}

class _CopyOverlayNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    hideActiveCopyOverlay();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    hideActiveCopyOverlay();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    hideActiveCopyOverlay();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    hideActiveCopyOverlay();
  }

  @override
  void didStartUserGesture(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    hideActiveCopyOverlay();
  }
}
