import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/utils/limited_concurrency.dart';

void main() {
  test('runLimitedConcurrent respects max concurrent workers', () async {
    var active = 0;
    var maxObserved = 0;
    final completers = List.generate(6, (_) => Completer<void>());

    final future = runLimitedConcurrent<int, int>(
      items: [0, 1, 2, 3, 4, 5],
      maxConcurrent: 3,
      task: (item, _) async {
        active += 1;
        if (active > maxObserved) {
          maxObserved = active;
        }
        await completers[item].future;
        active -= 1;
        return item * 2;
      },
    );

    await Future<void>.delayed(Duration.zero);
    expect(maxObserved, 3);
    expect(active, 3);

    completers[0].complete();
    completers[1].complete();
    completers[2].complete();
    await Future<void>.delayed(Duration.zero);
    expect(maxObserved, 3);
    expect(active, 3);

    for (final completer in completers.skip(3)) {
      completer.complete();
    }

    expect(await future, [0, 2, 4, 6, 8, 10]);
    expect(maxObserved, 3);
  });
}
