import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/map/localized_map_style.dart';

void main() {
  test('puts the local-script name above the romanised one', () {
    final source = File('assets/maps/liberty_dark.json').readAsStringSync();
    final localized = localizeMapStyleLabels(source);
    expect(localized, isNot(source));
    final layers = (jsonDecode(localized) as Map)['layers'] as List;
    var swapped = 0;
    for (final layer in layers) {
      final field = (layer as Map)['layout']?['text-field'];
      final text = jsonEncode(field);
      expect(
        text.contains('["concat",["get","name:latin"]'),
        isFalse,
        reason: '${layer['id']} still shows latin first',
      );
      if (text.contains('["concat",["get","name:nonlatin"]')) swapped++;
    }
    expect(swapped, greaterThan(10));
    // Non-label parts of the style are untouched.
    final original = jsonDecode(source) as Map;
    final updated = jsonDecode(localized) as Map;
    expect(updated['sources'], original['sources']);
    expect(updated['sprite'], original['sprite']);
    expect(
      (updated['layers'] as List).length,
      (original['layers'] as List).length,
    );
  });

  test('leaves unrelated or invalid styles unchanged', () {
    const plain =
        '{"version":8,"layers":[{"id":"a","layout":{"text-field":["get","name"]}}]}';
    expect(localizeMapStyleLabels(plain), plain);
    expect(localizeMapStyleLabels('not json'), 'not json');
  });

  test('cache localizes once and falls back to the source reference', () async {
    var loads = 0;
    final cache = LocalizedMapStyleCache(
      loader: (style) async {
        loads++;
        if (style == 'broken') throw StateError('offline');
        return '{"version":8,"layers":[{"id":"x","layout":{"text-field":'
            '["concat",["get","name:latin"],"\\n",["get","name:nonlatin"]]}}]}';
      },
    );
    final first = await cache.load('https://style.example/a');
    expect(first, contains('["concat",["get","name:nonlatin"]'));
    expect(cache.resolved('https://style.example/a'), first);
    await cache.load('https://style.example/a');
    expect(loads, 1);
    expect(await cache.load('broken'), 'broken');
    expect(cache.resolved('broken'), isNull);
  });
}
