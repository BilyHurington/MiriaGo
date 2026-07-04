import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _managedDirectories = <String>{
  'visit_record_images',
  'graded_photos',
  'imported_plan_assets',
};

class AppManagedFilePathResolution {
  const AppManagedFilePathResolution({
    required this.originalPath,
    required this.resolvedPath,
    required this.exists,
    required this.rebased,
  });

  final String originalPath;
  final String? resolvedPath;
  final bool exists;
  final bool rebased;
}

List<String>? _cachedBaseDirectories;

@visibleForTesting
void setAppManagedFileBaseDirectoriesForTesting(List<String>? paths) {
  _cachedBaseDirectories = paths
      ?.map((path) => p.normalize(path))
      .where((path) => path.trim().isNotEmpty)
      .toSet()
      .toList(growable: false);
}

Future<AppManagedFilePathResolution> resolveAppManagedFilePath(
  String? path,
) async {
  final originalPath = path?.trim() ?? '';
  if (originalPath.isEmpty || _isNonLocalPath(originalPath)) {
    return AppManagedFilePathResolution(
      originalPath: originalPath,
      resolvedPath: null,
      exists: false,
      rebased: false,
    );
  }

  final directFile = File(originalPath);
  if (directFile.existsSync()) {
    return AppManagedFilePathResolution(
      originalPath: originalPath,
      resolvedPath: originalPath,
      exists: true,
      rebased: false,
    );
  }

  final bases = await _ensureBaseDirectories();
  for (final candidate in _candidatePaths(originalPath, bases)) {
    if (candidate == originalPath) {
      continue;
    }
    if (File(candidate).existsSync()) {
      return AppManagedFilePathResolution(
        originalPath: originalPath,
        resolvedPath: candidate,
        exists: true,
        rebased: true,
      );
    }
  }

  return AppManagedFilePathResolution(
    originalPath: originalPath,
    resolvedPath: null,
    exists: false,
    rebased: false,
  );
}

String? resolveExistingAppManagedFilePathSync(String? path) {
  final originalPath = path?.trim();
  if (originalPath == null ||
      originalPath.isEmpty ||
      _isNonLocalPath(originalPath)) {
    return null;
  }

  if (File(originalPath).existsSync()) {
    return originalPath;
  }

  final bases = _cachedBaseDirectories;
  if (bases == null || bases.isEmpty) {
    return null;
  }
  for (final candidate in _candidatePaths(originalPath, bases)) {
    if (candidate == originalPath) {
      continue;
    }
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }
  return null;
}

bool hasPotentiallyRebasableAppManagedFilePath(String? path) {
  final value = path?.trim();
  if (value == null || value.isEmpty || _isNonLocalPath(value)) {
    return false;
  }
  if (File(value).existsSync()) {
    return false;
  }
  final normalized = _normalizeSeparators(value);
  return _managedRelativePath(normalized) != null;
}

Future<List<String>> _ensureBaseDirectories() async {
  final cached = _cachedBaseDirectories;
  if (cached != null) {
    return cached;
  }

  final bases = <String>{};
  try {
    bases.add(p.normalize((await getApplicationDocumentsDirectory()).path));
  } catch (_) {}
  try {
    bases.add(p.normalize((await getApplicationSupportDirectory()).path));
  } catch (_) {}

  _cachedBaseDirectories = bases.toList(growable: false);
  return _cachedBaseDirectories!;
}

Iterable<String> _candidatePaths(
  String path,
  List<String> baseDirectories,
) sync* {
  final normalized = _normalizeSeparators(path);
  final relativePaths = <String>{
    ?_afterMarker(normalized, '/Documents/'),
    ?_afterMarker(normalized, '/files/'),
    ?_managedRelativePath(normalized),
  };

  for (final relativePath in relativePaths) {
    final segments = relativePath
        .split('/')
        .where((segment) => segment.isNotEmpty && segment != '.')
        .toList(growable: false);
    if (segments.isEmpty || segments.any((segment) => segment == '..')) {
      continue;
    }
    for (final base in baseDirectories) {
      yield p.normalize(p.joinAll([base, ...segments]));
    }
  }
}

String? _afterMarker(String path, String marker) {
  final index = path.indexOf(marker);
  if (index < 0) {
    return null;
  }
  final value = path.substring(index + marker.length);
  return value.isEmpty ? null : value;
}

String? _managedRelativePath(String path) {
  final segments = path.split('/');
  for (var index = 0; index < segments.length; index += 1) {
    if (_managedDirectories.contains(segments[index])) {
      return segments.sublist(index).join('/');
    }
  }
  return null;
}

bool _isNonLocalPath(String path) {
  final uri = Uri.tryParse(path);
  if (uri == null) {
    return false;
  }
  return uri.hasScheme && uri.scheme != 'file';
}

String _normalizeSeparators(String path) => path.replaceAll(r'\', '/');
