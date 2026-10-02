import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../data/anitabi_image_url.dart';
import '../data/image_bytes.dart';
import '../data/reference_asset_paths.dart';
import '../plan/pilgrimage_models.dart';
import '../plan/reference_image_status.dart';
import 'plan_export_v2.dart';
import 'plan_package.dart';
import 'plan_transfer_background.dart';

enum PlanImportPackageKind { legacyJson, miriagoZip }

class PlanImportLimits {
  const PlanImportLimits({
    this.maxCompressedBytes = 128 * 1024 * 1024,
    this.maxEntries = 4096,
    this.maxEntryBytes = 64 * 1024 * 1024,
    this.maxExpandedBytes = 256 * 1024 * 1024,
    this.maxJsonBytes = 4 * 1024 * 1024,
    this.maxImagePixels = 40 * 1000 * 1000,
  });

  final int maxCompressedBytes;
  final int maxEntries;
  final int maxEntryBytes;
  final int maxExpandedBytes;
  final int maxJsonBytes;
  final int maxImagePixels;
}

class PlanImportLimitException extends FormatException {
  PlanImportLimitException(this.resource, this.actual, this.limit)
    : super('导入超限：$resource 为 $actual，上限 $limit。请拆分计划或减少打包图片后重试。');

  final String resource;
  final num actual;
  final int limit;
}

void _checkExpandedBudget(
  int size,
  int previous,
  bool isJson,
  PlanImportLimits limits,
) {
  if (size > limits.maxEntryBytes) {
    throw PlanImportLimitException('单文件解压字节数', size, limits.maxEntryBytes);
  }
  if (isJson && size > limits.maxJsonBytes) {
    throw PlanImportLimitException('JSON 字节数', size, limits.maxJsonBytes);
  }
  if (size + previous > limits.maxExpandedBytes) {
    throw PlanImportLimitException(
      '总解压字节数',
      size + previous,
      limits.maxExpandedBytes,
    );
  }
}

class PlanImportPackage {
  const PlanImportPackage({
    required this.kind,
    required this.package,
    required this.sourceName,
    required this.manifest,
    required this.assetCounts,
    required this.assetEntries,
    required this.pointAssetRefsById,
    required this.recordAssetRefsById,
    required this.warnings,
    required this.exportedAt,
    required this.appVersion,
    required this.schemaVersion,
    required this.exportMode,
  });

  final PlanImportPackageKind kind;
  final PlanPackage package;
  final String sourceName;
  final Map<String, Object?> manifest;
  final Map<String, int> assetCounts;
  final Map<String, List<int>> assetEntries;
  final Map<String, PlanImportPointAssetRefs> pointAssetRefsById;
  final Map<String, PlanImportRecordAssetRefs> recordAssetRefsById;
  final List<String> warnings;
  final DateTime? exportedAt;
  final String? appVersion;
  final int? schemaVersion;
  final String? exportMode;

  bool get isLegacyJson => kind == PlanImportPackageKind.legacyJson;

  bool get hasVisitRecords => package.visitRecords.isNotEmpty;

  bool get hasAssets => assetCounts.values.any((count) => count > 0);

  bool get hasRestorableAssets => assetEntries.isNotEmpty;

  /// Package asset paths plan.json actually points to: every point asset,
  /// plus record assets when records are imported.
  Set<String> referencedAssetPaths({required bool includeRecords}) => {
    for (final refs in pointAssetRefsById.values) ...[
      ?refs.referenceThumbnailAsset,
      ?refs.referenceFullReferenceAsset,
      ?refs.userReferenceAsset,
    ],
    if (includeRecords)
      for (final refs in recordAssetRefsById.values) ...[
        ?refs.visitPhotoAsset,
        ?refs.gradedPhotoAsset,
        ?refs.originalPhotoAsset,
        ?refs.referenceImageAsset,
      ],
  };

  /// A copy whose [assetEntries] only holds assets that the imported plan
  /// (and records, when [includeRecords]) reference, so unreferenced files in
  /// the archive are never written to disk.
  PlanImportPackage withReferencedAssetsOnly({required bool includeRecords}) {
    final referenced = referencedAssetPaths(includeRecords: includeRecords);
    return PlanImportPackage(
      kind: kind,
      package: package,
      sourceName: sourceName,
      manifest: manifest,
      assetCounts: assetCounts,
      assetEntries: {
        for (final entry in assetEntries.entries)
          if (referenced.contains(normalizeAssetPathSeparators(entry.key)))
            entry.key: entry.value,
      },
      pointAssetRefsById: pointAssetRefsById,
      recordAssetRefsById: recordAssetRefsById,
      warnings: warnings,
      exportedAt: exportedAt,
      appVersion: appVersion,
      schemaVersion: schemaVersion,
      exportMode: exportMode,
    );
  }

  int get totalAssetCount =>
      assetCounts.values.fold(0, (total, count) => total + count);

  int get workCount => package.plan.works.length;

  int get groupCount => package.plan.groups.length;

  int get pointCount => package.plan.points.length;

  int get visitRecordCount => package.visitRecords.length;

  String get versionLabel => switch (kind) {
    PlanImportPackageKind.legacyJson => 'v1.0 JSON',
    PlanImportPackageKind.miriagoZip => 'v2 数据包',
  };
}

