import 'dart:async';

import 'plan_transfer_background_stub.dart'
    if (dart.library.io) 'plan_transfer_background_io.dart'
    as platform;

/// Thrown when a background plan import/export task was cancelled.
class PlanTransferCancelledException implements Exception {
  const PlanTransferCancelledException();

  @override
  String toString() => 'PlanTransferCancelledException';
}

/// Cooperative cancellation for [runPlanTransferTask].
///
/// On native platforms cancelling terminates the worker isolate immediately,
/// so long ZIP inflate/deflate work stops instead of running to completion.
class PlanTransferCancellation {
  final _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;

  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) {
      _cancelled.complete();
    }
  }

  void throwIfCancelled() {
    if (isCancelled) {
      throw const PlanTransferCancelledException();
    }
  }
}

/// Runs heavy, synchronous plan package work (ZIP parsing, CRC checks,
/// compression) off the UI isolate on native platforms. On the web the task
/// runs inline because web isolates are unavailable.
///
/// [task] must be created by a top-level or static function so that its
/// closure only captures sendable values.
Future<R> runPlanTransferTask<R>(
  FutureOr<R> Function() task, {
  PlanTransferCancellation? cancellation,
}) async {
  cancellation?.throwIfCancelled();
  final result = await platform.runPlanTransferTaskOnPlatform(
    task,
    cancellation?.whenCancelled,
    () => const PlanTransferCancelledException(),
  );
  cancellation?.throwIfCancelled();
  return result;
}
