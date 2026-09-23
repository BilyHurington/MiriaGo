import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/data/reference_asset_paths.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan_transfer/plan_export_v2.dart';
import 'package:miriago/plan_transfer/plan_import_asset_restore_io.dart';
import 'package:miriago/plan_transfer/plan_import_package.dart';
import 'package:miriago/plan_transfer/plan_import_preview_screen.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

final _image = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'restore cleanup is retryable on failure and once-only on success',
    () async {
      var calls = 0;
      final paths = RestoredPlanImportAssets(
        const {},
        onDiscard: () async {
          if (++calls == 1) throw StateError('temporary cleanup failure');
        },
      );
      await expectLater(paths.discard(), throwsStateError);
      await paths.discard();
      await paths.discard();
      expect(calls, 2);
      await expectLater(paths.finalize(), throwsStateError);
    },
  );

  test(
    'finalize protects committed files even if native confirmation fails',
    () async {
      var cleanupCalls = 0;
      var finalizeCalls = 0;
      final paths = RestoredPlanImportAssets(
        const {},
        onDiscard: () async {
          cleanupCalls++;
        },
        onFinalize: () async {
          if (++finalizeCalls == 1) {
            throw StateError('temporary finalize failure');
          }
        },
      );
      await expectLater(paths.finalize(), throwsStateError);
      await paths.discard();
      await paths.finalize();
      await paths.finalize();
      await paths.discard();
      expect(cleanupCalls, 0);
      expect(finalizeCalls, 2);
    },
  );

  for (final path in [
    '../escape.jpg',
    '/assets/a.jpg',
    r'C:\assets\a.jpg',
    r'\\host\assets\a.jpg',
    r'\??\C:\assets\a.jpg',
    'assets/C:/a.jpg',
    'assets/a.jpg:stream',
    'assets/../a.jpg',
    r'assets\..\a.jpg',
    'assets/./a.jpg',
    'assets//a.jpg',
    'assets/a\x00.jpg',
    'assets/a\n.jpg',
    'assets/a. /b.jpg',
    'assets/NUL.jpg',
    'assets/COM1/a.jpg',
    'assets/Lpt9.txt',
    'assets/a./b.jpg',
    'assets/a /b.jpg',
  ]) {
    test('rejects cross-platform asset path $path', () {
      expect(isSafeRelativeAssetPath(path), isFalse);
    });
  }
  test('safe Windows separators and Unicode asset names remain compatible', () {
    expect(isSafeRelativeAssetPath(r'assets\visit_photos\写真.jpg'), isTrue);
  });

  test('compressed byte limit is checked before parsing', () {
    expect(
      () => _read(
        Uint8List(20),
        limits: const PlanImportLimits(maxCompressedBytes: 10),
      ),
      throwsA(_limit('压缩包字节数', 20, 10)),
    );
  });
  test('ZIP header collection is bounded, including ignored files', () {
    final bytes = _zip(
      assets: {
        'ignored.bin': [1],
      },
    );
    expect(
      () => _read(bytes, limits: const PlanImportLimits(maxEntries: 2)),
      throwsA(_limit('ZIP 条目数', 3, 2)),
    );
  });
  test('JSON and declared single-entry budgets report their own limit', () {
    expect(
      () => _read(_zip(), limits: const PlanImportLimits(maxJsonBytes: 10)),
      throwsA(
        isA<PlanImportLimitException>().having(
          (e) => e.resource,
          'resource',
          'JSON 字节数',
        ),
      ),
    );
    expect(
      () => _read(
        _zip(assets: {'ignored.bin': Uint8List(2048)}),
        limits: const PlanImportLimits(maxEntryBytes: 1024),
      ),
      throwsA(_limit('单文件解压字节数', 2048, 1024)),
    );
  });
  test('forged ZIP sizes cannot bypass the actual streaming output budget', () {
    final bytes = _zip(assets: {'ignored.bin': Uint8List(8192)});
    _forgeLastSize(bytes, 1);
    expect(
      () => _read(bytes, limits: const PlanImportLimits(maxEntryBytes: 1024)),
      throwsA(
        isA<PlanImportLimitException>()
            .having((e) => e.resource, 'resource', '单文件解压字节数')
            .having((e) => e.actual, 'actual', greaterThan(1024)),
      ),
    );
  });
  test('total expanded quota counts ignored entries and real output', () {
    final bytes = _zip(
      assets: {
        'ignored-a.bin': Uint8List(500),
        'ignored-b.bin': Uint8List(500),
      },
    );
    _forgeLastSize(bytes, 1);
    expect(
      () => _read(bytes, limits: const PlanImportLimits(maxExpandedBytes: 900)),
      throwsA(
        isA<PlanImportLimitException>()
            .having((e) => e.resource, 'resource', '总解压字节数')
            .having((e) => e.actual, 'actual', greaterThan(900)),
      ),
    );
  });
  test('exact compressed, entry, total and JSON boundaries are accepted', () {
    final bytes = _zip(assets: {'assets/visit_photos/a.png': _image});
    final archive = ZipDirectory()..read(InputMemoryStream(bytes));
    final total = archive.fileHeaders.fold<int>(
      0,
      (n, f) => n + f.uncompressedSize,
    );
    final max = archive.fileHeaders
        .map((f) => f.uncompressedSize)
        .reduce((a, b) => a > b ? a : b);
    final result = _read(
      bytes,
      limits: PlanImportLimits(
        maxCompressedBytes: bytes.length,
        maxEntries: 3,
        maxEntryBytes: max,
        maxExpandedBytes: total,
        maxJsonBytes: max,
        maxImagePixels: 1,
      ),
    );
    expect(result.assetEntries, hasLength(1));
  });
  test('pixel limit is enforced from dimensions before image decoding', () {
    final bytes = Uint8List.fromList(_image);
    ByteData.sublistView(bytes).setUint32(16, 100000);
    expect(
      () => _read(
        _zip(assets: {'assets/visit_photos/a.png': bytes}),
        limits: const PlanImportLimits(maxImagePixels: 16),
      ),
      throwsA(
        isA<PlanImportLimitException>().having(
          (e) => e.limit,
          'pixel limit',
          16,
        ),
      ),
    );
  });
  test('JPEG and WebP header dimensions also enforce small pixel limits', () {
    final jpeg = Uint8List.fromList([
      0xff,
      0xd8,
      0xff,
      0xc0,
      0,
      11,
      8,
      0,
      8,
      0,
      8,
      1,
      1,
      0x11,
      0,
    ]);
    final webp = Uint8List(30)
      ..setRange(0, 4, ascii.encode('RIFF'))
      ..setRange(8, 16, ascii.encode('WEBPVP8X'));
    ByteData.sublistView(webp).setUint32(16, 10, Endian.little);
    webp[24] = 7;
    webp[27] = 7;
    for (final image in [jpeg, webp]) {
      expect(
        () => _read(
          _zip(assets: {'assets/image': image}),
          limits: const PlanImportLimits(maxImagePixels: 16),
        ),
        throwsA(isA<PlanImportLimitException>()),
      );
    }
  });
  test('normal v1 input remains supported within the same JSON quota', () {
    final bytes = utf8.encode(
      jsonEncode({'format': 'miriago-plan', 'version': 1, 'plan': _plan}),
    );
    expect(_read(bytes).isLegacyJson, isTrue);
    expect(
      () => _read(bytes, limits: const PlanImportLimits(maxJsonBytes: 10)),
      throwsA(isA<PlanImportLimitException>()),
    );
  });
  test(
    'normalized aliases and case-folded duplicate ZIP paths are rejected',
    () {
      for (final alias in [r'assets\a.png', 'assets/A.png']) {
        expect(
          () => _read(_zip(assets: {'assets/a.png': _image, alias: _image})),
          throwsFormatException,
        );
      }
    },
  );
  test('symlinks are rejected without expanding their target', () {
    final bytes = _zip(assets: {'assets/a.png': _image});
    final directory = ZipDirectory()..read(InputMemoryStream(bytes));
    final data = ByteData.sublistView(bytes);
    final offset = _lastCentralHeader(directory);
    data.setUint16(offset + 4, 3 << 8, Endian.little);
    data.setUint32(offset + 38, 0xa1ff << 16, Endian.little);
    expect(() => _read(bytes), throwsFormatException);
  });
  test('stream output cancellation stops a highly compressible entry', () {
    var checks = 0;
    expect(
      () => readPlanImportPackageFromBytes(
        _zip(assets: {'ignored.bin': Uint8List(8192)}),
        sourceName: 'cancel.zip',
        isCancelled: () => ++checks > 20,
      ),
      throwsFormatException,
    );
    expect(checks, 21);
  });

  test('foreign record paths are removed even before asset application', () {
    final package = _read(_zip(records: [_record]));
    final record = package.package.visitRecords.single;
    expect(record.photoPath, isEmpty);
    expect(record.originalPhotoPath, isNull);
    expect(record.gradedPhotoPath, isNull);
    expect(record.referenceImagePath, isNull);
    final result = applyRestoredAssetPaths(
      importPackage: package,
      restoredPaths: const {},
      includeRecords: true,
    );
    expect(result.visitRecords.single.photoPath, isEmpty);
    expect(result.visitRecords.single.sourcePhotoPath, isEmpty);
    expect(result.visitRecords.single.displayPhotoPath, isEmpty);
    expect(result.warnings, isNotEmpty);
  });
  test('safe legacy package-relative record photos remain restorable', () {
    final package = _read(
      _zip(
        records: [
          {
            ..._record,
            'photoPath': r'assets\visit_photos\a.png',
            'originalPhotoPath': 'assets/visit_photos/original.png',
            'gradedPhotoPath': 'assets/graded_photos/a.png',
            'referenceImagePath': 'assets/full_references/a.png',
          },
        ],
      ),
    );
    final result = applyRestoredAssetPaths(
      importPackage: package,
      includeRecords: true,
      restoredPaths: const {
        'assets/visit_photos/a.png': '/this-import/photo.png',
        'assets/visit_photos/original.png': '/this-import/original.png',
        'assets/graded_photos/a.png': '/this-import/graded.png',
        'assets/full_references/a.png': '/this-import/reference.png',
      },
    );
    final record = result.visitRecords.single;
    expect(record.photoPath, '/this-import/photo.png');
    expect(record.originalPhotoPath, '/this-import/original.png');
    expect(record.gradedPhotoPath, '/this-import/graded.png');
    expect(record.referenceImagePath, '/this-import/reference.png');
  });
  test('record references reuse only this import same-plan point assets', () {
    for (final recordPlan in ['p', 'foreign-plan']) {
      final package = _read(
        _zip(
          plan: {
            ..._plan,
            'works': [
              {'id': 'w'},
            ],
            'points': [
              {
                'id': 'q',
                'workId': 'w',
                'referenceFullReferenceAsset': 'assets/full_references/q.png',
              },
            ],
          },
          records: [
            {..._record, 'planId': recordPlan},
          ],
        ),
      );
      final restored = applyRestoredAssetPaths(
        importPackage: package,
        includeRecords: true,
        restoredPaths: const {
          'assets/full_references/q.png': '/this-import/ref.png',
        },
      );
      expect(
        restored.visitRecords.single.referenceImagePath,
        recordPlan == 'p' ? '/this-import/ref.png' : null,
      );
    }
  });

  test('a restored thumbnail is not a complete record reference', () {
    final package = _read(
      _zip(
        plan: {
          ..._plan,
          'works': [
            {'id': 'w'},
          ],
          'points': [
            {
              'id': 'q',
              'workId': 'w',
              'referenceThumbnailAsset': 'assets/thumbnails/q.png',
            },
          ],
        },
        records: [_record],
      ),
    );
    final restored = applyRestoredAssetPaths(
      importPackage: package,
      includeRecords: true,
      restoredPaths: const {
        'assets/thumbnails/q.png': '/this-import/thumb.png',
      },
    );
    expect(restored.plan.points.single.referenceThumbnailPath, isNotNull);
    expect(restored.visitRecords.single.referenceImagePath, isNull);
  });

  for (final url in [
    '/private/photo.jpg',
    'file:///private/photo.jpg',
    r'C:\Users\private.jpg',
    'assets/photo.jpg',
    'https://user:secret@example.org/a.jpg',
  ]) {
    test(
      'import never accepts a local path or credentials as image URL: $url',
      () {
        final package = _read(
          _zip(
            plan: {
              ..._plan,
              'works': [
                {'id': 'w'},
              ],
              'points': [
                {'id': 'q', 'workId': 'w', 'referenceImageUrl': url},
              ],
            },
            records: [
              {..._record, 'referenceImageUrl': url},
            ],
          ),
        );
        final restored = applyRestoredAssetPaths(
          importPackage: package,
          includeRecords: true,
          restoredPaths: const {},
        );
        expect(restored.plan.points.single.referenceImageUrl, isNull);
        expect(restored.visitRecords.single.referenceImageUrl, isNull);
      },
    );
  }

  group('isolated native asset restoration', () {
    late Directory root;
    late PathProviderPlatform previous;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('miriago-import-security-');
      previous = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _DocumentsProvider(root.path);
    });
    tearDown(() async {
      PathProviderPlatform.instance = previous;
      await root.delete(recursive: true);
    });
    for (final commitFirst in [false, true]) {
      testWidgets(
        'repository failure preserves committed assets: $commitFirst',
        (tester) async {
          final package = _read(
            _zip(
              assets: {'assets/photo.png': _image},
              records: [
                {..._record, 'visitPhotoAsset': 'assets/photo.png'},
              ],
            ),
          );
          final old = await tester.runAsync(
            () => restorePlanImportAssets(package),
          );
          final repository = _FailingImportRepository(commitFirst);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light(),
              home: PlanImportPreviewScreen(
                importPackage: package,
                repository: repository,
              ),
            ),
          );
          await tester.tap(find.text('导入所选内容'));
          // Native file I/O runs outside the fake widget clock.
          for (
            var attempt = 0;
            attempt < 100 &&
                (repository.attempts == 0 ||
                    find.text('导入中...').evaluate().isNotEmpty);
            attempt++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump();
          }
          expect(repository.attempts, 1);
          expect(find.text('导入中...'), findsNothing);
          final directories = await tester.runAsync(
            () => Directory('${root.path}/imported_plan_assets').list().length,
          );
          expect(directories, commitFirst ? 2 : 1);
          expect(
            await tester.runAsync(() => File(old!.values.single).readAsBytes()),
            _image,
          );
          if (commitFirst) {
            final importedRecord = (await repository.loadVisitRecords(
              repository.importedId!,
            )).single;
            expect(
              await tester.runAsync(
                () => File(importedRecord.photoPath).readAsBytes(),
              ),
              _image,
            );
            expect(find.text('导入未确认完成，已保留资源以避免误删'), findsOneWidget);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
    test(
      'same packageId never shares directories, even concurrently',
      () async {
        final first = _read(_zip(assets: {'assets/a.png': _image}));
        final secondImage = Uint8List.fromList(_image)..last = 0;
        final second = _read(_zip(assets: {'assets/a.png': secondImage}));
        final results = await Future.wait([
          restorePlanImportAssets(first),
          restorePlanImportAssets(second),
        ]);
        final firstPath = results.first.values.single;
        final secondPath = results.last.values.single;
        expect(firstPath, isNot(secondPath));
        expect(await File(firstPath).readAsBytes(), _image);
        expect(await File(secondPath).readAsBytes(), secondImage);
      },
    );
    test(
      'write failure cleans only the new directory, not earlier imports',
      () async {
        final package = _read(_zip(assets: {'assets/a.png': _image}));
        final oldPaths = await restorePlanImportAssets(package);
        final failure = _withAssets(package, {
          'assets/file': _image,
          'assets/file/child.png': _image,
        });
        await expectLater(
          restorePlanImportAssets(failure),
          throwsA(isA<FileSystemException>()),
        );
        final imports = Directory('${root.path}/imported_plan_assets');
        expect(await imports.list().length, 1);
        expect(await File(oldPaths.values.single).readAsBytes(), _image);
      },
    );
    test(
      'restore independently rejects unsafe paths and cleans its writes',
      () async {
        final package = _read(_zip());
        await expectLater(
          restorePlanImportAssets(
            _withAssets(package, {
              'assets/a.png': _image,
              'assets/../../outside.png': _image,
            }),
          ),
          throwsFormatException,
        );
        expect(
          await Directory('${root.path}/imported_plan_assets').list().length,
          0,
        );
        expect(await File('${root.path}/outside.png').exists(), isFalse);
      },
    );
    test(
      'import and re-export cannot read an unrelated real local photo',
      () async {
        final secret = File('${root.path}/unrelated.png');
        await secret.writeAsBytes(_image);
        final package = _read(
          _zip(
            records: [
              {
                ..._record,
                'photoPath': secret.path,
                'originalPhotoPath': secret.path,
                'gradedPhotoPath': secret.path,
                'referenceImagePath': secret.path,
              },
            ],
          ),
        );
        final restored = applyRestoredAssetPaths(
          importPackage: package,
          restoredPaths: const {},
          includeRecords: true,
        );
        final exported = await buildPlanExportV2Package(
          plan: restored.plan,
          visitRecords: restored.visitRecords,
          options: const PlanExportV2Options(
            mode: PlanExportV2Mode.planWithRecords,
            includeFullReferenceCache: false,
          ),
        );
        final result = _read(exported.bytes);
        expect(result.assetEntries, isEmpty);
        expect(await secret.readAsBytes(), _image);
      },
    );
  });
}