class PlanImportPointAssetRefs {
  const PlanImportPointAssetRefs({
    this.referenceThumbnailAsset,
    this.referenceFullReferenceAsset,
    this.userReferenceAsset,
  });

  final String? referenceThumbnailAsset;
  final String? referenceFullReferenceAsset;
  final String? userReferenceAsset;

  bool get hasAny =>
      referenceThumbnailAsset != null ||
      referenceFullReferenceAsset != null ||
      userReferenceAsset != null;
}

class PlanImportRecordAssetRefs {
  const PlanImportRecordAssetRefs({
    this.visitPhotoAsset,
    this.gradedPhotoAsset,
    this.originalPhotoAsset,
    this.referenceImageAsset,
    this.usePointReference = false,
  });

  final String? visitPhotoAsset;
  final String? gradedPhotoAsset;
  final String? originalPhotoAsset;
  final String? referenceImageAsset;
  final bool usePointReference;

  bool get hasAny =>
      visitPhotoAsset != null ||
      gradedPhotoAsset != null ||
      originalPhotoAsset != null ||
      referenceImageAsset != null ||
      usePointReference;
}

class RestoredPlanImportData {
  const RestoredPlanImportData({
    required this.plan,
    required this.visitRecords,
    required this.warnings,
  });

  final PilgrimagePlan plan;
  final List<PilgrimageVisitRecord> visitRecords;
  final List<String> warnings;
}

class RestoredPlanImportAssets extends UnmodifiableMapBase<String, String> {
  RestoredPlanImportAssets(
    Map<String, String> paths, {
    required this.onDiscard,
    this.onFinalize,
    this.canDiscardAfterRepositoryRead = true,
  }) : _paths = Map.unmodifiable(paths);

  final Map<String, String> _paths;
  final Future<void> Function() onDiscard;
  final Future<void> Function()? onFinalize;
  // A desktop repository read may only reflect cached state after an IPC error.
  final bool canDiscardAfterRepositoryRead;
  Future<void>? _discarding;
  Future<void>? _finalizing;
  bool _committed = false;

  @override
  Iterable<String> get keys => _paths.keys;
  @override
  String? operator [](Object? key) => _paths[key];

  // The callback is created by the restorer and captures its owned directory;
  // no caller-provided path is ever used as a recursive deletion target.
  Future<void> discard() async {
    if (_committed) return;
    try {
      await (_discarding ??= onDiscard());
    } catch (_) {
      _discarding = null;
      rethrow;
    }
  }

  Future<void> finalize() async {
    if (_discarding != null) {
      throw StateError('Import assets were already discarded.');
    }
    // Protect committed files even if revoking the native token fails.
    _committed = true;
    try {
      await (_finalizing ??= onFinalize?.call() ?? Future.value());
    } catch (_) {
      _finalizing = null;
      rethrow;
    }
  }
}

PlanImportPackage readPlanImportPackageFromBytes(
  List<int> bytes, {
  required String sourceName,
  PlanImportLimits limits = const PlanImportLimits(),
  bool Function()? isCancelled,
}) {
  if (bytes.length > limits.maxCompressedBytes) {
    throw PlanImportLimitException(
      '压缩包字节数',
      bytes.length,
      limits.maxCompressedBytes,
    );
  }
  if (_looksLikeZip(bytes)) {
    return _readV2ZipPackage(
      bytes,
      sourceName: sourceName,
      limits: limits,
      isCancelled: isCancelled,
    );
  }
  // Other apps hand over arbitrary application/octet-stream files; reject
  // anything that is neither a ZIP package nor a JSON object up front instead
  // of reporting it as an oversized JSON plan.
  if (!_looksLikeJsonObject(bytes)) {
    throw const FormatException('Not a MiriaGo plan package.');
  }
  if (bytes.length > limits.maxJsonBytes) {
    throw PlanImportLimitException(
      'JSON 字节数',
      bytes.length,
      limits.maxJsonBytes,
    );
  }
  final package = PlanPackage.fromJsonString(utf8.decode(bytes));
  final planOnlyPackage = PlanPackage(
    plan: package.plan,
    visitRecords: const <PilgrimageVisitRecord>[],
  );
  return PlanImportPackage(
    kind: PlanImportPackageKind.legacyJson,
    package: planOnlyPackage,
    sourceName: sourceName,
    manifest: const {},
    assetCounts: const {},
    assetEntries: const {},
    pointAssetRefsById: const {},
    recordAssetRefsById: const {},
    warnings: const [],
    exportedAt: null,
    appVersion: null,
    schemaVersion: 1,
    exportMode: 'legacy_json',
  );
}

/// A plan file inside a downloaded archive.
class PlanArchiveEntry {
  const PlanArchiveEntry({required this.name, required this.size});

  /// Path inside the archive.
  final String name;

  /// Uncompressed size in bytes.
  final int size;

  String get fileName => name.split('/').last;
}

/// The downloaded archive holds several plan files; the user picks one and
/// the read is repeated with its [PlanArchiveEntry.name].
class PlanArchiveChoiceRequired implements Exception {
  const PlanArchiveChoiceRequired(this.entries);

  final List<PlanArchiveEntry> entries;

