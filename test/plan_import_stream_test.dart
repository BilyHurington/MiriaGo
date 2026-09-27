import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/plan_transfer/plan_import_package.dart';
import 'package:miriago/plan_transfer/plan_import_stream.dart';

void main() {
  const limits = PlanImportLimits(maxCompressedBytes: 4);

  test('reads a package exactly at the byte limit', () async {
    expect(
      await readBoundedPlanImportStream(
        Stream.fromIterable([
          [1, 2],
          [3, 4],
        ]),
        limits: limits,
      ),
      [1, 2, 3, 4],
    );
  });

  test('stops consuming after expanded input exceeds the limit', () async {
    var consumed = 0;
    var closed = false;
    Stream<List<int>> input() async* {
      try {
        for (var i = 0; i < 100; i++) {
          consumed++;
          yield [1, 2, 3];
        }
      } finally {
        closed = true;
      }
    }

    await expectLater(
      readBoundedPlanImportStream(input(), limits: limits),
      throwsA(isA<PlanImportLimitException>()),
    );
    expect(consumed, 2);
    expect(closed, isTrue);
  });

  test('does not return a partial package on read failure', () async {
    Stream<List<int>> input() async* {
      yield [1, 2];
      throw StateError('disk unavailable');
    }

    await expectLater(
      readBoundedPlanImportStream(input(), limits: limits),
      throwsStateError,
    );
  });
}
