import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  OverlayEntry? _copyOverlay;

  @override
  void dispose() {
    _hideCopyOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _hideCopyOverlay,
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
    _hideCopyOverlay();

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
    final overlaySize = overlayBox.size;
    final top = (targetTopLeft.dy - 44).clamp(8.0, overlaySize.height - 48);
    final left = (targetTopLeft.dx + targetSize.width - 72).clamp(
      8.0,
      overlaySize.width - 80,
    );

    _copyOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hideCopyOverlay,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: Material(
                color: Colors.transparent,
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    _hideCopyOverlay();
                    copyValue(value: widget.copyText ?? widget.text);
                  },
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  label: const Text('复制'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(_copyOverlay!);
  }

  void _hideCopyOverlay() {
    _copyOverlay?.remove();
    _copyOverlay = null;
  }
}

Future<void> copyValue({required String value}) async {
  await Clipboard.setData(ClipboardData(text: value));
}
