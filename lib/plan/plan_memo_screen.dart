import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../widgets/snackbar_helper.dart';
import 'pilgrimage_plan_controller.dart';

class PlanMemoScreen extends StatefulWidget {
  const PlanMemoScreen({required this.controller, super.key});

  final PilgrimagePlanController controller;

  @override
  State<PlanMemoScreen> createState() => _PlanMemoScreenState();
}

class _PlanMemoScreenState extends State<PlanMemoScreen> {
  late final TextEditingController _memoController;
  var _isEditing = false;
  var _isSaving = false;
  var _isTogglingTask = false;
  var _isUpdatingMemoText = false;

  String get _savedMemo => widget.controller.plan.memo;

  bool get _hasUnsavedChanges => _memoController.text != _savedMemo;

  @override
  void initState() {
    super.initState();
    _memoController = TextEditingController(text: _savedMemo);
    _memoController.addListener(_handleMemoTextChanged);
    widget.controller.addListener(_handlePlanUpdated);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handlePlanUpdated);
    _memoController.removeListener(_handleMemoTextChanged);
    _memoController.dispose();
    super.dispose();
  }

  void _handleMemoTextChanged() {
    if (_isEditing && mounted && !_isUpdatingMemoText) {
      setState(() {});
    }
  }

  void _setMemoText(String text) {
    _isUpdatingMemoText = true;
    _memoController.text = text;
    _isUpdatingMemoText = false;
  }

  void _handlePlanUpdated() {
    if (_isEditing || _memoController.text == _savedMemo) {
      return;
    }
    setState(() {
      _setMemoText(_savedMemo);
    });
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_isEditing || !_hasUnsavedChanges) {
      return true;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃未保存内容？'),
        content: const Text('当前备忘录还有未保存的修改。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _handleBack() async {
    if (!await _confirmDiscardChanges()) {
      return;
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
  }

  Future<void> _cancelEditing() async {
    if (!await _confirmDiscardChanges()) {
      return;
    }
    setState(() {
      _setMemoText(_savedMemo);
      _isEditing = false;
    });
  }

  Future<void> _saveMemo() async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      await widget.controller.updatePlanMemo(_memoController.text);
      if (!mounted) {
        return;
      }
      setState(() {
        _isEditing = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showReplacingSnackBar(const SnackBar(content: Text('计划备忘录已保存')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showReplacingSnackBar(const SnackBar(content: Text('计划备忘录保存失败')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _toggleTaskItem(int taskIndex) async {
    if (_isTogglingTask) {
      return;
    }
    final currentMemo = _savedMemo;
    final toggledMemo = _toggleMarkdownTask(currentMemo, taskIndex);
    if (toggledMemo == currentMemo) {
      return;
    }
    setState(() {
      _isTogglingTask = true;
      _setMemoText(toggledMemo);
    });
    try {
      await widget.controller.updatePlanMemo(toggledMemo);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _setMemoText(currentMemo);
      });
      ScaffoldMessenger.of(
        context,
      ).showReplacingSnackBar(const SnackBar(content: Text('待办状态保存失败')));
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingTask = false;
        });
      }
    }
  }

  String _toggleMarkdownTask(String source, int targetTaskIndex) {
    var currentTaskIndex = 0;
    final lines = source.split('\n');
    for (var index = 0; index < lines.length; index++) {
      final match = _taskLinePattern.firstMatch(lines[index]);
      if (match == null) {
        continue;
      }
      if (currentTaskIndex != targetTaskIndex) {
        currentTaskIndex++;
        continue;
      }
      final marker = match.namedGroup('mark') ?? ' ';
      final nextMarker = marker.trim().isEmpty ? 'x' : ' ';
      final markerOffset =
          match.start + (match.namedGroup('prefix') ?? '').length;
      lines[index] = lines[index].replaceRange(
        markerOffset,
        markerOffset + 1,
        nextMarker,
      );
      return lines.join('\n');
    }
    return source;
  }

  void _applyMarkdownAction(_MarkdownAction action) {
    switch (action) {
      case _MarkdownAction.heading:
        _applyLinePrefix('## ', placeholder: '标题');
      case _MarkdownAction.bold:
        _wrapSelection('**', '**', placeholder: '加粗文字');
      case _MarkdownAction.list:
        _applyLinePrefix('- ', placeholder: '列表项');
      case _MarkdownAction.task:
        _applyLinePrefix('- [ ] ', placeholder: '待办事项');
      case _MarkdownAction.quote:
        _applyLinePrefix('> ', placeholder: '引用内容');
      case _MarkdownAction.divider:
        _insertDivider();
      case _MarkdownAction.link:
        _insertLink();
      case _MarkdownAction.code:
        _insertCode();
    }
  }

  TextSelection get _effectiveSelection {
    final selection = _memoController.selection;
    final textLength = _memoController.text.length;
    if (!selection.isValid) {
      return TextSelection.collapsed(offset: textLength);
    }
    return TextSelection(
      baseOffset: selection.start.clamp(0, textLength),
      extentOffset: selection.end.clamp(0, textLength),
    );
  }

  void _replaceSelection(
    String replacement, {
    int? selectionStartInReplacement,
    int? selectionEndInReplacement,
  }) {
    final selection = _effectiveSelection;
    final text = _memoController.text;
    final nextText = text.replaceRange(
      selection.start,
      selection.end,
      replacement,
    );
    final nextSelectionStart =
        selection.start + (selectionStartInReplacement ?? replacement.length);
    final nextSelectionEnd =
        selection.start + (selectionEndInReplacement ?? nextSelectionStart);
    _memoController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection(
        baseOffset: nextSelectionStart.clamp(0, nextText.length),
        extentOffset: nextSelectionEnd.clamp(0, nextText.length),
      ),
    );
  }

  void _wrapSelection(
    String before,
    String after, {
    required String placeholder,
  }) {
    final selection = _effectiveSelection;
    final selected = _memoController.text.substring(
      selection.start,
      selection.end,
    );
    final content = selected.isEmpty ? placeholder : selected;
    _replaceSelection(
      '$before$content$after',
      selectionStartInReplacement: selected.isEmpty ? before.length : null,
      selectionEndInReplacement: selected.isEmpty
          ? before.length + content.length
          : null,
    );
  }

  void _applyLinePrefix(String prefix, {required String placeholder}) {
    final selection = _effectiveSelection;
    final selected = _memoController.text.substring(
      selection.start,
      selection.end,
    );
    if (selected.isEmpty) {
      _replaceSelection(
        '$prefix$placeholder',
        selectionStartInReplacement: prefix.length,
        selectionEndInReplacement: prefix.length + placeholder.length,
      );
      return;
    }
    final replacement = selected
        .split('\n')
        .map((line) => line.trim().isEmpty ? line : '$prefix$line')
        .join('\n');
    _replaceSelection(replacement);
  }

  void _insertDivider() {
    final selection = _effectiveSelection;
    final text = _memoController.text;
    final needsLeadingBreak =
        selection.start > 0 &&
        !text.substring(0, selection.start).endsWith('\n');
    final needsTrailingBreak =
        selection.end < text.length &&
        !text.substring(selection.end).startsWith('\n');
    final replacement =
        '${needsLeadingBreak ? '\n' : ''}---${needsTrailingBreak ? '\n' : ''}';
    _replaceSelection(replacement);
  }

  void _insertLink() {
    final selection = _effectiveSelection;
    final selected = _memoController.text.substring(
      selection.start,
      selection.end,
    );
    final label = selected.isEmpty ? '链接文字' : selected;
    final replacement = '[$label](https://example.com)';
    final urlStart = label.length + 3;
    _replaceSelection(
      replacement,
      selectionStartInReplacement: selected.isEmpty ? 1 : urlStart,
      selectionEndInReplacement: selected.isEmpty
          ? 1 + label.length
          : replacement.length - 1,
    );
  }

  void _insertCode() {
    final selection = _effectiveSelection;
    final selected = _memoController.text.substring(
      selection.start,
      selection.end,
    );
    if (selected.contains('\n')) {
      _replaceSelection('```\n$selected\n```');
      return;
    }
    _wrapSelection('`', '`', placeholder: '代码');
  }

  Future<void> _openMarkdownLink(String? href) async {
    if (href == null || href.trim().isEmpty) {
      return;
    }
    final uri = Uri.tryParse(href.trim());
    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(
        context,
      ).showReplacingSnackBar(const SnackBar(content: Text('链接格式不正确')));
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || opened) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showReplacingSnackBar(const SnackBar(content: Text('无法打开链接')));
  }

  @override
  Widget build(BuildContext context) {
    final memo = _memoController.text.trim();
    return PopScope(
      canPop: !_isEditing || !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '返回',
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: const Text('计划备忘录'),
          actions: [
            if (_isEditing) ...[
              TextButton(
                onPressed: _isSaving ? null : _cancelEditing,
                child: const Text('取消'),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveMemo,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('保存'),
                ),
              ),
            ] else
              IconButton(
                tooltip: '编辑',
                onPressed: _startEditing,
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: _isEditing
                ? Column(
                    children: [
                      _MarkdownToolbar(onAction: _applyMarkdownAction),
                      const SizedBox(height: 12),
                      Expanded(
                        child: TextField(
                          controller: _memoController,
                          autofocus: true,
                          expands: true,
                          maxLines: null,
                          minLines: null,
                          keyboardType: TextInputType.multiline,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            labelText: '备忘录内容',
                            alignLabelWithHint: true,
                            hintText: '可以记录交通、预约、补拍事项、同行安排等。',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  )
                : memo.isEmpty
                ? const _EmptyPlanMemo()
                : _PlanMemoMarkdownPreview(
                    data: _savedMemo,
                    onTapLink: _openMarkdownLink,
                    onToggleTask: _toggleTaskItem,
                  ),
          ),
        ),
      ),
    );
  }
}

final _taskLinePattern = RegExp(
  r'^(?<prefix>\s*(?:[-*+]|\d+[.)])\s+\[)(?<mark>[ xX])(?<suffix>\]\s+.*)$',
);

enum _MarkdownAction { heading, bold, list, task, quote, divider, link, code }

class _MarkdownToolbar extends StatelessWidget {
  const _MarkdownToolbar({required this.onAction});

  final ValueChanged<_MarkdownAction> onAction;

  @override
  Widget build(BuildContext context) {
    const tools = [
      _MarkdownToolSpec(
        action: _MarkdownAction.heading,
        icon: Icons.title,
        tooltip: '标题',
      ),
      _MarkdownToolSpec(
        action: _MarkdownAction.bold,
        icon: Icons.format_bold,
        tooltip: '加粗',
      ),
      _MarkdownToolSpec(
        action: _MarkdownAction.list,
        icon: Icons.format_list_bulleted,
        tooltip: '列表',
      ),
      _MarkdownToolSpec(
        action: _MarkdownAction.task,
        icon: Icons.check_box_outlined,
        tooltip: '待办',
      ),
      _MarkdownToolSpec(
        action: _MarkdownAction.quote,
        icon: Icons.format_quote,
        tooltip: '引用',
      ),
      _MarkdownToolSpec(
        action: _MarkdownAction.divider,
        icon: Icons.horizontal_rule,
        tooltip: '分割线',
      ),
      _MarkdownToolSpec(
        action: _MarkdownAction.link,
        icon: Icons.link,
        tooltip: '链接',
      ),
      _MarkdownToolSpec(
        action: _MarkdownAction.code,
        icon: Icons.code,
        tooltip: '代码',
      ),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final tool in tools) ...[
              Tooltip(
                message: tool.tooltip,
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onAction(tool.action),
                    icon: Icon(tool.icon, size: 20),
                  ),
                ),
              ),
              if (tool != tools.last) const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _MarkdownToolSpec {
  const _MarkdownToolSpec({
    required this.action,
    required this.icon,
    required this.tooltip,
  });

  final _MarkdownAction action;
  final IconData icon;
  final String tooltip;
}

class _PlanMemoMarkdownPreview extends StatelessWidget {
  const _PlanMemoMarkdownPreview({
    required this.data,
    required this.onTapLink,
    required this.onToggleTask,
  });

  final String data;
  final ValueChanged<String?> onTapLink;
  final ValueChanged<int> onToggleTask;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: MarkdownBody(
        data: _escapeHtmlBlocks(data),
        selectable: true,
        softLineBreak: true,
        listItemCrossAxisAlignment: MarkdownListItemCrossAxisAlignment.start,
        styleSheet: _markdownStyleSheet(context),
        onTapLink: (_, href, _) => onTapLink(href),
        checkboxBuilder: _TaskCheckboxBuilder(onToggleTask: onToggleTask).build,
        bulletBuilder: _buildMarkdownBullet,
        imageBuilder: (uri, title, alt) => _UnsupportedMarkdownImage(
          label: alt?.trim().isNotEmpty == true ? alt!.trim() : uri.toString(),
        ),
      ),
    );
  }

  static String _escapeHtmlBlocks(String source) {
    return source
        .split('\n')
        .map((line) {
          final quoteMatch = RegExp(
            r'^(?<marker>\s*>+\s?)(?<content>.*)$',
          ).firstMatch(line);
          if (quoteMatch != null) {
            return '${quoteMatch.namedGroup('marker') ?? ''}${_escapeHtml(quoteMatch.namedGroup('content') ?? '')}';
          }
          return _escapeHtml(line);
        })
        .join('\n');
  }

  static String _escapeHtml(String source) {
    return source.replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  }

  static MarkdownStyleSheet _markdownStyleSheet(BuildContext context) {
    final base = MarkdownStyleSheet.fromTheme(Theme.of(context));
    const paragraph = TextStyle(
      color: AppColors.textPrimary,
      fontSize: 16,
      height: 1.55,
      letterSpacing: 0,
    );
    return base.copyWith(
      a: TextStyle(
        color: AppColors.accentDark,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.55,
        letterSpacing: 0,
        decoration: TextDecoration.underline,
      ),
      p: paragraph,
      listBullet: paragraph.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
      listBulletPadding: EdgeInsets.zero,
      checkbox: TextStyle(color: AppColors.accentDark, fontSize: 24),
      h1: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w800,
        height: 1.25,
        letterSpacing: 0,
      ),
      h2: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 21,
        fontWeight: FontWeight.w800,
        height: 1.3,
        letterSpacing: 0,
      ),
      h3: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        height: 1.35,
        letterSpacing: 0,
      ),
      strong: const TextStyle(fontWeight: FontWeight.w800),
      blockSpacing: 10,
      blockquote: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 16,
        height: 1.55,
        letterSpacing: 0,
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      blockquoteDecoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        border: Border(left: BorderSide(color: AppColors.accentDark, width: 4)),
        borderRadius: BorderRadius.circular(8),
      ),
      code: const TextStyle(
        color: AppColors.textPrimary,
        backgroundColor: AppColors.surfaceMuted,
        fontSize: 14,
        height: 1.45,
        letterSpacing: 0,
      ),
      codeblockPadding: const EdgeInsets.all(12),
      codeblockDecoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      horizontalRuleDecoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
    );
  }
}

