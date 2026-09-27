import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../application/add/add_dependencies.dart';
import '../../app/toast.dart';
import '../../components/components.dart';

/// Shows a service notice as a toast.
void showAddNotice(BuildContext context, AddNotice notice) {
  if (!context.mounted) return;
  context.showToast(
    notice.title,
    kind: switch (notice.kind) {
      AddNoticeKind.running => ToastKind.running,
      AddNoticeKind.success => ToastKind.success,
      AddNoticeKind.warning => ToastKind.warning,
      AddNoticeKind.error => ToastKind.error,
    },
    duration: notice.duration,
  );
}

/// A bordered form section (old `_FormSection`).
class AddFormSection extends StatelessWidget {
  const AddFormSection({required this.children, this.title, super.key});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.x4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Radii.mdAll,
        border: Border.all(color: c.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(title!, style: context.text.titleSmall),
            const SizedBox(height: Space.x3),
          ],
          ...children,
        ],
      ),
    );
  }
}

/// One step of a filling guide (old `_FillingGuideItem`).
class FillingGuideItem {
  const FillingGuideItem({
    required this.title,
    required this.badge,
    required this.body,
    required this.example,
  });

  final String title;
  final String badge;
  final String body;
  final String example;
}

/// The old 「填写指南」 dialogs, rendered as an in-form collapsible
/// explanation (DESIGN §8.11).
class FillingGuide extends StatefulWidget {
  const FillingGuide({
    required this.title,
    required this.intro,
    required this.items,
    required this.tip,
    this.tipIcon = Symbols.lightbulb_rounded,
    this.initiallyExpanded = false,
    super.key,
  });

  final String title;
  final String intro;
  final List<FillingGuideItem> items;
  final String tip;
  final IconData tipIcon;
  final bool initiallyExpanded;

  @override
  State<FillingGuide> createState() => _FillingGuideState();
}

class _FillingGuideState extends State<FillingGuide> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Radii.mdAll,
        border: Border.all(color: c.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MiriaPressable(
            onTap: () => setState(() => _expanded = !_expanded),
            semanticLabel: widget.title,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.x4,
                  vertical: Space.x3,
                ),
                child: Row(
                  children: [
                    Icon(Symbols.menu_book_rounded, size: 20, color: c.primary),
                    const SizedBox(width: Space.x2),
                    Expanded(child: Text(widget.title, style: text.titleSmall)),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: Motion.of(context, Motion.standard),
                      child: Icon(
                        Symbols.expand_more_rounded,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: Motion.of(context, Motion.standard),
            curve: Motion.emphasized,
            alignment: Alignment.topCenter,
            child: !_expanded
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.x4,
                      0,
                      Space.x4,
                      Space.x4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.intro,
                          style: text.bodySmall?.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                        const SizedBox(height: Space.x4),
                        for (var i = 0; i < widget.items.length; i++)
                          _GuideStep(
                            index: i + 1,
                            item: widget.items[i],
                            isLast: i == widget.items.length - 1,
                          ),
                        Container(
                          padding: const EdgeInsets.all(Space.x3),
                          decoration: BoxDecoration(
                            color: c.primaryContainer.withValues(alpha: 0.5),
                            borderRadius: Radii.smAll,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                widget.tipIcon,
                                size: 18,
                                color: c.primaryText,
                              ),
                              const SizedBox(width: Space.x2),
                              Expanded(
                                child: Text(
                                  widget.tip,
                                  style: text.bodySmall?.copyWith(
                                    color: c.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.index,
    required this.item,
    required this.isLast,
  });

  final int index;
  final FillingGuideItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final requiredBadge = item.badge != '选填';
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.primaryContainer,
            ),
            child: Text(
              '$index',
              style: text.labelMedium?.copyWith(
                color: c.onPrimaryContainer,
                fontFeatures: MiriaFonts.tabular,
              ),
            ),
          ),
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
                    Text(item.title, style: text.titleSmall),
                    Tag(
                      label: item.badge,
                      tone: requiredBadge
                          ? MiriaTone.primary
                          : MiriaTone.neutral,
                    ),
                  ],
                ),
                const SizedBox(height: Space.x1),
                Text(
                  item.body,
                  style: text.bodySmall?.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: Space.x1),
                Text(
                  '示例：${item.example}',
                  style: text.caption.copyWith(color: c.textTertiary),
                  locale: MiriaFonts.japanese,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Field label matching [MiriaTextField]'s (red `*` for required fields),
/// for inputs that have no built-in required marker.
class FieldLabel extends StatelessWidget {
  const FieldLabel(
    this.label, {
    this.required = false,
    this.trailing,
    super.key,
  });

  final String label;
  final bool required;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: label,
                children: [
                  if (required)
                    TextSpan(
                      text: ' *',
                      style: TextStyle(color: c.danger),
                      semanticsLabel: '（必填）',
                    ),
                ],
              ),
              style: context.text.labelMedium?.copyWith(
                color: c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
