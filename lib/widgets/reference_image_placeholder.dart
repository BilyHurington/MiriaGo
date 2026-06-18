import 'package:flutter/material.dart';

import '../app_theme.dart';

enum ReferenceImagePlaceholderState { loading, unavailable, empty }

class ReferenceImagePlaceholder extends StatelessWidget {
  const ReferenceImagePlaceholder({
    this.state = ReferenceImagePlaceholderState.unavailable,
    this.compact = false,
    this.iconColor,
    super.key,
  });

  final ReferenceImagePlaceholderState state;
  final bool compact;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final label = switch (state) {
      ReferenceImagePlaceholderState.loading => '参考图加载中',
      ReferenceImagePlaceholderState.unavailable => '参考图暂不可用',
      ReferenceImagePlaceholderState.empty => '暂无参考图',
    };

    return ColoredBox(
      color: AppColors.surfaceMuted,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(compact ? 6 : 14),
          child: compact
              ? Icon(
                  Icons.image_outlined,
                  color: iconColor ?? AppColors.accentDark,
                  size: 28,
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state == ReferenceImagePlaceholderState.loading)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    else
                      Icon(
                        Icons.image_outlined,
                        color: iconColor ?? AppColors.accentDark,
                        size: 32,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
