import 'dart:convert';

import 'package:markdown/markdown.dart' as md;

String prepareMemoMarkdown(String source) {
  String escape(String text) =>
      text.replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  return source
      .split('\n')
      .map((line) {
        final quote = RegExp(r'^(\s*>+\s?)(.*)$').firstMatch(line);
        return quote == null ? escape(line) : '${quote[1]}${escape(quote[2]!)}';
      })
      .join('\n');
}

String toggleMemoMarkdownTask(String source, int taskIndex) {
  if (taskIndex < 0) return source;
  final offsets = _taskMarkerOffsets(source);
  if (taskIndex >= offsets.length) return source;
  final offset = offsets[taskIndex];
  return source.replaceRange(
    offset,
    offset + 1,
    source[offset] == ' ' ? 'x' : ' ',
  );
}

List<int> _taskMarkerOffsets(String source) {
  var prefix = 'MiriagoTaskSourceMarker';
  while (source.contains(prefix)) {
    prefix += 'Z';
  }
  final candidate = RegExp(
    r'^([ \t]*(?:>[ \t]*)*(?:[-*+]|\d+[.)])[ \t]+\[)([ xX])(\][ \t]+)',
  );
  final candidates = <int>{};
  var offset = 0;
  final annotated = source
      .split('\n')
      .map((line) {
        final match = candidate.firstMatch(line);
        final lineOffset = offset;
        offset += line.length + 1;
        if (match == null) return line;
        final markerOffset = lineOffset + match[1]!.length;
        candidates.add(markerOffset);
        return '${line.substring(0, match.end)}$prefix${markerOffset}EndMarker ${line.substring(match.end)}';
      })
      .join('\n');

  // Annotate only the parsing copy. The same GFM parser as the preview decides
  // which candidates are checkboxes, excluding fenced/indented code examples.
  final nodes = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  ).parseLines(const LineSplitter().convert(prepareMemoMarkdown(annotated)));
  final marker = RegExp('^${RegExp.escape(prefix)}(\\d+)EndMarker(?:\\s|\$)');
  final offsets = <int>[];
  void visit(List<md.Node> nodes) {
    for (final node in nodes) {
      if (node is! md.Element) continue;
      final children = node.children;
      if (children == null || children.isEmpty) continue;
      visit(children);
      // flutter_markdown_plus builds each checkbox when leaving its li, after
      // nested items. Mirror that postorder, not the input node's source order.
      final first = children.first;
      if (node.tag != 'li' ||
          first is! md.Element ||
          first.attributes['type'] != 'checkbox') {
        continue;
      }
      final following = children.length > 1 ? children[1].textContent : '';
      final match = marker.firstMatch(following);
      final value = match == null ? null : int.tryParse(match[1]!);
      if (value != null && candidates.contains(value)) offsets.add(value);
    }
  }

  visit(nodes);
  return offsets;
}
