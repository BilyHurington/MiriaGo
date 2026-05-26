import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CopyableText extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () =>
          copyValue(context, label: copyLabel, value: copyText ?? text),
      child: Text(text, maxLines: maxLines, overflow: overflow, style: style),
    );
  }
}

Future<void> copyValue(
  BuildContext context, {
  required String label,
  required String value,
}) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('已复制：$label')));
}
