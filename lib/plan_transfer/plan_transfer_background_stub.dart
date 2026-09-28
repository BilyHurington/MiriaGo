import 'dart:async';

// Web has no isolates for this work; run inline and honor cancellation only
// before and after the task.
Future<R> runPlanTransferTaskOnPlatform<R>(
  FutureOr<R> Function() task,
  Future<void>? cancelled,
  Object Function() cancelledError,
) async {
  return await task();
}
