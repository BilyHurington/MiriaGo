import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AppBackButton extends StatelessWidget {
  const AppBackButton({this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox.square(
        dimension: 40,
        child: IconButton(
          onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(LucideIcons.arrowLeft, semanticLabel: '返回'),
        ),
      ),
    );
  }
}

Widget? appBackButtonIfCanPop(BuildContext context) {
  return ModalRoute.of(context)?.canPop == true ? const AppBackButton() : null;
}
