import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/application/plan/memo_editing.dart';

TextEditingValue _value(String text, int start, [int? end]) => TextEditingValue(
  text: text,
  selection: TextSelection(baseOffset: start, extentOffset: end ?? start),
);

String _selected(TextEditingValue value) =>
    value.text.substring(value.selection.start, value.selection.end);

void main() {
  test('heading with no selection inserts a selected placeholder', () {
    final result = applyMemoMarkdownAction(
      _value('', 0),
      MemoMarkdownAction.heading,
    );
    expect(result.text, '## 标题');
    expect(_selected(result), '标题');
  });

  test('line prefixes apply to every non-blank selected line', () {
    final result = applyMemoMarkdownAction(
      _value('a\n\nb', 0, 4),
      MemoMarkdownAction.task,
    );
    expect(result.text, '- [ ] a\n\n- [ ] b');
    expect(result.selection.isCollapsed, isTrue);
  });

  test('list and quote prefixes', () {
    expect(
      applyMemoMarkdownAction(_value('x', 0, 1), MemoMarkdownAction.list).text,
      '- x',
    );
    expect(
      applyMemoMarkdownAction(_value('', 0), MemoMarkdownAction.quote).text,
      '> 引用内容',
    );
  });

  test('bold wraps the selection or a placeholder', () {
    final placeholder = applyMemoMarkdownAction(
      _value('ab', 1),
      MemoMarkdownAction.bold,
    );
    expect(placeholder.text, 'a**加粗文字**b');
    expect(_selected(placeholder), '加粗文字');
    final wrapped = applyMemoMarkdownAction(
      _value('hello', 0, 5),
      MemoMarkdownAction.bold,
    );
    expect(wrapped.text, '**hello**');
  });

  test('divider adds line breaks only where needed', () {
    expect(
      applyMemoMarkdownAction(_value('ab', 1), MemoMarkdownAction.divider).text,
      'a\n---\nb',
    );
    expect(
      applyMemoMarkdownAction(_value('', 0), MemoMarkdownAction.divider).text,
      '---',
    );
    expect(
      applyMemoMarkdownAction(
        _value('a\n', 2),
        MemoMarkdownAction.divider,
      ).text,
      'a\n---',
    );
  });

  test('link selects the label placeholder or the url', () {
    final empty = applyMemoMarkdownAction(
      _value('', 0),
      MemoMarkdownAction.link,
    );
    expect(empty.text, '[链接文字](https://example.com)');
    expect(_selected(empty), '链接文字');
    final labelled = applyMemoMarkdownAction(
      _value('官网', 0, 2),
      MemoMarkdownAction.link,
    );
    expect(labelled.text, '[官网](https://example.com)');
    expect(_selected(labelled), 'https://example.com');
  });

  test('code uses inline code or a fenced block for multi-line text', () {
    expect(
      applyMemoMarkdownAction(_value('', 0), MemoMarkdownAction.code).text,
      '`代码`',
    );
    expect(
      applyMemoMarkdownAction(
        _value('a\nb', 0, 3),
        MemoMarkdownAction.code,
      ).text,
      '```\na\nb\n```',
    );
  });

  test('an invalid selection appends at the end', () {
    final result = applyMemoMarkdownAction(
      const TextEditingValue(text: 'x'),
      MemoMarkdownAction.bold,
    );
    expect(result.text, 'x**加粗文字**');
  });
}
