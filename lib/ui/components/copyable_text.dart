import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../app/toast.dart';
import '../design/theme.dart';

/// Copies [value] to the clipboard and shows the 「已复制」 toast (with
/// [label], e.g. 「点位名称」, as the message).
Future<void> copyToClipboard(
  BuildContext context,
  String value, {
  String? label,
}) async {
  final toasts = Provider.of<ToastController?>(context, listen: false);
  await Clipboard.setData(ClipboardData(text: value));
  unawaited(HapticFeedback.selectionClick());
  toasts?.show(
    ToastData(kind: ToastKind.success, title: '已复制', message: label),
  );
}

OverlayEntry? _activeBubble;
Timer? _bubbleTimer;

/// Hides the floating 「复制」 bubble if one is showing.
void hideCopyBubble() {
  _bubbleTimer?.cancel();
  _bubbleTimer = null;
  _activeBubble?.remove();
  _activeBubble = null;
}

/// Shows the old floating 「复制」 bubble above the widget of [context].
/// Tapping it copies [value]; tapping anywhere else dismisses it.
void showCopyBubble(
  BuildContext context, {
  required String value,
  String? label,
}) {
  hideCopyBubble();
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final box = context.findRenderObject() as RenderBox?;
  final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
  if (overlay == null ||
      box == null ||
      !box.hasSize ||
      overlayBox == null ||
      !overlayBox.hasSize) {
    return;
  }
  final topLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
  final bounds = overlayBox.size;
  const width = 92.0;
  const height = 44.0;
  final top = (topLeft.dy - height - 6).clamp(8.0, bounds.height - height - 8);
  final left = (topLeft.dx + box.size.width / 2 - width / 2).clamp(
    8.0,
    bounds.width - width - 8,
  );
  HapticFeedback.selectionClick();
  final entry = OverlayEntry(
    builder: (overlayContext) => Stack(
      children: [
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => hideCopyBubble(),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: _CopyBubble(
            onCopy: () {
              hideCopyBubble();
              copyToClipboard(context, value, label: label);
            },
          ),
        ),
      ],
    ),
  );
  _activeBubble = entry;
  overlay.insert(entry);
  _bubbleTimer = Timer(const Duration(seconds: 4), hideCopyBubble);
}

class _CopyBubble extends StatelessWidget {
  const _CopyBubble({required this.onCopy});

  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {},
      child: Material(
        color: c.textPrimary,
        borderRadius: Radii.pillAll,
        elevation: 0,
        child: InkWell(
          borderRadius: Radii.pillAll,
          onTap: onCopy,
          autofocus: true,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Symbols.content_copy_rounded, size: 16, color: c.surface),
                const SizedBox(width: 6),
                Text(
                  '复制',
                  style: context.text.labelLarge?.copyWith(color: c.surface),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Text that can be copied with a long press (old `CopyableText`): a
/// floating 「复制」 bubble appears; tapping it copies [copyText] (or
/// [text]) and shows 「已复制」. Right click does the same on desktop.
///
/// ```dart
/// CopyableText(
///   text: point.name,
///   copyLabel: '点位名称',
///   locale: MiriaFonts.japanese,
///   style: context.text.titleMedium,
/// )
/// ```
class CopyableText extends StatefulWidget {
  const CopyableText({
    required this.text,
    required this.copyLabel,
    this.copyText,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.locale,
    this.onTap,
    super.key,
  });

  final String text;

  /// What is being copied (「点位名称」); shown in the toast and announced.
  final String copyLabel;

  /// Value to copy when different from the visible [text].
  final String? copyText;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  /// e.g. `MiriaFonts.japanese` for place names.
  final Locale? locale;
  final VoidCallback? onTap;

  @override
  State<CopyableText> createState() => _CopyableTextState();
}

class _CopyableTextState extends State<CopyableText> {
  bool _bubbleOwner = false;

  @override
  void dispose() {
    if (_bubbleOwner) hideCopyBubble();
    super.dispose();
  }

  void _show() {
    _bubbleOwner = true;
    showCopyBubble(
      context,
      value: widget.copyText ?? widget.text,
      label: widget.copyLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: '复制${widget.copyLabel}'): () =>
            copyToClipboard(
              context,
              widget.copyText ?? widget.text,
              label: widget.copyLabel,
            ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: _show,
        onSecondaryTap: _show,
        child: Text(
          widget.text,
          style: widget.style,
          maxLines: widget.maxLines,
          overflow: widget.overflow,
          textAlign: widget.textAlign,
          locale: widget.locale,
        ),
      ),
    );
  }
}
