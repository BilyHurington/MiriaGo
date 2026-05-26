import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_junrei_helper/data/anitabi_client.dart';
import 'package:seichi_junrei_helper/plan/pilgrimage_models.dart';

void main() {
  group('formatAnitabiSceneTime', () {
    test('formats seconds below one hour as minutes and seconds', () {
      expect(formatAnitabiSceneTime(0), '0:00');
      expect(formatAnitabiSceneTime(7), '0:07');
      expect(formatAnitabiSceneTime(125), '2:05');
    });

    test('formats seconds above one hour as hours minutes and seconds', () {
      expect(formatAnitabiSceneTime(3723), '1:02:03');
      expect(formatAnitabiSceneTime('7322'), '2:02:02');
    });

    test('ignores invalid values', () {
      expect(formatAnitabiSceneTime(null), isNull);
      expect(formatAnitabiSceneTime(-1), isNull);
      expect(formatAnitabiSceneTime('not-a-time'), isNull);
    });
  });

  test('formats legacy episode labels that already contain raw seconds', () {
    expect(formatEpisodeLabelForDisplay('EP 4 / 125s'), 'EP 4 / 2:05');
    expect(formatEpisodeLabelForDisplay('EP 12 / 3723s'), 'EP 12 / 1:02:03');
    expect(formatEpisodeLabelForDisplay('手动录入'), '手动录入');
  });
}