  @override
  String toString() => 'PlanArchiveChoiceRequired(${entries.length})';
}

/// The downloaded archive is a ZIP without a plan package in it.
class PlanArchiveHasNoPlanException implements Exception {
  const PlanArchiveHasNoPlanException();

  @override
  String toString() => 'PlanArchiveHasNoPlanException';
}

/// Reads a downloaded plan: a .sjhplan (or legacy JSON) as is, or a ZIP
/// that carries .sjhplan files next to other material (e.g. a release
/// "full pack" with notes). [entryName] picks one of several; without it a
/// [PlanArchiveChoiceRequired] lists them.
PlanImportPackage readPlanImportPackageFromDownload(
  List<int> bytes, {
  required String sourceName,
  String? entryName,
  PlanImportLimits limits = const PlanImportLimits(),
  bool Function()? isCancelled,
}) {
  if (bytes.length > limits.maxCompressedBytes) {
    throw PlanImportLimitException(
      '压缩包字节数',
      bytes.length,
      limits.maxCompressedBytes,
    );
  }
  if (!_looksLikeZip(bytes)) {
    return readPlanImportPackageFromBytes(
      bytes,
      sourceName: sourceName,
      limits: limits,
      isCancelled: isCancelled,
    );
  }
  void checkCancellation() {
    if (isCancelled?.call() ?? false) {
      throw const FormatException('Import cancelled.');
    }
  }

  final directory = _LimitedZipDirectory(limits.maxEntries, checkCancellation);
  directory.read(InputMemoryStream(bytes));
  final headers = directory.fileHeaders;
  if (headers.any(
    (header) =>
        normalizeAssetPathSeparators(header.filename) == 'manifest.json',
  )) {
    // A MiriaGo package itself.
    return readPlanImportPackageFromBytes(
      bytes,
      sourceName: sourceName,
      limits: limits,
      isCancelled: isCancelled,
    );
  }
  final plans = [
    for (final header in headers)
      if (_isPlanArchiveEntryName(
        normalizeAssetPathSeparators(header.filename),
      ))
        header,
  ];
  if (plans.isEmpty) {
    throw const PlanArchiveHasNoPlanException();
  }
  final ZipFileHeader chosen;
  if (entryName != null) {
    chosen = plans.firstWhere(
      (header) => normalizeAssetPathSeparators(header.filename) == entryName,
      orElse: () => throw const PlanArchiveHasNoPlanException(),
    );
  } else if (plans.length == 1) {
    chosen = plans.single;
  } else {
    throw PlanArchiveChoiceRequired([
      for (final header in plans)
        PlanArchiveEntry(
          name: normalizeAssetPathSeparators(header.filename),
          size: header.uncompressedSize,
        ),
    ]);
  }
  final inner = _readSinglePlanEntry(chosen, limits, checkCancellation);
  return readPlanImportPackageFromBytes(
    inner,
    sourceName: normalizeAssetPathSeparators(chosen.filename).split('/').last,
    limits: limits,
    isCancelled: isCancelled,
  );
}

bool _isPlanArchiveEntryName(String name) {
  final lower = name.toLowerCase();
  final fileName = lower.split('/').last;
  return lower.endsWith('.$seichiPlanFileExtension') &&
      !lower.startsWith('__macosx/') &&
      !lower.contains('/__macosx/') &&
      !fileName.startsWith('.');
}

Uint8List _readSinglePlanEntry(
  ZipFileHeader header,
  PlanImportLimits limits,
  void Function() checkCancellation,
) {
  final file = header.file!;
  if (file.filename != header.filename ||
      (header.generalPurposeBitFlag | file.flags) & 0x41 != 0 ||
      ![0, 8].contains(header.compressionMethod) ||
      header.uncompressedSize < 0) {
    throw const FormatException('Ambiguous or unsupported ZIP entry.');
  }
  if (header.uncompressedSize > limits.maxCompressedBytes) {
    throw PlanImportLimitException(
      '计划文件字节数',
      header.uncompressedSize,
      limits.maxCompressedBytes,
    );
  }
  final output = _CappedOutput(limits.maxCompressedBytes, checkCancellation);
  final input = file.getStream(decompress: false);
  if (header.compressionMethod == 8) {
    Inflate.stream(input, output: output);
  } else {
    output.writeStream(input);
  }
  final content = output.getBytes();
  if (content.length != header.uncompressedSize ||
      getCrc32(content) != header.crc32) {
    throw const FormatException('Invalid ZIP size or checksum.');
  }
  return content;
}

class _CappedOutput extends OutputMemoryStream {
  _CappedOutput(this.limit, this.check) : super(size: 1024);

  final int limit;
  final void Function() check;

  void _reserve(int count) {
    check();
    if (length + count > limit) {
      throw PlanImportLimitException('计划文件字节数', length + count, limit);
    }
  }

