import 'dart:async';

Future<List<R>> runLimitedConcurrent<T, R>({
  required List<T> items,
  required int maxConcurrent,
  required Future<R> Function(T item, int index) task,
  void Function(R result)? onResult,
}) async {
  if (items.isEmpty) {
    return const [];
  }

  final workerCount = maxConcurrent.clamp(1, items.length);
  final results = List<R?>.filled(items.length, null);
  var nextIndex = 0;

  Future<void> worker() async {
    while (true) {
      final index = nextIndex;
      if (index >= items.length) {
        return;
      }
      nextIndex += 1;

      final result = await task(items[index], index);
      results[index] = result;
      onResult?.call(result);
    }
  }

  await Future.wait([for (var i = 0; i < workerCount; i += 1) worker()]);
  return [for (final result in results) result as R];
}