Matcher _limit(String resource, int actual, int limit) =>
    isA<PlanImportLimitException>()
        .having((e) => e.resource, 'resource', resource)
        .having((e) => e.actual, 'actual', actual)
        .having((e) => e.limit, 'limit', limit)
        .having((e) => e.message, 'message', contains('$limit'));

PlanImportPackage _read(
  List<int> bytes, {
  PlanImportLimits limits = const PlanImportLimits(),
}) => readPlanImportPackageFromBytes(
  bytes,
  sourceName: 'test.sjhplan',
  limits: limits,
);

Uint8List _zip({
  Map<String, List<int>> assets = const {},
  List<Map<String, Object?>> records = const [],
  Map<String, Object?>? plan,
}) {
  final archive = Archive()
    ..addFile(
      ArchiveFile.string(
        'manifest.json',
        jsonEncode({
          'format': miriagoExportPackageFormat,
          'packageId': 'same-untrusted-id',
        }),
      ),
    )
    ..addFile(
      ArchiveFile.string(
        'plan.json',
        jsonEncode({'plan': plan ?? _plan, 'visitRecords': records}),
      ),
    );
  for (final entry in assets.entries) {
    archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

// Corrupt fixed ZIP header fields only in test fixtures; archive still parses
// all directory structures and compressed content in the production reader.
int _lastCentralHeader(ZipDirectory directory) =>
    directory.centralDirectoryOffset +
    directory.fileHeaders
        .take(directory.fileHeaders.length - 1)
        .fold<int>(
          0,
          (n, h) =>
              n +
              46 +
              utf8.encode(h.filename).length +
              (h.extraField?.length ?? 0) +
              utf8.encode(h.fileComment).length,
        );

void _forgeLastSize(Uint8List bytes, int size) {
  final directory = ZipDirectory()..read(InputMemoryStream(bytes));
  final data = ByteData.sublistView(bytes);
  data.setUint32(_lastCentralHeader(directory) + 24, size, Endian.little);
  data.setUint32(
    directory.fileHeaders.last.localHeaderOffset + 22,
    size,
    Endian.little,
  );
}

PlanImportPackage _withAssets(
  PlanImportPackage source,
  Map<String, List<int>> assets,
) => PlanImportPackage(
  kind: source.kind,
  package: source.package,
  sourceName: source.sourceName,
  manifest: source.manifest,
  assetCounts: source.assetCounts,
  assetEntries: assets,
  pointAssetRefsById: source.pointAssetRefsById,
  recordAssetRefsById: source.recordAssetRefsById,
  warnings: source.warnings,
  exportedAt: source.exportedAt,
  appVersion: source.appVersion,
  schemaVersion: source.schemaVersion,
  exportMode: source.exportMode,
);

class _DocumentsProvider extends PathProviderPlatform {
  _DocumentsProvider(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class _FailingImportRepository extends SamplePilgrimageRepository {
  _FailingImportRepository(this.commitFirst);
  final bool commitFirst;
  var attempts = 0;
  String? importedId;

  @override
  Future<PilgrimagePlan> importPlanPackage({
    required PilgrimagePlan plan,
    required List<PilgrimageVisitRecord> visitRecords,
  }) async {
    attempts++;
    if (commitFirst) {
      importedId = (await super.importPlanPackage(
        plan: plan,
        visitRecords: visitRecords,
      )).id;
    }
    throw StateError('injected repository failure');
  }
}

const _plan = <String, Object?>{
  'id': 'p',
  'name': 'Plan',
  'area': 'Test',
  'works': [],
  'points': [],
};
const _record = <String, Object?>{
  'id': 'r',
  'planId': 'p',
  'pointId': 'q',
  'workId': 'w',
  'photoPath': '/foreign/photo.jpg',
  'originalPhotoPath': r'C:\private\original.jpg',
  'gradedPhotoPath': 'assets/imported_plan_assets/old/private.jpg',
  'referenceImagePath': '/foreign/ref.jpg',
};