  @override
  void writeByte(int value) {
    _reserve(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _reserve(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _reserve(stream.length);
    super.writeStream(stream);
  }
}

/// Parses [bytes] in a worker isolate on native platforms so ZIP inflate,
/// CRC and JSON work cannot stall the UI isolate. All limits of
/// [readPlanImportPackageFromBytes] still apply inside the worker.
Future<PlanImportPackage> readPlanImportPackageInBackground(
  Uint8List bytes, {
  required String sourceName,
  PlanTransferCancellation? cancellation,
}) {
  return runPlanTransferTask(
    () => readPlanImportPackageFromBytes(bytes, sourceName: sourceName),
    cancellation: cancellation,
  );
}

bool _looksLikeZip(List<int> bytes) {
  return bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4B &&
      bytes[2] == 0x03 &&
      bytes[3] == 0x04;
}

bool _looksLikeJsonObject(List<int> bytes) {
  var index = 0;
  // Optional UTF-8 BOM.
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    index = 3;
  }
  for (; index < bytes.length; index++) {
    final byte = bytes[index];
    if (byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D) {
      continue;
    }
    return byte == 0x7B; // '{'
  }
  return false;
}

// ZipDecoder eagerly expands symlink targets, and the native ZLibDecoder's
// decodeStream buffers its entire result. Use archive's directory parser and
// Inflate directly so every output write is checked before allocation.
Map<String, Uint8List> _readBoundedZip(
  List<int> bytes,
  PlanImportLimits limits,
  bool Function()? isCancelled,
) {
  void checkCancellation() {
    if (isCancelled?.call() ?? false) {
      throw const FormatException('Import cancelled.');
    }
  }

  checkCancellation();
  final directory = _LimitedZipDirectory(limits.maxEntries, checkCancellation);
  directory.read(InputMemoryStream(bytes));
  if (directory.filePosition < 0 ||
      directory.numberOfThisDisk != 0 ||
      directory.diskWithTheStartOfTheCentralDirectory != 0 ||
      directory.totalCentralDirectoryEntries != directory.fileHeaders.length) {
    throw const FormatException('Invalid ZIP directory.');
  }
  final entries = <String, Uint8List>{};
  final names = <String>{};
  var expanded = 0;
  for (final header in directory.fileHeaders) {
    checkCancellation();
    final file = header.file!;
    final name = normalizeAssetPathSeparators(header.filename);
    final mode = (header.externalFileAttributes >> 16) & 0xf000;
    if (!names.add(name.toLowerCase()) ||
        file.filename != header.filename ||
        (header.generalPurposeBitFlag | file.flags) & 0x41 != 0 ||
        ![0, 8].contains(header.compressionMethod) ||
        file.compressionMethod !=
            (header.compressionMethod == 0
                ? CompressionType.none
                : CompressionType.deflate) ||
        ![0, 0x8000, 0x4000].contains(mode)) {
      throw const FormatException('Ambiguous or unsupported ZIP entry.');
    }
    final isJson = name == 'manifest.json' || name == 'plan.json';
    if (header.uncompressedSize < 0) {
      throw const FormatException('Invalid ZIP size.');
    }
    _checkExpandedBudget(header.uncompressedSize, expanded, isJson, limits);
    final output = _BoundedImportOutput(
      limits,
      expanded,
      isJson,
      checkCancellation,
    );
    final input = file.getStream(decompress: false);
    if (header.compressionMethod == 8) {
      Inflate.stream(input, output: output);
    } else {
      output.writeStream(input);
    }
    final content = output.getBytes();
    if (content.length != header.uncompressedSize ||
        getCrc32(content) != header.crc32) {
      throw const FormatException('Invalid ZIP size or checksum.');
    }
    expanded += content.length;
    if (isJson || isSafeRelativeAssetPath(name)) {
      entries[name] = content;
    }
  }
  return entries;
}

class _LimitedZipDirectory extends ZipDirectory {
  _LimitedZipDirectory(int limit, void Function() check)
    : _headers = _LimitedZipHeaders(limit, check);

  final List<ZipFileHeader> _headers;
  @override
  List<ZipFileHeader> get fileHeaders => _headers;
}

class _LimitedZipHeaders extends ListBase<ZipFileHeader> {
  _LimitedZipHeaders(this.limit, this.check);
  final int limit;
  final void Function() check;
  final _values = <ZipFileHeader>[];

  @override
  int get length => _values.length;
  @override
  set length(int value) => throw UnsupportedError('Use add');
  @override
  ZipFileHeader operator [](int index) => _values[index];
  @override
  void operator []=(int index, ZipFileHeader value) => _values[index] = value;
  @override
  void add(ZipFileHeader value) {
    check();
    if (length >= limit) {
      throw PlanImportLimitException('ZIP 条目数', length + 1, limit);
    }
    _values.add(value);
  }
}

class _BoundedImportOutput extends OutputMemoryStream {
  _BoundedImportOutput(this.limits, this.previous, this.isJson, this.check)
    : super(size: 1024);
  final PlanImportLimits limits;
  final int previous;
  final bool isJson;
  final void Function() check;

  void _reserve(int count) {
    check();
    _checkExpandedBudget(count + length, previous, isJson, limits);
  }

