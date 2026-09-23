import 'dart:async';

import 'package:flutter/foundation.dart';

enum _Ownership { draft, saving, committed, uncertain }

/// Owns only newly selected resources, never an existing point's images.
class PendingReferenceLifecycle<T extends Object> {
  PendingReferenceLifecycle({required this.delete});

  final Future<void> Function(T resource) delete;
  T? _current;
  _Ownership _ownership = _Ownership.draft;
  bool _disposed = false;
  bool _isSelecting = false;
  bool _isSaving = false;

  T? get current => _current;
  bool get isDisposed => _disposed;
  bool get isSaving => _isSaving;
  bool get isBusy => _isSaving || _isSelecting;

  Future<bool> select(Future<T?> Function() pickAndStore) async {
    if (_disposed || isBusy) return false;
    _isSelecting = true;
    try {
      final resource = await pickAndStore();
      if (resource == null) return false;
      if (_disposed) {
        await _delete(resource);
        return false;
      }
      final previous = _takeDisposableDraft();
      _current = resource;
      _ownership = _Ownership.draft;
      if (previous != null) await _delete(previous);
      return !_disposed;
    } finally {
      _isSelecting = false;
    }
  }

  bool beginSave() {
    if (_disposed || isBusy) return false;
    _isSaving = true;
    return true;
  }

  void beginPersistence() {
    assert(_isSaving);
    _ownership = _Ownership.saving;
  }

  void finishPersistence({required bool succeeded}) {
    if (_ownership != _Ownership.saving) return;
    // A thrown repository call can mean the commit succeeded but rereading
    // failed. Without authoritative confirmation, retaining is the safe choice.
    _ownership = succeeded ? _Ownership.committed : _Ownership.uncertain;
  }

  void endSave() {
    _isSaving = false;
    if (_disposed) _discardDraft();
  }

  void remove() {
    if (_disposed || isBusy) return;
    _discardDraft();
    _current = null;
    _ownership = _Ownership.draft;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (!_isSaving) _discardDraft();
  }

  T? _takeDisposableDraft() {
    if (_ownership != _Ownership.draft) return null;
    final resource = _current;
    _current = null;
    return resource;
  }

  void _discardDraft() {
    final resource = _takeDisposableDraft();
    if (resource != null) unawaited(_delete(resource));
  }

  Future<void> _delete(T resource) async {
    try {
      await delete(resource);
    } catch (error) {
      // Cleanup is best-effort; an orphan must not break saving or disposal.
      debugPrint('Pending reference cleanup failed: $error');
    }
  }
}
