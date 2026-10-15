import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan_transfer/plan_import_package.dart';
import 'package:miriago/plan_transfer/plan_import_preview_screen.dart';
import 'package:miriago/plan_transfer/plan_link.dart';
import 'package:miriago/plan_transfer/plan_link_import_screen.dart';
import 'package:miriago/plan_transfer/plan_package.dart';
import 'package:miriago/plan_transfer/plan_transfer_background.dart';

const _sjhplanUrl =
    'https://github.com/xiaotianMC/BanG-Dream-Visit-Plan/releases/download/'
    'v1.0.2/BanGDream-ver0903.sjhplan';
const _zipUrl =
    'https://github.com/xiaotianMC/BanG-Dream-Visit-Plan/releases/download/'
    'v1.0.2/BanGDream-FullPack-v1.0.2.zip';

Uint8List _legacyPlan() => Uint8List.fromList(
  utf8.encode(
    PlanPackage(
      plan: samplePilgrimagePlan,
      visitRecords: const [],
    ).toJsonString(),
  ),
);

Uint8List _zip(Map<String, List<int>> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  group('PlanLink.parse', () {
    test('release downloads are files', () {
      for (final url in [_sjhplanUrl, _zipUrl]) {
        final link = PlanLink.parse('  $url ');
        expect(link, isA<PlanFileLink>());
        expect((link as PlanFileLink).uri.toString(), url);
      }
      expect(
        (PlanLink.parse(_sjhplanUrl) as PlanFileLink).fileName,
        'BanGDream-ver0903.sjhplan',
      );
      expect(
        PlanLink.parse('https://example.com/dl/a.zip?x=1'),
        isA<PlanFileLink>(),
      );
    });

    test('release pages and repositories go through the GitHub API', () {
      final tagged =
          PlanLink.parse(
                'https://github.com/xiaotianMC/BanG-Dream-Visit-Plan/releases/tag/v1.0.2',
              )
              as GitHubReleaseLink;
      expect(
        tagged.apiUri.toString(),
        'https://api.github.com/repos/xiaotianMC/BanG-Dream-Visit-Plan/releases/tags/v1.0.2',
      );
      for (final input in [
        'github.com/xiaotianMC/BanG-Dream-Visit-Plan',
        'https://github.com/xiaotianMC/BanG-Dream-Visit-Plan.git',
        'https://github.com/xiaotianMC/BanG-Dream-Visit-Plan/releases',
        'https://github.com/xiaotianMC/BanG-Dream-Visit-Plan/releases/latest',
      ]) {
        final link = PlanLink.parse(input) as GitHubReleaseLink;
        expect(link.tag, isNull, reason: input);
        expect(
          link.apiUri.path,
          '/repos/xiaotianMC/BanG-Dream-Visit-Plan/releases/latest',
        );
      }
    });

    test('repository files and latest downloads are files', () {
      expect(
        (PlanLink.parse('https://github.com/o/r/blob/main/plans/a b.sjhplan')
                as PlanFileLink)
            .uri
            .toString(),
        'https://raw.githubusercontent.com/o/r/main/plans/a%20b.sjhplan',
      );
      for (final url in [
        'https://github.com/o/r/raw/main/a.sjhplan',
        'https://github.com/o/r/releases/latest/download/a.sjhplan',
      ]) {
        expect(PlanLink.parse(url), isA<PlanFileLink>(), reason: url);
      }
      expect(
        (PlanLink.parse('https://github.com/o/r/releases/tag/team/v1')
                as GitHubReleaseLink)
            .apiUri
            .toString(),
        'https://api.github.com/repos/o/r/releases/tags/team%2Fv1',
      );
      expect(
        (PlanLink.parse('https://example.com/100%25.sjhplan') as PlanFileLink)
            .fileName,
        '100%.sjhplan',
      );
    });

    test('refuses local network addresses', () {
      for (final input in [
        'https://localhost/a.sjhplan',
        'https://192.168.1.2/a.sjhplan',
        'https://[::1]/a.sjhplan',
      ]) {
        expect(
          () => PlanLink.parse(input),
          throwsA(
            isA<PlanLinkException>().having(
              (error) => error.message,
              'message',
              '不支持本机或局域网地址',
            ),
          ),
          reason: input,
        );
      }
    });

    test('refuses empty and non-HTTPS links', () {
      for (final input in [
        '',
        '   ',
        'http://example.com/a.sjhplan',
        'ftp://example.com/a.sjhplan',
        'https://user@example.com/a',
      ]) {
        expect(
          () => PlanLink.parse(input),
          throwsA(isA<PlanLinkException>()),
          reason: input,
        );
      }
    });
  });

  test('release assets keep plan files and zips, plans first', () {
    final release = parseGitHubRelease(
      jsonEncode({
        'name': 'v1.0.2',
        'tag_name': 'v1.0.2',
        'assets': [
          {
            'name': 'BanGDream-FullPack-v1.0.2.zip',
            'size': 41665792,
            'browser_download_url': _zipUrl,
          },
          {
            'name': 'BanGDream-ver0903.sjhplan',
            'size': 41687724,
            'browser_download_url': _sjhplanUrl,
          },
          {
            'name': 'notes.md',
            'size': 10,
            'browser_download_url': 'https://github.com/a/b/notes.md',
          },
        ],
      }),
    );
    expect(release.releaseName, 'v1.0.2');
    expect(release.assets.map((asset) => asset.name), [
      'BanGDream-ver0903.sjhplan',
      'BanGDream-FullPack-v1.0.2.zip',
    ]);
    expect(release.assets.first.size, 41687724);
    expect(
      () => parseGitHubRelease('<html>'),
      throwsA(isA<PlanLinkException>()),
    );
  });

  group('readPlanImportPackageFromDownload', () {
    test('reads a plan file as is', () {
      final package = readPlanImportPackageFromDownload(
        _legacyPlan(),
        sourceName: 'a.sjhplan',
      );
      expect(package.package.plan.id, samplePilgrimagePlan.id);
    });

    test('takes the only plan out of a release zip', () {
      final package = readPlanImportPackageFromDownload(
        _zip({
          'attachments/README.md': utf8.encode('# notes'),
          '__MACOSX/._计划.sjhplan': [1, 2, 3],
          '计划.sjhplan': _legacyPlan(),
        }),
        sourceName: 'FullPack.zip',
      );
      expect(package.package.plan.id, samplePilgrimagePlan.id);
      expect(package.sourceName, '计划.sjhplan');
    });

    test('asks which plan when there are several', () {
      final bytes = _zip({
        'a/one.sjhplan': _legacyPlan(),
        'two.SJHPLAN': _legacyPlan(),
      });
      PlanImportPackage choice() =>
          readPlanImportPackageFromDownload(bytes, sourceName: 'pack.zip');
      expect(
        choice,
        throwsA(
          isA<PlanArchiveChoiceRequired>().having(
            (error) => error.entries.map((entry) => entry.fileName),
            'files',
            ['one.sjhplan', 'two.SJHPLAN'],
          ),
        ),
      );
      final package = readPlanImportPackageFromDownload(
        bytes,
        sourceName: 'pack.zip',
        entryName: 'two.SJHPLAN',
      );
      expect(package.sourceName, 'two.SJHPLAN');
    });

    test('a zip with two entries of the same name is refused', () {
      final archive = Archive()
        ..addFile(ArchiveFile.bytes('a.sjhplan', _legacyPlan()))
        ..addFile(ArchiveFile.bytes('A.sjhplan', _legacyPlan()));
      expect(
        () => readPlanImportPackageFromDownload(
          ZipEncoder().encode(archive),
          sourceName: 'x.zip',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('a zip without a plan is reported', () {
      expect(
        () => readPlanImportPackageFromDownload(
          _zip({'README.md': utf8.encode('x')}),
          sourceName: 'x.zip',
        ),
        throwsA(isA<PlanArchiveHasNoPlanException>()),
      );
    });

    test('a zip with a manifest is read as a MiriaGo package', () {
      expect(
        () => readPlanImportPackageFromDownload(
          _zip({
            'manifest.json': utf8.encode('{"format":"other"}'),
            'inner.sjhplan': _legacyPlan(),
          }),
          sourceName: 'x.sjhplan',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Unsupported MiriaGo package format'),
          ),
        ),
      );
    });

    test('a plan inside a zip is limited like a picked file', () {
      expect(
        () => readPlanImportPackageFromDownload(
          _zip({'big.sjhplan': Uint8List(2048)}),
          sourceName: 'x.zip',
          limits: const PlanImportLimits(maxCompressedBytes: 1024),
        ),
        throwsA(isA<PlanImportLimitException>()),
      );
    });
  });

  group('PlanLinkImportScreen', () {
    Future<_FakeService> pumpScreen(
      WidgetTester tester, {
      _FakeService? service,
    }) async {
      final fake = service ?? _FakeService();
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: PlanLinkImportScreen(
            repository: SamplePilgrimageRepository(),
            service: fake,
          ),
        ),
      );
      return fake;
    }

    Future<void> submit(WidgetTester tester, String link) async {
      await tester.enterText(
        find.byKey(const ValueKey('plan-link-input')),
        link,
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('plan-link-start')));
      await tester.pump();
    }

    testWidgets('a release lists its files, downloads and previews', (
      tester,
    ) async {
      final service = await pumpScreen(tester);
      await submit(
        tester,
        'https://github.com/xiaotianMC/BanG-Dream-Visit-Plan/releases/tag/v1.0.2',
      );
      await tester.pumpAndSettle();
      expect(service.releaseRequests.single.tag, 'v1.0.2');
      expect(find.text('BanGDream-ver0903.sjhplan'), findsOneWidget);
      expect(find.text('BanGDream-FullPack-v1.0.2.zip'), findsOneWidget);

      service.downloadGate = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('plan-link-asset-1')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('plan-link-progress')), findsOneWidget);
      expect(find.textContaining('20.0 MB / 40.0 MB'), findsOneWidget);
      service.downloadGate!.complete();
      await tester.pumpAndSettle();

      expect(service.downloads.single.toString(), _zipUrl);
      expect(find.byType(PlanImportPreviewScreen), findsOneWidget);
      expect(service.discarded, 1);
    });

    testWidgets('several plans in a zip ask which one', (tester) async {
      final service = _FakeService()
        ..choice = const [
          PlanArchiveEntry(name: 'a/one.sjhplan', size: 1024),
          PlanArchiveEntry(name: 'two.sjhplan', size: 2048),
        ];
      await pumpScreen(tester, service: service);
      await submit(tester, _zipUrl);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('plan-link-entry-sheet')), findsOne);
      await tester.tap(find.text('two.sjhplan'));
      await tester.pumpAndSettle();
      expect(service.readEntries, [null, 'two.sjhplan']);
      expect(find.byType(PlanImportPreviewScreen), findsOneWidget);
    });

    testWidgets('errors are explained and the download is cleaned up', (
      tester,
    ) async {
      final service = _FakeService()
        ..readError = const PlanArchiveHasNoPlanException();
      await pumpScreen(tester, service: service);
      await submit(tester, _zipUrl);
      await tester.pumpAndSettle();
      expect(find.text('压缩包里没有 .sjhplan 计划文件'), findsOneWidget);
      expect(service.discarded, 1);

      await submit(tester, 'http://example.com/a.sjhplan');
      await tester.pumpAndSettle();
      expect(find.text('只支持 https:// 开头的链接'), findsOneWidget);
    });

    testWidgets('a % in the file name downloads normally', (tester) async {
      final service = await pumpScreen(tester);
      await submit(tester, 'https://example.com/100%25.sjhplan');
      await tester.pumpAndSettle();
      expect(service.downloads.single.path, '/100%25.sjhplan');
      expect(find.byType(PlanImportPreviewScreen), findsOneWidget);
    });

    testWidgets('a cancelled attempt never touches the next one', (
      tester,
    ) async {
      final service = _FakeService()..releaseGate = Completer<String>();
      final stale = service.releaseGate!;
      await pumpScreen(tester, service: service);
      await submit(tester, 'https://github.com/o/r');
      await tester.tap(find.byKey(const ValueKey('plan-link-cancel')));
      await tester.pump();

      // A new attempt is reading when the old one fails late.
      service
        ..downloadGate = null
        ..choice = const [
          PlanArchiveEntry(name: 'a.sjhplan', size: 1),
          PlanArchiveEntry(name: 'b.sjhplan', size: 1),
        ];
      await submit(tester, _zipUrl);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('plan-link-entry-sheet')), findsOne);
      stale.completeError(const PlanLinkException('late'));
      await tester.pumpAndSettle();
      expect(service.discarded, 0);
      expect(find.text('late'), findsNothing);

      await tester.tap(find.text('b.sjhplan'));
      await tester.pumpAndSettle();
      expect(find.byType(PlanImportPreviewScreen), findsOneWidget);
      expect(service.discarded, 1);
    });

    testWidgets('closing the choice discards the download', (tester) async {
      final service = _FakeService()
        ..choice = const [
          PlanArchiveEntry(name: 'a.sjhplan', size: 1),
          PlanArchiveEntry(name: 'b.sjhplan', size: 1),
        ];
      await pumpScreen(tester, service: service);
      expect(service.swept, 1);
      await submit(tester, _zipUrl);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(service.discarded, 1);
      expect(find.byType(PlanImportPreviewScreen), findsNothing);
    });

    testWidgets('cancel stops the download', (tester) async {
      final service = _FakeService()..downloadGate = Completer<void>();
      await pumpScreen(tester, service: service);
      await submit(tester, _sjhplanUrl);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('plan-link-cancel')));
      await tester.pump();
      expect(service.cancellation!.isCancelled, isTrue);
      expect(find.byKey(const ValueKey('plan-link-progress')), findsNothing);
      service.downloadGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(PlanImportPreviewScreen), findsNothing);
    });

    testWidgets('the browser build explains it cannot download', (
      tester,
    ) async {
      await pumpScreen(tester, service: _FakeService()..isAvailable = false);
      expect(find.text('网页版无法直接下载'), findsOneWidget);
      expect(
        tester
            .widget<InkWell>(
              find.descendant(
                of: find.byKey(const ValueKey('plan-link-start')),
                matching: find.byType(InkWell),
              ),
            )
            .onTap,
        isNull,
      );
    });
  });
}

