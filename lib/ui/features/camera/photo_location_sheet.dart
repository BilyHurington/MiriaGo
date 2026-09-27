import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../plan/pilgrimage_models.dart';
import '../../components/components.dart';

/// 「是否在巡礼照片中记录定位？」 — bottom sheet on phones, dialog otherwise.
/// Closing without a choice returns null (= no location for this photo).
Future<PhotoLocationStrategy?> showPhotoLocationChoiceSheet(
  BuildContext context,
) {
  return showAdaptiveSheet<PhotoLocationStrategy>(
    context,
    title: '是否在巡礼照片中记录定位？',
    builder: (context) => const PhotoLocationChoiceContent(),
  );
}

/// Body of the location choice sheet (old `PhotoLocationChoiceSheet`).
class PhotoLocationChoiceContent extends StatelessWidget {
  const PhotoLocationChoiceContent({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hint = context.text.bodyMedium?.copyWith(color: c.textSecondary);
    return Column(
      key: const ValueKey('photo-location-choice-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('以后可以在“拍摄设置”中修改。', style: hint),
        Text('不会使用点位坐标代替实际定位。', style: hint),
        const SizedBox(height: Space.x4),
        _ChoiceTile(
          key: const ValueKey('photo-location-choice-recent'),
          icon: Symbols.history_rounded,
          title: '使用最近一次定位',
          subtitle: '优先快速写入近期有效定位，没有时获取一次。',
          onTap: () => Navigator.of(
            context,
          ).pop(PhotoLocationStrategy.useRecentLocation),
        ),
        const SizedBox(height: Space.x2),
        _ChoiceTile(
          key: const ValueKey('photo-location-choice-confirm'),
          icon: Symbols.my_location_rounded,
          title: '确认记录时获取定位',
          subtitle: '拍摄后在确认页面等待新定位，适合需要更准确位置时。',
          recommended: true,
          onTap: () => Navigator.of(
            context,
          ).pop(PhotoLocationStrategy.waitOnConfirmation),
        ),
        const SizedBox(height: Space.x2),
        _ChoiceTile(
          key: const ValueKey('photo-location-choice-disabled'),
          icon: Symbols.location_off_rounded,
          title: '不记录定位',
          onTap: () =>
              Navigator.of(context).pop(PhotoLocationStrategy.disabled),
        ),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.recommended = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MiriaCard(
      onTap: onTap,
      semanticLabel: title,
      padding: const EdgeInsets.all(Space.x3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c.textPrimary),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: Space.x2,
                  runSpacing: Space.x1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(title, style: context.text.titleSmall),
                    if (recommended)
                      const Tag(label: '推荐', tone: MiriaTone.primary),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: Space.x1),
                  Text(
                    subtitle!,
                    style: context.text.bodySmall?.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
