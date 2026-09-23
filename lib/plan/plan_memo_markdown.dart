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
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      if (node is! md.Element) continue;
      if (node.tag == 'input' && node.attributes['type'] == 'checkbox') {
        final following = index + 1 < nodes.length
            ? nodes[index + 1].textContent
            : '';
        final match = marker.firstMatch(following);
        final value = match == null ? null : int.tryParse(match[1]!);
        if (value != null && candidates.contains(value)) offsets.add(value);
      }
      final children = node.children;
      if (children != null) visit(children);
    }
  }

  visit(nodes);
  return offsets;
}
