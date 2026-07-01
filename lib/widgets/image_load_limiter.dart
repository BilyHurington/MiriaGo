import 'dart:async';
import 'dart:collection';

class ImageLoadPermit {
  ImageLoadPermit._(this._limiter);

  final ImageLoadLimiter _limiter;
  var _released = false;

  void release() {
    if (_released) {
      return;
    }
    _released = true;
    _limiter._release();
  }
}

class ImageLoadLimiter {
  ImageLoadLimiter(int maxConcurrent)
    : _maxConcurrent = maxConcurrent.clamp(1, 30);

  int _maxConcurrent;
  int _active = 0;
  final Queue<Completer<ImageLoadPermit>> _queue =
      Queue<Completer<ImageLoadPermit>>();

  int get maxConcurrent => _maxConcurrent;

  set maxConcurrent(int value) {
    _maxConcurrent = value.clamp(1, 30);
    _drainQueue();
  }

  Future<ImageLoadPermit> acquire() {
    final completer = Completer<ImageLoadPermit>();
    _queue.add(completer);
    _drainQueue();
    return completer.future;
  }

  void _release() {
    if (_active > 0) {
      _active -= 1;
    }
    _drainQueue();
  }

  void _drainQueue() {
    while (_active < _maxConcurrent && _queue.isNotEmpty) {
      final completer = _queue.removeFirst();
      if (completer.isCompleted) {
        continue;
      }
      _active += 1;
      completer.complete(ImageLoadPermit._(this));
    }
  }
}