class _FakeService implements PlanLinkService {
  var isAvailable = true;
  final releaseRequests = <GitHubReleaseLink>[];
  final downloads = <Uri>[];
  final readEntries = <String?>[];
  var discarded = 0;
  final discardedFiles = <DownloadedPlanFile>[];
  var swept = 0;
  Completer<String>? releaseGate;
  Completer<void>? downloadGate;
  PlanTransferCancellation? cancellation;
  List<PlanArchiveEntry>? choice;
  Object? readError;

  @override
  bool get available => isAvailable;

  @override
  Future<String> fetchRelease(GitHubReleaseLink link) async {
    releaseRequests.add(link);
    final gate = releaseGate;
    if (gate != null) {
      releaseGate = null;
      return gate.future;
    }
    return jsonEncode({
      'name': 'v1.0.2',
      'assets': [
        {
          'name': 'BanGDream-ver0903.sjhplan',
          'size': 41687724,
          'browser_download_url': _sjhplanUrl,
        },
        {
          'name': 'BanGDream-FullPack-v1.0.2.zip',
          'size': 41665792,
          'browser_download_url': _zipUrl,
        },
      ],
    });
  }

  @override
  Future<DownloadedPlanFile> download(
    Uri uri, {
    required String fileName,
    PlanLinkProgress? onProgress,
    PlanTransferCancellation? cancellation,
  }) async {
    downloads.add(uri);
    this.cancellation = cancellation;
    onProgress?.call(20 * 1024 * 1024, 40 * 1024 * 1024);
    await downloadGate?.future;
    return DownloadedPlanFile(fileName: fileName, bytes: const []);
  }

  @override
  Future<PlanImportPackage> read(
    DownloadedPlanFile file, {
    String? entryName,
    PlanTransferCancellation? cancellation,
  }) async {
    readEntries.add(entryName);
    final error = readError;
    if (error != null) throw error;
    final entries = choice;
    if (entries != null && entryName == null) {
      throw PlanArchiveChoiceRequired(entries);
    }
    return readPlanImportPackageFromBytes(
      _legacyPlan(),
      sourceName: entryName ?? file.fileName,
    );
  }

  @override
  Future<void> discard(DownloadedPlanFile file) async {
    discarded++;
    discardedFiles.add(file);
  }

  @override
  Future<void> sweep() async {
    swept++;
  }
}
