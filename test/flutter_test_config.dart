import 'dart:async';

import 'package:miriago/data/work_cover_backfill.dart';

/// Widget tests have no network; tests that cover the backfill run it
/// explicitly.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  WorkCoverBackfill.automaticEnabled = false;
  await testMain();
}
