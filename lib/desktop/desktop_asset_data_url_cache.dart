import '../data/reference_asset_paths.dart';

/// Bounded LRU cache of desktop asset `data:` URLs.
///
/// * In-flight loads are shared so concurrent widgets issue one IPC read.
/// * Failures and empty results are never cached, so a transient read error
///   or a file written later is retried on the next request.
/// * Completed entries are evicted least-recently-used first once either the
///   total size (UTF-16 code units of the data URLs) or the entry count
///   exceeds its budget.
class DesktopAssetDataUrlCache {
  DesktopAssetDataUrlCache({
    this.maxTotalSize = 64 * 1024 * 1024,
    this.maxEntries = 256,
  });

  final int maxTotalSize;
  final int maxEntries;

  // Map literals are insertion-ordered LinkedHashMaps: first key = LRU.
  final _entries = <String, _DataUrlEntry>{};
  var _totalSize = 0;

  int get totalSize => _totalSize;

  int get length => _entries.length;

  bool containsKey(String key) => _entries.containsKey(key);

  Future<String?> load(String key, Future<String?> Function() loader) {
    final existing = _entries.remove(key);
    if (existing != null) {
      _entries[key] = existing; // Mark as most recently used.
      return existing.future;
    }
    final entry = _DataUrlEntry();
    _entries[key] = entry;
    entry.future = _run(key, entry, loader);
    return entry.future;
  }

  Future<String?> _run(
    String key,
    _DataUrlEntry entry,
    Future<String?> Function() loader,
  ) async {
    final String? value;
    try {
      value = await loader();
    } catch (_) {
      _removeIfCurrent(key, entry);
      rethrow;
    }
    if (!identical(_entries[key], entry)) {
      // Invalidated while loading: hand the value to current waiters only.
      return value;
    }
    if (value == null || value.isEmpty || value.length > maxTotalSize) {
      _removeIfCurrent(key, entry);
      return value;
    }
    entry.size = value.length;
    _totalSize += entry.size;
    _evict(keep: key);
    return value;
  }

  void _removeIfCurrent(String key, _DataUrlEntry entry) {
    if (identical(_entries[key], entry)) {
      _entries.remove(key);
      _totalSize -= entry.size;
    }
  }

  void _evict({required String keep}) {
    if (_totalSize <= maxTotalSize && _entries.length <= maxEntries) {
      return;
    }
    for (final key in _entries.keys.toList()) {
      if (_totalSize <= maxTotalSize && _entries.length <= maxEntries) {
        break;
      }
      final entry = _entries[key]!;
      // In-flight entries have no size yet and keep their dedupe slot.
      if (key == keep || entry.size == 0) {
        continue;
      }
      _entries.remove(key);
      _totalSize -= entry.size;
    }
  }

  void invalidate(String key) {
    final entry = _entries.remove(key);
    if (entry != null) {
      _totalSize -= entry.size;
    }
  }

  void clear() {
    _entries.clear();
    _totalSize = 0;
  }
}

class _DataUrlEntry {
  late Future<String?> future;
  var size = 0;
}

final desktopAssetDataUrlCache = DesktopAssetDataUrlCache();

/// Drops the cached data URL of [path] after the asset was written or deleted.
void invalidateDesktopAssetDataUrl(String path) {
  desktopAssetDataUrlCache.invalidate(_cacheKey(path));
}

/// Drops every cached data URL, e.g. after a plan or record deletion removed
/// asset files on the native side.
void clearDesktopAssetDataUrlCache() {
  desktopAssetDataUrlCache.clear();
}

String _cacheKey(String path) => normalizeAssetPathSeparators(path.trim());
