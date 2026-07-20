import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

enum CurrentLocationFailure { serviceDisabled, permissionDenied, timeout }

class CurrentLocationException implements Exception {
  const CurrentLocationException(this.failure);

  final CurrentLocationFailure failure;
}

typedef LocationPermissionReader = Future<LocationPermission> Function();
typedef LocationPermissionRequester = Future<LocationPermission> Function();
typedef LocationServiceReader = Future<bool> Function();
typedef LocationStreamFactory =
    Stream<Position> Function(LocationSettings settings);

Future<Position> resolveCurrentLocation({
  LocationServiceReader? isServiceEnabled,
  LocationPermissionReader? checkPermission,
  LocationPermissionRequester? requestPermission,
  LocationStreamFactory? positionStream,
  Future<void> Function(Duration duration)? delay,
  Future<void> Function()? waitForAppResume,
  Duration normalTimeout = const Duration(seconds: 12),
  Duration firstGrantTimeout = const Duration(seconds: 25),
}) async {
  final readService = isServiceEnabled ?? Geolocator.isLocationServiceEnabled;
  final readPermission = checkPermission ?? Geolocator.checkPermission;
  final request = requestPermission ?? Geolocator.requestPermission;
  final streamFactory =
      positionStream ??
      (settings) => Geolocator.getPositionStream(locationSettings: settings);
  final wait = delay ?? Future<void>.delayed;
  final waitForResume = waitForAppResume ?? _waitForAppResume;

  if (!await readService()) {
    throw const CurrentLocationException(
      CurrentLocationFailure.serviceDisabled,
    );
  }

  var permission = await readPermission();
  var firstGrant = false;
  if (permission == LocationPermission.denied) {
    permission = await request();
    firstGrant =
        permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
    if (firstGrant) {
      await waitForResume();
      await wait(const Duration(milliseconds: 350));
      permission = await readPermission();
    }
  }

  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever ||
      permission == LocationPermission.unableToDetermine) {
    throw const CurrentLocationException(
      CurrentLocationFailure.permissionDenied,
    );
  }

  final iterator = StreamIterator<Position>(
    streamFactory(const LocationSettings(accuracy: LocationAccuracy.high)),
  );
  try {
    final hasPosition = await iterator.moveNext().timeout(
      firstGrant ? firstGrantTimeout : normalTimeout,
    );
    if (!hasPosition) {
      throw const CurrentLocationException(CurrentLocationFailure.timeout);
    }
    return iterator.current;
  } on TimeoutException {
    throw const CurrentLocationException(CurrentLocationFailure.timeout);
  } finally {
    await iterator.cancel();
  }
}

Future<void> _waitForAppResume() async {
  final binding = WidgetsBinding.instance;
  final state = binding.lifecycleState;
  if (state == null || state == AppLifecycleState.resumed) {
    return;
  }

  final observer = _ResumeObserver();
  binding.addObserver(observer);
  try {
    await observer.resumed.timeout(const Duration(seconds: 3));
  } on TimeoutException {
    // Permission state is rechecked below even if no lifecycle event arrives.
  } finally {
    binding.removeObserver(observer);
  }
}

class _ResumeObserver with WidgetsBindingObserver {
  final _completer = Completer<void>();

  Future<void> get resumed => _completer.future;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_completer.isCompleted) {
      _completer.complete();
    }
  }
}

String currentLocationFailureMessage(CurrentLocationException error) {
  return switch (error.failure) {
    CurrentLocationFailure.serviceDisabled => '定位服务未开启。',
    CurrentLocationFailure.permissionDenied => '需要定位权限来显示当前位置。',
    CurrentLocationFailure.timeout => '定位超时，请稍后重试。',
  };
}
