import 'package:flutter/material.dart';

class ClearAnchorSelectionButton extends StatelessWidget {
  const ClearAnchorSelectionButton({required this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '清除选点',
      onPressed: onPressed,
      icon: const Icon(Icons.clear),
    );
  }
}
