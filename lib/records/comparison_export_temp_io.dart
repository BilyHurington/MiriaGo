import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/app_file_reclamation.dart';
import '../data/pilgrimage_repository.dart';

// exportComparisonImage writes each render into its own
// Documents/visit_record_images/comparison-XXXX/ directory (createTemp).
const _exportDirectoryPrefix = 'comparison-';

/// Deletes a rendered comparison image once it has been delivered (e.g. the
/// gallery saver has copied it). Only a file directly inside a
/// `visit_record_images/comparison-*` export directory is removed, together
/// with that directory once empty; any other path is ignored.
Future<void> deleteComparisonExportTemp(String? path) async {
  if (path == null || path.isEmpty) return;
  try {
    final exportFile = await _ownedExportFile(path);
    if (exportFile == null) return;
    await File(exportFile).delete();
    // Non-recursive: keeps the directory if anything else is left inside.
    await Directory(p.dirname(exportFile)).delete();
  } on Object catch (error) {
    debugPrint('Comparison export cleanup skipped: $error');
  }
}

/// Startup sweep for comparison exports that were handed to the image viewer
/// (share sheet / save to gallery). share_plus may still be read by the
/// receiving app after the share sheet closes, so these are only removed once
/// they are older than [maxAge]. Files are removed with the same reference
/// rule as every other app-owned file.
Future<void> sweepStaleComparisonExports({
  required PilgrimageRepository repository,
  Duration maxAge = const Duration(days: 1),
  DateTime? now,
}) async {
  try {
    final documents = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(documents.path, 'visit_record_images'));
    if (await FileSystemEntity.type(root.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      return;
    }
    final cutoff = (now ?? DateTime.now()).subtract(maxAge);
    final staleFiles = <String>[];
    final staleDirectories = <Directory>[];
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! Directory ||
          !p.basename(entry.path).startsWith(_exportDirectoryPrefix)) {
        continue;
      }
      // A render is written once; its file time is when it was exported. An
      // export folder without files falls back to the folder's own time.
      final files = <File>[];
      var stale = true;
      await for (final child in entry.list(followLinks: false)) {
        if (child is! File) {
          stale = false;
          break;
        }
        if (!(await child.stat()).modified.isBefore(cutoff)) stale = false;
        files.add(child);
      }
      if (files.isEmpty && stale) {
        stale = (await entry.stat()).modified.isBefore(cutoff);
      }
      if (!stale) continue;
      staleDirectories.add(entry);
      staleFiles.addAll(files.map((file) => file.path));
    }
    if (staleDirectories.isEmpty) return;
    await reclaimUnreferencedAppFiles(
      repository: repository,
      candidatePaths: staleFiles,
      ownedDirectories: const {AppOwnedDirectory.visitRecordImages},
    );
    for (final directory in staleDirectories) {
      try {
        // Already empty ones are pruned by reclamation; leftovers stay.
        if (await directory.exists()) await directory.delete();
      } on FileSystemException {
        // Not empty: a file was kept because something references it.
      }
    }
  } on Object catch (error) {
    debugPrint('Comparison export sweep skipped: $error');
  }
}

/// The canonical path of [path] if it is a regular file directly inside a
/// comparison export directory of the app's own visit_record_images.
Future<String?> _ownedExportFile(String path) async {
  if (await FileSystemEntity.type(path, followLinks: false) !=
      FileSystemEntityType.file) {
    return null;
  }
  final documents = await getApplicationDocumentsDirectory();
  final root = Directory(p.join(documents.path, 'visit_record_images'));
  if (!await root.exists()) return null;
  final canonicalBase = await documents.resolveSymbolicLinks();
  final canonicalRoot = await root.resolveSymbolicLinks();
  if (!p.isWithin(canonicalBase, canonicalRoot)) return null;
  final canonicalFile = await File(path).resolveSymbolicLinks();
  final directory = p.dirname(canonicalFile);
  if (p.dirname(directory) != canonicalRoot ||
      !p.basename(directory).startsWith(_exportDirectoryPrefix)) {
    return null;
  }
  if (await FileSystemEntity.type(directory, followLinks: false) !=
      FileSystemEntityType.directory) {
    return null;
  }
  return canonicalFile;
}
