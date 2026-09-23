import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/plan/pending_reference_lifecycle.dart';

void main() {
  late List<String> deleted;
  late PendingReferenceLifecycle<String> lifecycle;
  setUp(() {
    deleted = [];
    lifecycle = PendingReferenceLifecycle(
      delete: (path) async {
        deleted.add(path);
      },
    );
  });

  test(
    'cleanup exceptions never escape replacement or unawaited disposal',
    () async {
      lifecycle = PendingReferenceLifecycle(
        delete: (path) async {
          deleted.add(path);
          throw FileSystemExceptionForTest();
        },
      );
      await lifecycle.select(() async => 'first');
      expect(await lifecycle.select(() async => 'second'), isTrue);
      lifecycle.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(deleted, ['first', 'second']);
      final gate = Completer<String?>();
      final lateLifecycle = PendingReferenceLifecycle<String>(
        delete: (_) async {
          throw FileSystemExceptionForTest();
        },
      );
      final selection = lateLifecycle.select(() => gate.future);
      lateLifecycle.dispose();
      gate.complete('late');
      expect(await selection, isFalse);
    },
  );

  test(
    'replacement, removal and repeated disposal delete each draft once',
    () async {
      await lifecycle.select(() async => 'first');
      await lifecycle.select(() async => 'second');
      lifecycle.remove();
      lifecycle.dispose();
      lifecycle.dispose();
      expect(deleted, ['first', 'second']);
    },
  );

  for (final succeeded in [true, false]) {
    test(
      'disposal waits for persistence and retains outcome $succeeded',
      () async {
        await lifecycle.select(() async => 'submitted');
        expect(lifecycle.beginSave(), isTrue);
        lifecycle.beginPersistence();
        lifecycle.dispose();
        expect(deleted, isEmpty);
        lifecycle.finishPersistence(succeeded: succeeded);
        lifecycle.endSave();
        lifecycle.dispose();
        expect(deleted, isEmpty);
      },
    );
  }

  test(
    'local failure before persistence still cleans draft after disposal',
    () async {
      await lifecycle.select(() async => 'draft');
      lifecycle.beginSave();
      lifecycle.dispose();
      expect(deleted, isEmpty);
      lifecycle.endSave();
      lifecycle.endSave();
      expect(deleted, ['draft']);
    },
  );

  test(
    'uncertain submitted resource survives replacement and cancellation',
    () async {
      await lifecycle.select(() async => 'uncertain');
      lifecycle.beginSave();
      lifecycle.beginPersistence();
      lifecycle.finishPersistence(succeeded: false);
      lifecycle.endSave();
      await lifecycle.select(() async => 'new-draft');
      lifecycle.dispose();
      expect(deleted, ['new-draft']);
    },
  );

  test('uncertain resource can be retried without being deleted', () async {
    await lifecycle.select(() async => 'submitted');
    for (final succeeded in [false, true]) {
      expect(lifecycle.beginSave(), isTrue);
      lifecycle.beginPersistence();
      lifecycle.finishPersistence(succeeded: succeeded);
      lifecycle.endSave();
    }
    lifecycle.remove();
    lifecycle.dispose();
    expect(deleted, isEmpty);
  });

  test(
    'save and repeated selection are rejected while picker is pending',
    () async {
      final picker = Completer<String?>();
      final selection = lifecycle.select(() => picker.future);
      expect(lifecycle.beginSave(), isFalse);
      expect(await lifecycle.select(() async => 'unreachable'), isFalse);
      picker.complete('chosen');
      expect(await selection, isTrue);
      expect(lifecycle.current, 'chosen');
      expect(lifecycle.beginSave(), isTrue);
      expect(await lifecycle.select(() async => 'unreachable'), isFalse);
      lifecycle.remove();
      expect(lifecycle.current, 'chosen');
      lifecycle.endSave();
      lifecycle.dispose();
      expect(deleted, ['chosen']);
    },
  );

  test(
    'picker finishes after disposal: old and late drafts deleted once',
    () async {
      await lifecycle.select(() async => 'old');
      final picker = Completer<String?>();
      final selection = lifecycle.select(() => picker.future);
      lifecycle.dispose();
      expect(deleted, ['old']);
      picker.complete('late');
      expect(await selection, isFalse);
      lifecycle.dispose();
      expect(deleted, ['old', 'late']);
    },
  );

  test(
    'dispose during previous selection cleanup also cleans new draft',
    () async {
      final cleanup = Completer<void>();
      lifecycle = PendingReferenceLifecycle(
        delete: (path) async {
          deleted.add(path);
          if (path == 'old') await cleanup.future;
        },
      );
      await lifecycle.select(() async => 'old');
      final replacing = lifecycle.select(() async => 'new');
      await Future<void>.delayed(Duration.zero);
      expect(lifecycle.current, 'new');
      lifecycle.dispose();
      cleanup.complete();
      expect(await replacing, isFalse);
      expect(deleted, ['old', 'new']);
    },
  );

  test(
    'cancelled or failed picker keeps old selection and unlocks save',
    () async {
      await lifecycle.select(() async => 'old');
      expect(await lifecycle.select(() async => null), isFalse);
      await expectLater(
        lifecycle.select(() async => throw StateError('picker')),
        throwsStateError,
      );
      expect(lifecycle.isBusy, isFalse);
      expect(lifecycle.current, 'old');
      lifecycle.dispose();
      expect(deleted, ['old']);
    },
  );
}

class FileSystemExceptionForTest implements Exception {}