class _TaskCheckboxBuilder {
  _TaskCheckboxBuilder({required this.onToggleTask});

  final ValueChanged<int> onToggleTask;
  var _taskIndex = 0;

  Widget build(bool value) {
    final taskIndex = _taskIndex++;
    return Transform.translate(
      offset: Offset.zero,
      child: Tooltip(
        message: value ? '取消勾选' : '标记完成',
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => onToggleTask(taskIndex),
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(
              value ? Icons.check_box : Icons.check_box_outline_blank,
              size: 25,
              color: value ? AppColors.accentDark : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildMarkdownBullet(MarkdownBulletParameters parameters) {
  if (parameters.style == BulletStyle.orderedList) {
    return Transform.translate(
      offset: const Offset(0, 1),
      child: SizedBox(
        width: 28,
        child: Text(
          '${parameters.index + 1}.',
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            height: 1.45,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
  return Transform.translate(
    offset: const Offset(0, 4),
    child: const SizedBox(
      width: 20,
      height: 20,
      child: Center(
        child: Text(
          '•',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1,
            letterSpacing: 0,
          ),
        ),
      ),
    ),
  );
}

class _UnsupportedMarkdownImage extends StatelessWidget {
  const _UnsupportedMarkdownImage({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.image_not_supported_outlined, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '备忘录不支持图片：$label',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlanMemo extends StatelessWidget {
  const _EmptyPlanMemo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.sticky_note_2_outlined,
              color: AppColors.accentDark,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '还没有写计划备忘',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '点击右上角编辑，记录交通、预约、补拍事项或其他准备内容。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
