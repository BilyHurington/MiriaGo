import 'dart:async';
import 'dart:isolate';

// Mirrors Isolate.run, but keeps the Isolate handle so a cancelled import or
// export can be killed instead of burning CPU until it finishes.
Future<R> runPlanTransferTaskOnPlatform<R>(
  FutureOr<R> Function() task,
  Future<void>? cancelled,
  Object Function() cancelledError,
) {
  final completer = Completer<R>();
  final port = RawReceivePort();
  Isolate? isolate;
  var cancelRequested = false;

  void finish(void Function() complete) {
    if (completer.isCompleted) return;
    port.close();
    complete();
  }

  port.handler = (Object? response) {
    if (response == null) {
      finish(
        () => completer.completeError(
          RemoteError('Plan transfer task ended without a result.', ''),
          StackTrace.empty,
        ),
      );
      return;
    }
    final list = response as List<Object?>;
    if (list.length == 1) {
      finish(() => completer.complete(list[0] as R));
      return;
    }
    final error = list[0];
    final stack = list[1];
    if (stack is StackTrace) {
      finish(() => completer.completeError(error!, stack));
    } else {
      final remote = RemoteError(error.toString(), stack.toString());
      finish(() => completer.completeError(remote, remote.stackTrace));
    }
  };

  cancelled?.then((_) {
    cancelRequested = true;
    isolate?.kill(priority: Isolate.immediate);
    finish(() => completer.completeError(cancelledError()));
  });

  Isolate.spawn<_PlanTransferMessage<R>>(
    _runPlanTransferTask,
    _PlanTransferMessage<R>(task, port.sendPort),
    onError: port.sendPort,
    onExit: port.sendPort,
    errorsAreFatal: true,
    debugName: 'plan-transfer',
  ).then(
    (spawned) {
      isolate = spawned;
      if (cancelRequested) {
        spawned.kill(priority: Isolate.immediate);
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      finish(() => completer.completeError(error, stackTrace));
    },
  );
  return completer.future;
}

class _PlanTransferMessage<R> {
  const _PlanTransferMessage(this.task, this.resultPort);

  final FutureOr<R> Function() task;
  final SendPort resultPort;
}

Future<void> _runPlanTransferTask<R>(_PlanTransferMessage<R> message) async {
  final R result;
  try {
    result = await message.task();
  } catch (error, stackTrace) {
    Isolate.exit(message.resultPort, <Object?>[error, stackTrace]);
  }
  Isolate.exit(message.resultPort, <Object?>[result]);
}
