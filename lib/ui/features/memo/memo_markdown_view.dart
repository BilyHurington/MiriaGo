import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../plan/plan_memo_markdown.dart';
import '../../components/components.dart';

/// GitHub-flavoured Markdown rendering of a plan memo (old
/// `_PlanMemoMarkdownPreview`): raw HTML escaped, selectable text, task
/// checkboxes that report their index, images shown as a placeholder.
class MemoMarkdownView extends StatelessWidget {
  const MemoMarkdownView({
    required this.data,
    required this.onTapLink,
    this.onToggleTask,
    super.key,
  });

  final String data;
  final ValueChanged<String?> onTapLink;

  /// Null renders the checkboxes read-only (live preview while editing).
  final ValueChanged<int>? onToggleTask;

  @override
  Widget build(BuildContext context) {
    final markdown = prepareMemoMarkdown(data);
    return MarkdownBody(
      data: markdown,
      selectable: true,
      softLineBreak: true,
      listItemCrossAxisAlignment: MarkdownListItemCrossAxisAlignment.start,
      styleSheet: _styleSheet(context),
      onTapLink: (_, href, _) => onTapLink(href),
      checkboxBuilder: _TaskCheckboxBuilder(
        colors: context.colors,
        onToggleTask: onToggleTask,
        taskCount: countRenderedMemoTaskCheckboxes(markdown),
      ).build,
      bulletBuilder: (parameters) => _bullet(context, parameters),
      imageBuilder: (uri, title, alt) => _UnsupportedImage(
        label: alt?.trim().isNotEmpty == true ? alt!.trim() : uri.toString(),
      ),
    );
  }

  static MarkdownStyleSheet _styleSheet(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final base = MarkdownStyleSheet.fromTheme(Theme.of(context));
    final paragraph = text.bodyLarge!.copyWith(
      color: c.textPrimary,
      height: 1.55,
    );
    return base.copyWith(
      a: paragraph.copyWith(
        color: c.primaryText,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
        decorationColor: c.primaryText,
      ),
      p: paragraph,
      listBullet: paragraph.copyWith(fontWeight: FontWeight.w700),
      listBulletPadding: EdgeInsets.zero,
      checkbox: paragraph.copyWith(color: c.primaryText),
      h1: text.headlineSmall?.copyWith(color: c.textPrimary, height: 1.25),
      h2: text.titleLarge?.copyWith(color: c.textPrimary, height: 1.3),
      h3: text.titleMedium?.copyWith(color: c.textPrimary, height: 1.35),
      h4: text.titleSmall?.copyWith(color: c.textPrimary),
      strong: const TextStyle(fontWeight: FontWeight.w700),
      blockSpacing: Space.x3 - 2,
      blockquote: paragraph.copyWith(color: c.textSecondary),
      blockquotePadding: const EdgeInsets.fromLTRB(
        Space.x3,
        Space.x2,
        Space.x3,
        Space.x2,
      ),
      blockquoteDecoration: BoxDecoration(
        color: c.surfaceMuted,
        border: Border(left: BorderSide(color: c.primary, width: 4)),
        borderRadius: Radii.xsAll,
      ),
      code: text.bodyMedium?.copyWith(
        color: c.textPrimary,
        backgroundColor: c.surfaceMuted,
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Menlo', 'Consolas', 'monospace'],
        height: 1.45,
      ),
      codeblockPadding: const EdgeInsets.all(Space.x3),
      codeblockDecoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: Radii.smAll,
        border: Border.all(color: c.hairline),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.hairline)),
      ),
      tableBorder: TableBorder.all(color: c.hairline),
      tableHead: text.titleSmall,
      tableBody: paragraph,
    );
  }

  static Widget _bullet(
    BuildContext context,
    MarkdownBulletParameters parameters,
  ) {
    final c = context.colors;
    final text = context.text;
    if (parameters.style == BulletStyle.orderedList) {
      return Container(
        width: 32,
        padding: const EdgeInsets.only(right: Space.x1 + 2),
        child: Text(
          '${parameters.index + 1}.',
          textAlign: TextAlign.right,
          style: text.bodyLarge?.copyWith(
            color: c.textPrimary,
            fontWeight: FontWeight.w700,
            height: 1.55,
            fontFeatures: MiriaFonts.tabular,
          ),
        ),
      );
    }
    return Transform.translate(
      offset: const Offset(0, 4),
      child: SizedBox(
        width: 20,
        height: 20,
        child: Center(
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: c.textPrimary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// The markdown widget may parse the same data more than once with one
/// builder (e.g. didUpdateWidget and didChangeDependencies in the same
/// frame), so the callback counter wraps per parse instead of growing past
/// the task count.
class _TaskCheckboxBuilder {
  _TaskCheckboxBuilder({
    required this.colors,
    required this.onToggleTask,
    required this.taskCount,
  });

  final MiriaColors colors;
  final ValueChanged<int>? onToggleTask;
  final int taskCount;
  var _buildCount = 0;

  Widget build(bool value) {
    final built = _buildCount++;
    final taskIndex = taskCount > 0 ? built % taskCount : built;
    final onToggle = onToggleTask;
    final icon = Icon(
      value
          ? Symbols.check_box_rounded
          : Symbols.check_box_outline_blank_rounded,
      size: 24,
      fill: value ? 1 : 0,
      color: value ? colors.primaryText : colors.textSecondary,
    );
    if (onToggle == null) {
      return Padding(
        padding: const EdgeInsets.only(right: Space.x1),
        child: SizedBox(width: 28, height: 28, child: Center(child: icon)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: Space.x1),
      child: Tooltip(
        message: value ? '取消勾选' : '标记完成',
        child: Semantics(
          checked: value,
          button: true,
          child: InkWell(
            key: ValueKey('memo-task-$taskIndex'),
            borderRadius: Radii.xsAll,
            onTap: () => onToggle(taskIndex),
            child: SizedBox(width: 28, height: 28, child: Center(child: icon)),
          ),
        ),
      ),
    );
  }
}

class _UnsupportedImage extends StatelessWidget {
  const _UnsupportedImage({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: Space.x2),
      padding: const EdgeInsets.all(Space.x3),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        border: Border.all(color: c.hairline),
        borderRadius: Radii.smAll,
      ),
      child: Row(
        children: [
          Icon(Symbols.hide_image_rounded, size: 20, color: c.textSecondary),
          const SizedBox(width: Space.x2),
          Expanded(
            child: Text(
              '备忘录不支持图片：$label',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(
                color: c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
