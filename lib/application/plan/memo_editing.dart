import 'package:flutter/services.dart';

/// The eight toolbar actions of the memo editor (old `_MarkdownAction`).
enum MemoMarkdownAction {
  heading('标题'),
  bold('加粗'),
  list('列表'),
  task('待办'),
  quote('引用'),
  divider('分割线'),
  link('链接'),
  code('代码');

  const MemoMarkdownAction(this.label);

  /// Tooltip / accessible label.
  final String label;
}

/// Applies a toolbar [action] to the editor [value] and returns the new
/// text and selection. Ported line by line from the old
/// `PlanMemoScreen._applyMarkdownAction`.
TextEditingValue applyMemoMarkdownAction(
  TextEditingValue value,
  MemoMarkdownAction action,
) {
  final editor = _MemoEdit(value);
  switch (action) {
    case MemoMarkdownAction.heading:
      editor.applyLinePrefix('## ', placeholder: '标题');
    case MemoMarkdownAction.bold:
      editor.wrapSelection('**', '**', placeholder: '加粗文字');
    case MemoMarkdownAction.list:
      editor.applyLinePrefix('- ', placeholder: '列表项');
    case MemoMarkdownAction.task:
      editor.applyLinePrefix('- [ ] ', placeholder: '待办事项');
    case MemoMarkdownAction.quote:
      editor.applyLinePrefix('> ', placeholder: '引用内容');
    case MemoMarkdownAction.divider:
      editor.insertDivider();
    case MemoMarkdownAction.link:
      editor.insertLink();
    case MemoMarkdownAction.code:
      editor.insertCode();
  }
  return editor.value;
}

class _MemoEdit {
  _MemoEdit(this.value);

  TextEditingValue value;

  String get _text => value.text;

  TextSelection get _selection {
    final selection = value.selection;
    final length = _text.length;
    if (!selection.isValid) return TextSelection.collapsed(offset: length);
    return TextSelection(
      baseOffset: selection.start.clamp(0, length),
      extentOffset: selection.end.clamp(0, length),
    );
  }

  String get _selected {
    final selection = _selection;
    return _text.substring(selection.start, selection.end);
  }

  void replaceSelection(
    String replacement, {
    int? selectionStartInReplacement,
    int? selectionEndInReplacement,
  }) {
    final selection = _selection;
    final nextText = _text.replaceRange(
      selection.start,
      selection.end,
      replacement,
    );
    final nextStart =
        selection.start + (selectionStartInReplacement ?? replacement.length);
    final nextEnd = selection.start + (selectionEndInReplacement ?? nextStart);
    value = TextEditingValue(
      text: nextText,
      selection: TextSelection(
        baseOffset: nextStart.clamp(0, nextText.length),
        extentOffset: nextEnd.clamp(0, nextText.length),
      ),
    );
  }

  void wrapSelection(
    String before,
    String after, {
    required String placeholder,
  }) {
    final selected = _selected;
    final content = selected.isEmpty ? placeholder : selected;
    replaceSelection(
      '$before$content$after',
      selectionStartInReplacement: selected.isEmpty ? before.length : null,
      selectionEndInReplacement: selected.isEmpty
          ? before.length + content.length
          : null,
    );
  }

  void applyLinePrefix(String prefix, {required String placeholder}) {
    final selected = _selected;
    if (selected.isEmpty) {
      replaceSelection(
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
    replaceSelection(replacement);
  }

  void insertDivider() {
    final selection = _selection;
    final needsLeadingBreak =
        selection.start > 0 &&
        !_text.substring(0, selection.start).endsWith('\n');
    final needsTrailingBreak =
        selection.end < _text.length &&
        !_text.substring(selection.end).startsWith('\n');
    replaceSelection(
      '${needsLeadingBreak ? '\n' : ''}---${needsTrailingBreak ? '\n' : ''}',
    );
  }

  void insertLink() {
    final selected = _selected;
    final label = selected.isEmpty ? '链接文字' : selected;
    final replacement = '[$label](https://example.com)';
    final urlStart = label.length + 3;
    replaceSelection(
      replacement,
      selectionStartInReplacement: selected.isEmpty ? 1 : urlStart,
      selectionEndInReplacement: selected.isEmpty
          ? 1 + label.length
          : replacement.length - 1,
    );
  }

  void insertCode() {
    final selected = _selected;
    if (selected.contains('\n')) {
      replaceSelection('```\n$selected\n```');
      return;
    }
    wrapSelection('`', '`', placeholder: '代码');
  }
}
