import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/plan/plan_memo_markdown.dart';

void main() {
  test('fenced examples do not shift real task indices', () {
    const source = '```md\n- [ ] example\n```\n\n- [ ] first\n- [x] second';
    expect(
      toggleMemoMarkdownTask(source, 0),
      source.replaceFirst('[ ] first', '[x] first'),
    );
    expect(
      toggleMemoMarkdownTask(source, 1),
      source.replaceFirst('[x] second', '[ ] second'),
    );
    expect(toggleMemoMarkdownTask(source, 2), source);
  });

  test('nested lists, quotations and repeated text retain source identity', () {
    const source = '- [ ] same\n  - [ ] same\n\n> - [X] same\n\n1. [ ] same';
    expect(
      toggleMemoMarkdownTask(source, 0),
      '- [ ] same\n  - [x] same\n\n> - [X] same\n\n1. [ ] same',
    );
    expect(
      toggleMemoMarkdownTask(source, 1),
      '- [x] same\n  - [ ] same\n\n> - [X] same\n\n1. [ ] same',
    );
    expect(
      toggleMemoMarkdownTask(source, 2),
      source.replaceFirst('[X]', '[ ]'),
    );
    expect(
      toggleMemoMarkdownTask(source, 3),
      source.replaceFirst('1. [ ]', '1. [x]'),
    );
  });

  test('indented and tilde fenced code remain unchanged', () {
    const source = '    - [ ] code\n\n~~~\n- [ ] code\n~~~\n\n- [ ] actual';
    expect(
      toggleMemoMarkdownTask(source, 0),
      source.replaceFirst('[ ] actual', '[x] actual'),
    );
    expect(toggleMemoMarkdownTask(source, -1), source);
  });

  test('unicode, CRLF, empty labels and inline code keep exact text', () {
    const source = '中文\r\n\r\n- [ ] \r\n- [ ] `**代码**`\r\n';
    expect(
      toggleMemoMarkdownTask(source, 0),
      source.replaceFirst('- [ ] ', '- [x] '),
    );
    expect(
      toggleMemoMarkdownTask(source, 1),
      source.replaceFirst('[ ] `', '[x] `'),
    );
  });

  test('annotations do not collide with user text or escape into output', () {
    const source = '- [ ] MiriagoTaskSourceMarker42EndMarker';
    expect(
      toggleMemoMarkdownTask(source, 0),
      '- [x] MiriagoTaskSourceMarker42EndMarker',
    );
  });

  test('loose task and nested code do not shift rendered task indices', () {
    const source =
        '- [ ] parent\n\n  ```\n  - [ ] example\n  ```\n\n---\n\n- [ ] next';
    expect(
      toggleMemoMarkdownTask(source, 0),
      source.replaceFirst('[ ] next', '[x] next'),
    );
    expect(toggleMemoMarkdownTask(source, 1), source);
  });
}