  @override
  void writeByte(int value) {
    _reserve(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _reserve(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _reserve(stream.length);
    super.writeStream(stream);
  }
}

// Read dimensions only. In particular image.JpegDecoder.startDecode allocates
// DCT blocks, so it is not a safe preflight for attacker-controlled dimensions.
bool _imageWithinLimit(Uint8List bytes, int maxPixels) {
  final data = ByteData.sublistView(bytes);
  int u16(int offset) => data.getUint16(offset);
  int le24(int offset) =>
      bytes[offset] | bytes[offset + 1] << 8 | bytes[offset + 2] << 16;
  bool dimensions(int width, int height, [int frames = 1]) {
    if (width <= 0 || height <= 0 || frames <= 0) return false;
    if (width > maxPixels ~/ height || frames > maxPixels ~/ (width * height)) {
      throw PlanImportLimitException(
        '图片像素（$width x $height x $frames 帧）',
        width.toDouble() * height * frames,
        maxPixels,
      );
    }
    return true;
  }

  if (isPngBytes(bytes)) {
    if (bytes.length < 33 ||
        data.getUint32(8) != 13 ||
        data.getUint32(12) != 0x49484452) {
      return false;
    }
    final width = data.getUint32(16);
    final height = data.getUint32(20);
    if (!dimensions(width, height)) return false;
    for (var offset = 8; offset + 12 <= bytes.length;) {
      final size = data.getUint32(offset);
      if (size > bytes.length - offset - 12) return false;
      final type = data.getUint32(offset + 4);
      if (type == 0x6163544c) {
        if (size != 8 ||
            !dimensions(width, height, data.getUint32(offset + 8))) {
          return false;
        }
      }
      if (type == 0x6663544c &&
          (size != 26 ||
              !dimensions(
                data.getUint32(offset + 12),
                data.getUint32(offset + 16),
              ))) {
        return false;
      }
      offset += size + 12;
    }
    return true;
  }
  if (isJpegBytes(bytes)) {
    var offset = 2;
    while (offset + 3 < bytes.length) {
      if (bytes[offset++] != 0xff) return false;
      while (offset < bytes.length && bytes[offset] == 0xff) {
        offset++;
      }
      if (offset >= bytes.length) return false;
      final marker = bytes[offset++];
      if (marker == 0xda || marker == 0xd9) return false;
      if (marker == 0x01 || (marker >= 0xd0 && marker <= 0xd7)) continue;
      if (offset + 2 > bytes.length) return false;
      final size = u16(offset);
      if (size < 2 || size > bytes.length - offset) return false;
      if (marker >= 0xc0 &&
          marker <= 0xcf &&
          ![0xc4, 0xc8, 0xcc].contains(marker)) {
        return size >= 8 && dimensions(u16(offset + 5), u16(offset + 3));
      }
      offset += size;
    }
    return false;
  }
  if (isWebpBytes(bytes)) {
    var valid = false;
    var frames = 0;
    var canvasWidth = 0;
    var canvasHeight = 0;
    for (var offset = 12; offset + 8 <= bytes.length;) {
      final size = data.getUint32(offset + 4, Endian.little);
      if (size > bytes.length - offset - 8) return false;
      final type = data.getUint32(offset);
      final start = offset + 8;
      if (type == 0x56503858 && size >= 10) {
        // VP8X
        canvasWidth = le24(start + 4) + 1;
        canvasHeight = le24(start + 7) + 1;
        valid = dimensions(canvasWidth, canvasHeight);
      } else if (type == 0x5650384c && size >= 5 && bytes[start] == 0x2f) {
        // VP8L
        final bits = data.getUint32(start + 1, Endian.little);
        valid = dimensions((bits & 0x3fff) + 1, ((bits >> 14) & 0x3fff) + 1);
      } else if (type == 0x56503820 &&
          size >= 10 &&
          le24(start + 3) == 0x2a019d) {
        // VP8
        valid = dimensions(
          data.getUint16(start + 6, Endian.little) & 0x3fff,
          data.getUint16(start + 8, Endian.little) & 0x3fff,
        );
      } else if (type == 0x414e4d46) {
        // ANMF
        if (size < 16 ||
            !dimensions(le24(start + 6) + 1, le24(start + 9) + 1) ||
            !dimensions(canvasWidth, canvasHeight, ++frames)) {
          return false;
        }
      }
      offset += 8 + size + (size & 1);
    }
    return valid;
  }
  return false;
}

PlanImportPackage _readV2ZipPackage(
  List<int> bytes, {
  required String sourceName,
  required PlanImportLimits limits,
  bool Function()? isCancelled,
}) {
  final archive = _readBoundedZip(bytes, limits, isCancelled);
  final manifest = _readArchiveJson(archive, 'manifest.json');
  if (manifest['format'] != miriagoExportPackageFormat) {
    throw const FormatException('Unsupported MiriaGo package format.');
  }
  final planRoot = _readArchiveJson(archive, 'plan.json');
  final planJson = _mapValue(planRoot['plan']);
  final visitRecordJsons = _listMaps(planRoot['visitRecords']);
  final invalidCoordinatePointIds = <String>[];
  final plan = _planFromV2Json(planJson, invalidCoordinatePointIds);
  final manifestWarnings =
      (manifest['warnings'] as List?)?.whereType<String>().toList() ??
      const <String>[];
  final records = visitRecordJsons.map(_visitRecordFromV2Json).toList();

  return PlanImportPackage(
    kind: PlanImportPackageKind.miriagoZip,
    package: PlanPackage(plan: plan, visitRecords: records),
    sourceName: sourceName,
    manifest: manifest,
    assetCounts: _intMap(manifest['assetCounts']),
    assetEntries: _archiveAssetEntries(archive, limits),
    pointAssetRefsById: _pointAssetRefsById(planJson['points']),
    recordAssetRefsById: _recordAssetRefsById(visitRecordJsons),
    warnings: [
      if (invalidCoordinatePointIds.isNotEmpty)
        '${invalidCoordinatePointIds.length} 个点位坐标无效，已改为待补充坐标',
      ...manifestWarnings,
    ],
    exportedAt: _nullableDateValue(manifest['exportedAt']),
    appVersion: manifest['appVersion'] as String?,
    schemaVersion: (manifest['schemaVersion'] as num?)?.toInt(),
    exportMode: manifest['exportMode'] as String?,
  );
}

RestoredPlanImportData applyRestoredAssetPaths({
  required PlanImportPackage importPackage,
  required Map<String, String> restoredPaths,
  required bool includeRecords,
}) {
  final warnings = <String>[];
  final restoredPlan = importPackage.package.plan.copyWith(
    points: [
      for (final point in importPackage.package.plan.points)
        _pointWithRestoredAssets(
          point,
          importPackage.pointAssetRefsById[point.id],
          restoredPaths,
          warnings,
        ),
    ],
  );
  final points = {for (final point in restoredPlan.points) point.id: point};
  final records = includeRecords
      ? [
          for (final record in importPackage.package.visitRecords)
            _recordWithRestoredAssets(
              record,
              importPackage.recordAssetRefsById[record.id],
              restoredPaths,
              warnings,
              record.planId == restoredPlan.id ? points[record.pointId] : null,
            ),
        ]
      : const <PilgrimageVisitRecord>[];
  return RestoredPlanImportData(
    plan: restoredPlan,
    visitRecords: records,
    warnings: warnings,
  );
}

Map<String, Object?> _readArchiveJson(
  Map<String, Uint8List> archive,
  String name,
) {
  final content = archive[name];
  if (content == null) {
    throw FormatException('Missing $name.');
  }
  final source = utf8.decode(content);
  final decoded = jsonDecode(source);
  return _mapValue(decoded);
}

Map<String, List<int>> _archiveAssetEntries(
  Map<String, Uint8List> archive,
  PlanImportLimits limits,
) {
  final entries = <String, List<int>>{};
  for (final file in archive.entries) {
    final name = file.key;
    if (!_isSafeAssetPath(name)) {
      continue;
    }
    final normalizedName = normalizeAssetPathSeparators(name);
    final bytes = file.value;
    if (bytes.isEmpty) {
      continue;
    }
    if (!_imageWithinLimit(bytes, limits.maxImagePixels)) {
      continue;
    }
    entries[normalizedName] = bytes;
  }
  return entries;
}

bool _isSafeAssetPath(String path) {
  return isSafeRelativeAssetPath(path);
}

Map<String, PlanImportPointAssetRefs> _pointAssetRefsById(Object? source) {
  final refs = <String, PlanImportPointAssetRefs>{};
  for (final pointJson in _listMaps(source)) {
    final id = pointJson['id'];
    if (id is! String || id.isEmpty) {
      continue;
    }
    final assetRefs = PlanImportPointAssetRefs(
      referenceThumbnailAsset: _safeAssetValue(
        pointJson['referenceThumbnailAsset'],
      ),
      referenceFullReferenceAsset: _safeAssetValue(
        pointJson['referenceFullReferenceAsset'],
      ),
      userReferenceAsset: _safeAssetValue(pointJson['userReferenceAsset']),
    );
    if (assetRefs.hasAny) {
      refs[id] = assetRefs;
    }
  }
  return refs;
}

Map<String, PlanImportRecordAssetRefs> _recordAssetRefsById(
  List<Map<String, Object?>> recordJsons,
) {
  final refs = <String, PlanImportRecordAssetRefs>{};
  for (final recordJson in recordJsons) {
    final id = recordJson['id'];
    if (id is! String || id.isEmpty) {
      continue;
    }
    final assetRefs = PlanImportRecordAssetRefs(
      visitPhotoAsset:
          _safeAssetValue(recordJson['visitPhotoAsset']) ??
          _safeAssetValue(recordJson['photoPath']),
      gradedPhotoAsset:
          _safeAssetValue(recordJson['gradedPhotoAsset']) ??
          _safeAssetValue(recordJson['gradedPhotoPath']),
      originalPhotoAsset:
          _safeAssetValue(recordJson['originalPhotoAsset']) ??
          _safeAssetValue(recordJson['originalPhotoPath']),
      referenceImageAsset:
          _safeAssetValue(recordJson['referenceImageAsset']) ??
          _safeAssetValue(recordJson['referenceImagePath']),
      usePointReference:
          recordJson['referenceImagePath'] is String &&
          (recordJson['referenceImagePath'] as String).isNotEmpty,
    );
    if (assetRefs.hasAny) {
      refs[id] = assetRefs;
    }
  }
  return refs;
}

String? _safeAssetValue(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  if (!_isSafeAssetPath(value)) {
    return null;
  }
  return normalizeAssetPathSeparators(value);
}

PilgrimagePoint _pointWithRestoredAssets(
  PilgrimagePoint point,
  PlanImportPointAssetRefs? assetRefs,
  Map<String, String> restoredPaths,
  List<String> warnings,
) {
  if (assetRefs == null) {
    if (isLocalUploadedReference(point)) {
      warnings.add('local reference not bundled: ${point.id}');
    }
    return point.copyWith(
      referenceThumbnailPath: null,
      referenceFullImagePath: null,
      referenceImageUrl: _canonicalReferenceUrl(point.referenceImageUrl),
    );
  }
  final thumbnailPath = _restoredPath(
    assetRefs.referenceThumbnailAsset,
    restoredPaths,
    warnings,
  );
  final fullReferencePath = _restoredPath(
    assetRefs.userReferenceAsset ?? assetRefs.referenceFullReferenceAsset,
    restoredPaths,
    warnings,
  );
  final hasRestoredUserReference =
      assetRefs.userReferenceAsset != null && fullReferencePath != null;
  return point.copyWith(
    referenceThumbnailPath: thumbnailPath,
    referenceFullImagePath: fullReferencePath,
    referenceImageUrl: hasRestoredUserReference
        ? null
        : _canonicalReferenceUrl(point.referenceImageUrl),
  );
}

PilgrimageVisitRecord _recordWithRestoredAssets(
  PilgrimageVisitRecord record,
  PlanImportRecordAssetRefs? assetRefs,
  Map<String, String> restoredPaths,
  List<String> warnings,
  PilgrimagePoint? referencePoint,
) {
  final photoPath = _restoredPath(
    assetRefs?.visitPhotoAsset,
    restoredPaths,
    warnings,
  );
  final gradedPhotoPath = _restoredPath(
    assetRefs?.gradedPhotoAsset,
    restoredPaths,
    warnings,
  );
  final originalPhotoPath = _restoredPath(
    assetRefs?.originalPhotoAsset,
    restoredPaths,
    warnings,
  );
  final referenceImagePath =
      _restoredPath(assetRefs?.referenceImageAsset, restoredPaths, warnings) ??
      ((assetRefs?.usePointReference ?? false) &&
              referencePoint?.work.id == record.workId
          ? referencePoint?.referenceFullImagePath
          : null);
  if (photoPath == null &&
      originalPhotoPath == null &&
      gradedPhotoPath == null) {
    warnings.add('record photo not bundled or restored: ${record.id}');
  }
  return record.copyWith(
    photoPath: photoPath ?? originalPhotoPath ?? gradedPhotoPath ?? '',
    originalPhotoPath: originalPhotoPath,
    gradedPhotoPath: gradedPhotoPath,
    referenceImagePath: referenceImagePath,
  );
}

String? _restoredPath(
  String? assetPath,
  Map<String, String> restoredPaths,
  List<String> warnings,
) {
  if (assetPath == null) {
    return null;
  }
  final normalizedAssetPath = normalizeAssetPathSeparators(assetPath);
  final restoredPath =
      restoredPaths[normalizedAssetPath] ?? restoredPaths[assetPath];
  if (restoredPath == null) {
    warnings.add('asset not restored: $normalizedAssetPath');
  }
  return restoredPath == null
      ? null
      : normalizeAssetPathSeparators(restoredPath);
}

PilgrimagePlan _planFromV2Json(
  Map<String, Object?> json,
  List<String> invalidCoordinatePointIds,
) {
  final works = _readList(json['works'], _workFromV2Json);
  final workById = {for (final work in works) work.id: work};
  final groups = _readList(json['groups'], _groupFromV2Json);
  final points = _readList(
    json['points'],
    (pointJson) =>
        _pointFromV2Json(pointJson, workById, invalidCoordinatePointIds),
  );

  return PilgrimagePlan(
    id: _stringValue(json['id'], fallback: 'imported-plan'),
    name: _stringValue(json['name'], fallback: '导入的巡礼计划'),
    area: _stringValue(json['area'], fallback: '未设置区域'),
    memo: _optionalStringValue(json['memo']) ?? '',
    works: works,
    groups: groups,
    points: points,
    createdAt: _dateValue(json['createdAt']),
    updatedAt: _dateValue(json['updatedAt']),
    currentPointId: json['currentPointId'] as String?,
    currentGroupId: json['currentGroupId'] as String?,
    completedPointIds:
        (json['completedPointIds'] as List?)?.whereType<String>().toSet() ??
        <String>{},
  );
}

PilgrimageWork _workFromV2Json(Map<String, Object?> json) {
  return PilgrimageWork(
    id: _stringValue(json['id'], fallback: 'work-${json.hashCode}'),
    bangumiId: (json['bangumiId'] as num?)?.toInt(),
    bangumiSubjectType: _enumValue(
      BangumiSubjectType.values,
      json['bangumiSubjectType'],
    ),
    coverImageUrl: json['coverImageUrl'] as String?,
    title: _stringValue(json['title'], fallback: '未知作品'),
    subtitle: _stringValue(json['subtitle'], fallback: ''),
    city: _stringValue(json['city'], fallback: '未设置地区'),
    source: _enumValue(WorkSource.values, json['source']) ?? WorkSource.manual,
  );
}

PilgrimagePlanGroup _groupFromV2Json(Map<String, Object?> json) {
  final anchor = importedCoordinate(
    json['anchorLatitude'],
    json['anchorLongitude'],
  );
  return PilgrimagePlanGroup(
    id: _stringValue(json['id'], fallback: 'group-${json.hashCode}'),
    name: _stringValue(json['name'], fallback: '未命名片区'),
    orderIndex: (json['orderIndex'] as num?)?.toInt() ?? 0,
    orderMode:
        _enumValue(PlanGroupOrderMode.values, json['orderMode']) ??
        PlanGroupOrderMode.unordered,
    anchorName: json['anchorName'] as String?,
    anchorLatitude: anchor?.latitude,
    anchorLongitude: anchor?.longitude,
    anchorPointId: json['anchorPointId'] as String?,
    note: json['note'] as String?,
    createdAt: _dateValue(json['createdAt']),
  );
}

PilgrimagePoint _pointFromV2Json(
  Map<String, Object?> json,
  Map<String, PilgrimageWork> works,
  List<String> invalidCoordinatePointIds,
) {
  final workId = _stringValue(json['workId'], fallback: 'manual-work');
  final work =
      works[workId] ??
      PilgrimageWork(
        id: workId,
        title: '未知作品',
        subtitle: '',
        city: '未设置地区',
        source: WorkSource.manual,
      );

  final id = _stringValue(json['id'], fallback: 'point-${json.hashCode}');
  final position = importedCoordinate(json['latitude'], json['longitude']);
  if (position == null) {
    invalidCoordinatePointIds.add(id);
  }

  return PilgrimagePoint(
    id: id,
    work: work,
    name: _stringValue(json['name'], fallback: '未命名点位'),
    subtitle: _stringValue(json['subtitle'], fallback: ''),
    position: position ?? PilgrimagePoint.pendingPosition,
    episodeLabel: _stringValue(json['episodeLabel'], fallback: ''),
    referenceLabel: _stringValue(json['referenceLabel'], fallback: ''),
    source:
        _enumValue(PointSource.values, json['source']) ?? PointSource.manual,
    sourceId: json['sourceId'] as String?,
    referenceImageUrl: _canonicalReferenceUrl(json['referenceImageUrl']),
    referenceThumbnailPath: json['referenceThumbnailPath'] as String?,
    referenceFullImagePath: json['referenceFullImagePath'] as String?,
    sourceUrl: json['sourceUrl'] as String?,
    note: json['note'] as String?,
    groupId: json['groupId'] as String?,
    groupOrderIndex: (json['groupOrderIndex'] as num?)?.toInt(),
  );
}

PilgrimageVisitRecord _visitRecordFromV2Json(Map<String, Object?> json) {
  return PilgrimageVisitRecord(
    id: _stringValue(json['id'], fallback: 'record-${json.hashCode}'),
    planId: _stringValue(json['planId'], fallback: ''),
    pointId: _stringValue(json['pointId'], fallback: ''),
    workId: _stringValue(json['workId'], fallback: ''),
    workTitle: json['workTitle'] as String?,
    workSubtitle: json['workSubtitle'] as String?,
    pointName: json['pointName'] as String?,
    pointSubtitle: json['pointSubtitle'] as String?,
    // Foreign device paths are metadata, never authority to read local files.
    // Bundled relative paths are captured separately in recordAssetRefsById.
    photoPath: '',
    colorGradingMode: json['colorGradingMode'] as String?,
    colorGradingParamsJson: json['colorGradingParamsJson'] as String?,
    colorGradingIntensity: (json['colorGradingIntensity'] as num?)?.toDouble(),
    referenceImageUrl: _canonicalReferenceUrl(json['referenceImageUrl']),
    referenceMode: _stringValue(json['referenceMode'], fallback: '未知'),
    capturedAt: _dateValue(json['capturedAt']),
  );
}

Map<String, int> _intMap(Object? source) {
  if (source is! Map) {
    return const {};
  }
  return {
    for (final entry in source.entries)
      if (entry.key is String && entry.value is num)
        entry.key as String: (entry.value as num).toInt(),
  };
}

Map<String, Object?> _mapValue(Object? source) {
  if (source is Map<String, Object?>) {
    return source;
  }
  if (source is Map) {
    return source.map((key, value) => MapEntry(key.toString(), value));
  }
  throw const FormatException('Invalid object payload.');
}

List<T> _readList<T>(
  Object? source,
  T Function(Map<String, Object?> json) decode,
) {
  return _listMaps(source).map(decode).toList();
}

List<Map<String, Object?>> _listMaps(Object? source) {
  if (source is! List) {
    return const [];
  }
  return source.map(_mapValue).toList();
}

T? _enumValue<T extends Enum>(List<T> values, Object? source) {
  if (source is! String) {
    return null;
  }
  for (final value in values) {
    if (value.name == source) {
      return value;
    }
  }
  return null;
}

String _stringValue(Object? value, {required String fallback}) {
  return value is String && value.isNotEmpty ? value : fallback;
}

String? _optionalStringValue(Object? value) {
  if (value is! String) {
    return null;
  }
  return value;
}

DateTime _dateValue(Object? value) {
  return _nullableDateValue(value) ?? DateTime.now();
}

DateTime? _nullableDateValue(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

String? _canonicalReferenceUrl(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return canonicalAnitabiImageUrl(uri.toString());
}
