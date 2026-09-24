import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'synced_maplibre_layer.dart';

/// Rewrites OpenFreeMap label expressions so the local script is shown first.
///
/// OpenFreeMap styles label places as `name:latin` above `name:nonlatin`, so
/// Japanese places read "Ujibashi nishizume" above "宇治橋西詰". Pilgrims match
/// labels against local signs, so the local name goes on top and the romanised
/// name below. Returns [styleJson] unchanged when nothing needed rewriting or
/// the document cannot be parsed.
String localizeMapStyleLabels(String styleJson) {
  Object? decoded;
  try {
    decoded = jsonDecode(styleJson);
  } on FormatException {
    return styleJson;
  }
  if (decoded is! Map<String, dynamic>) return styleJson;
  final layers = decoded['layers'];
  if (layers is! List) return styleJson;
  var changed = false;
  for (final layer in layers) {
    if (layer is! Map) continue;
    final layout = layer['layout'];
    if (layout is! Map || !layout.containsKey('text-field')) continue;
    final rewritten = _swapLatinFirst(layout['text-field']);
    if (rewritten.changed) {
      layout['text-field'] = rewritten.value;
      changed = true;
    }
  }
  return changed ? jsonEncode(decoded) : styleJson;
}

({Object? value, bool changed}) _swapLatinFirst(Object? expression) {
  if (expression is! List) return (value: expression, changed: false);
  if (expression.length == 4 &&
      expression[0] == 'concat' &&
      _isGet(expression[1], 'name:latin') &&
      _isGet(expression[3], 'name:nonlatin')) {
    return (
      value: ['concat', expression[3], expression[2], expression[1]],
      changed: true,
    );
  }
  var changed = false;
  final children = [
    for (final child in expression)
      () {
        final result = _swapLatinFirst(child);
        changed = changed || result.changed;
        return result.value;
      }(),
  ];
  return (value: changed ? children : expression, changed: changed);
}

bool _isGet(Object? expression, String property) =>
    expression is List &&
    expression.length == 2 &&
    expression[0] == 'get' &&
    expression[1] == property;

typedef MapStyleSourceLoader = Future<String> Function(String style);

/// Loads OpenFreeMap styles (remote URL or bundled asset) and localizes their
/// labels. Results are cached per style for the app session; a failed load
/// falls back to the original style reference so the map still renders.
class LocalizedMapStyleCache {
  LocalizedMapStyleCache({MapStyleSourceLoader? loader})
    : _loader = loader ?? _defaultLoader;

  static final instance = LocalizedMapStyleCache();

  final MapStyleSourceLoader _loader;
  final _resolved = <String, String>{};
  final _pending = <String, Future<String>>{};

  /// Already localized style, if loaded before.
  String? resolved(String style) => _resolved[style];

  Future<String> load(String style) {
    final done = _resolved[style];
    if (done != null) return SynchronousFuture(done);
    return _pending[style] ??= () async {
      try {
        final source = await _loader(style);
        final localized = localizeMapStyleLabels(source);
        _resolved[style] = localized;
        return localized;
      } on Object {
        // Keep the unmodified URL/asset; do not cache so a later map retries.
        return style;
      } finally {
        _pending.remove(style);
      }
    }();
  }

  static Future<String> _defaultLoader(String style) async {
    final uri = Uri.tryParse(style);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('style ${response.statusCode}');
      }
      return utf8.decode(response.bodyBytes);
    }
    return rootBundle.loadString(style);
  }
}

/// A [SyncedMapLibreLayer] whose OpenFreeMap style shows local-script labels
/// first.
class LocalizedMapLibreLayer extends StatefulWidget {
  const LocalizedMapLibreLayer({required this.style, this.cache, super.key});

  final String style;
  final LocalizedMapStyleCache? cache;

  @override
  State<LocalizedMapLibreLayer> createState() => _LocalizedMapLibreLayerState();
}

class _LocalizedMapLibreLayerState extends State<LocalizedMapLibreLayer> {
  LocalizedMapStyleCache get _cache =>
      widget.cache ?? LocalizedMapStyleCache.instance;
  String? _style;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant LocalizedMapLibreLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.style != widget.style) _resolve();
  }

  void _resolve() {
    final requested = widget.style;
    _style = _cache.resolved(requested);
    if (_style != null) return;
    unawaited(
      _cache.load(requested).then((style) {
        if (mounted && widget.style == requested) {
          setState(() => _style = style);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    if (style == null) return const SizedBox.shrink();
    // The native map reads its style once; a new key recreates it if the
    // localized document arrives for a different style.
    return SyncedMapLibreLayer(key: ValueKey(style.hashCode), initStyle: style);
  }
}
