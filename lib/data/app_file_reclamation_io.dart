import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_file_reclamation.dart';
import 'app_managed_file_paths_io.dart';

Future<AppFileReclamationResult> deleteUnreferencedOwnedFiles({
  required Set<String> candidates,
  required Iterable<String?> references,
  required Set<String> directoryNames,
}) async {
  final owned = <String>{};
  for (final path in candidates) {
    try {
      final resolved = await canonicalAppFilePath(path);
      if (resolved != null) owned.add(resolved);
    } on Object {
      // An unresolvable candidate is simply not reclaimed.
    }
  }
  if (owned.isEmpty) return AppFileReclamationResult.none;

  // A reference that cannot be resolved aborts: it might be a candidate.
  for (final path in references) {
    final resolved = await canonicalAppFilePath(path);
    if (resolved != null) owned.remove(resolved);
  }
  if (owned.isEmpty) return AppFileReclamationResult.none;

  final roots = await _ownedRoots(directoryNames);
  var deleted = 0;
  var failed = 0;
  for (final path in owned) {
    final root = _rootContaining(roots, path);
    if (root == null) continue;
    try {
      if (await FileSystemEntity.type(path, followLinks: false) !=
          FileSystemEntityType.file) {
        continue;
      }
      await File(path).delete();
      deleted++;
    } on Object {
      failed++;
      continue;
    }
    await _removeEmptyParents(path, root);
  }
  return AppFileReclamationResult(
    deletedFileCount: deleted,
    failedFileCount: failed,
  );
}

/// The existing file [path] points to, rebased into the current app container
/// and with symlinks resolved, or null for remote/missing paths.
Future<String?> canonicalAppFilePath(String? path) async {
  final resolution = await resolveAppManagedFilePath(path);
  final resolved = resolution.resolvedPath;
  if (resolved == null) return null;
  return p.normalize(await File(resolved).resolveSymbolicLinks());
}

/// Canonical app-owned roots. A root that is a symlink leaving its base
/// directory is not granted ownership.
Future<List<String>> _ownedRoots(Set<String> directoryNames) async {
  final bases = <Directory>[];
  try {
    bases.add(await getApplicationDocumentsDirectory());
  } on Object {
    // Unavailable on this platform.
  }
  try {
    bases.add(await getApplicationSupportDirectory());
  } on Object {
    // Unavailable on this platform.
  }
  final roots = <String>{};
  for (final base in bases) {
    if (!await base.exists()) continue;
    final canonicalBase = await base.resolveSymbolicLinks();
    for (final name in directoryNames) {
      final root = Directory(p.join(base.path, name));
      if (!await root.exists()) continue;
      final canonicalRoot = p.normalize(await root.resolveSymbolicLinks());
      if (p.isWithin(canonicalBase, canonicalRoot)) roots.add(canonicalRoot);
    }
  }
  return roots.toList(growable: false);
}

String? _rootContaining(List<String> roots, String path) {
  for (final root in roots) {
    if (p.isWithin(root, path)) return root;
  }
  return null;
}

/// Removes directories left empty below [root] (e.g. an imported package or
/// a user reference folder). Never removes [root] or a non-empty directory.
Future<void> _removeEmptyParents(String path, String root) async {
  var directory = p.dirname(path);
  while (p.isWithin(root, directory)) {
    try {
      if (await FileSystemEntity.type(directory, followLinks: false) !=
          FileSystemEntityType.directory) {
        return;
      }
      // Non-recursive: fails, and stops here, if anything is left inside.
      await Directory(directory).delete();
    } on Object {
      return;
    }
    directory = p.dirname(directory);
  }
}
