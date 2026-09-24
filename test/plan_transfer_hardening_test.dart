import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan_transfer/my_maps_csv_export.dart';
import 'package:miriago/plan_transfer/plan_export_v2.dart';
import 'package:miriago/plan_transfer/plan_import_package.dart';
import 'package:miriago/plan_transfer/plan_package.dart';
import 'package:miriago/plan_transfer/plan_transfer_background.dart';

const _thumbnail = 'docs/sample_images/铃音-记录详情页面-调色前.jpg';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('asset names', () {
    test('ids that sanitize or case-fold alike stay importable', () async {
      final plan = await SamplePilgrimageRepository().loadActivePlan();
      final template = plan.points.first;
      final ids = ['a b', 'a_b', 'Point', 'point', 'x/y', 'x:y', 'p' * 200];
      final exportPlan = plan.copyWith(
        points: [
          for (final id in ids)
            template.copyWith(id: id, referenceThumbnailPath: _thumbnail),
        ],
        currentPointId: null,
      );

      final package = await buildPlanExportV2Package(
        plan: exportPlan,
        visitRecords: const [],
        options: const PlanExportV2Options(
          mode: PlanExportV2Mode.planOnly,
          includeFullReferenceCache: false,
        ),
      );

      final names = ZipDecoder()
          .decodeBytes(package.bytes)
          .files
          .map((file) => file.name)
          .where((name) => name.startsWith('assets/'))
          .toList();
      expect(names, hasLength(ids.length));
      expect(names.map((name) => name.toLowerCase()).toSet(), hasLength(7));
      expect(names.every((name) => name.length < 120), isTrue);

      final imported = readPlanImportPackageFromBytes(
        package.bytes,
        sourceName: 'collisions.sjhplan',
      );
      expect(imported.assetEntries, hasLength(ids.length));
      for (final id in ids) {
        final ref = imported.pointAssetRefsById[id]!.referenceThumbnailAsset;
        expect(imported.assetEntries.containsKey(ref), isTrue, reason: id);
      }
    });

    test('safe ids keep their readable asset name', () {
      expect(planExportAssetStem('point-1'), 'point-1');
      expect(planExportAssetStem('a b'), startsWith('a_b_'));
      expect(planExportAssetStem('a b'), isNot(planExportAssetStem('a_b')));
      expect(planExportAssetStem('p' * 200).length, lessThanOrEqualTo(89));
    });
  });

  group('CSV export', () {
    test('package CSVs neutralize formulas and carry a UTF-8 BOM', () async {
      final plan = await SamplePilgrimageRepository().loadActivePlan();
      final point = plan.points.first.copyWith(
        name: '=HYPERLINK("http://evil.example","x")',
        subtitle: '@SUM(1+1)',
        position: const LatLng(-33.5, -70.25),
      );
      final package = await buildPlanExportV2Package(
        plan: plan.copyWith(points: [point], currentPointId: null),
        visitRecords: const [],
        options: const PlanExportV2Options(
          mode: PlanExportV2Mode.planOnly,
          includeFullReferenceCache: false,
        ),
      );
      final bytes = ZipDecoder()
          .decodeBytes(package.bytes)
          .findFile('points.csv')!
          .readBytes()!;
      expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
      final line = const LineSplitter().convert(utf8.decode(bytes))[1];
      expect(line, contains('"\'=HYPERLINK(""http://evil.example"",""x"")"'));
      expect(line, contains(",'@SUM(1+1),"));
      // Numeric coordinates are never prefixed.
      expect(line, contains(',-33.5,-70.25,'));
    });

    test('My Maps CSV keeps coordinates raw but escapes text', () async {
      final plan = await SamplePilgrimageRepository().loadActivePlan();
      final point = plan.points.first.copyWith(
        name: '-cmd|calc',
        subtitle: '+1',
        position: const LatLng(-33.5, -70.25),
      );
      final csv = utf8.decode(
        buildMyMapsCsvExport(
          plan: plan.copyWith(points: [point]),
          exportedAt: DateTime.utc(2026, 7, 27),
        ).bytes,
      );
      final row = csv.split('\r\n')[1].split(',');
      expect(row[0], "'-cmd|calc");
      expect(row[1], '-33.5000000');
      expect(row[2], '-70.2500000');
      expect(row[4], "'+1");
    });
  });

  group('imported coordinates', () {
    Map<String, Object?> pointJson(String id, Object? lat, Object? lng) => {
      'id': id,
      'workId': 'w',
      'name': id,
      'latitude': lat,
      'longitude': lng,
    };

    Uint8List v2Zip(List<Map<String, Object?>> points) {
      final archive = Archive()
        ..addFile(
          ArchiveFile.string(
            'manifest.json',
            jsonEncode({'format': miriagoExportPackageFormat}),
          ),
        )
        ..addFile(
          ArchiveFile.string(
            'plan.json',
            jsonEncode({
              'plan': {
                'id': 'p',
                'name': 'p',
                'works': [
                  {'id': 'w', 'title': 'w'},
                ],
                'groups': [
                  {
                    'id': 'g',
                    'name': 'g',
                    'anchorLatitude': 1000,
                    'anchorLongitude': 10,
                  },
                ],
                'points': points,
              },
            }),
          ),
        );
      return Uint8List.fromList(ZipEncoder().encode(archive));
    }

    test('v2 import marks out-of-range coordinates as pending', () {
      final imported = readPlanImportPackageFromBytes(
        v2Zip([
          pointJson('ok', 35.5, 139.7),
          pointJson('lat', 1000, 10),
          pointJson('lng', 10, -181),
          pointJson('missing', null, 10),
          pointJson('text', '35', '139'),
          pointJson('pending', -90, 0),
        ]),
        sourceName: 'coords.sjhplan',
      );
      final byId = {
        for (final point in imported.package.plan.points) point.id: point,
      };
      expect(byId['ok']!.position.latitude, 35.5);
      expect(byId['ok']!.hasCoordinate, isTrue);
      for (final id in ['lat', 'lng', 'missing', 'text', 'pending']) {
        expect(byId[id]!.hasCoordinate, isFalse, reason: id);
      }
      expect(imported.warnings.first, startsWith('4 个点位坐标无效'));
      expect(imported.package.plan.groups.single.anchorLatitude, isNull);
      expect(imported.package.plan.groups.single.anchorLongitude, isNull);
    });

    test('legacy JSON import marks out-of-range coordinates as pending', () {
      final source = jsonEncode({
        'format': 'miriago-plan',
        'version': 1,
        'plan': {
          'id': 'p',
          'name': 'p',
          'works': [
            {'id': 'w', 'title': 'w'},
          ],
          'points': [pointJson('ok', 35.5, 139.7), pointJson('bad', 91, 0)],
        },
      });
      final plan = PlanPackage.fromJsonString(source).plan;
      expect(plan.points.first.hasCoordinate, isTrue);
      expect(plan.points.last.hasCoordinate, isFalse);
      expect(importedCoordinate(double.infinity, 0), isNull);
      expect(importedCoordinate(double.nan, 0), isNull);
      expect(importedCoordinate(90, 180)!.latitude, 90);
    });
  });

  group('background runner', () {
    test('parses in a worker isolate with identical results', () async {
      final plan = await SamplePilgrimageRepository().loadActivePlan();
      final package = await buildPlanExportV2Package(
        plan: plan,
        visitRecords: const [],
        options: const PlanExportV2Options(
          mode: PlanExportV2Mode.planOnly,
          includeFullReferenceCache: false,
        ),
      );
      final bytes = Uint8List.fromList(package.bytes);
      final background = await readPlanImportPackageInBackground(
        bytes,
        sourceName: 'bg.sjhplan',
      );
      final inline = readPlanImportPackageFromBytes(
        bytes,
        sourceName: 'bg.sjhplan',
      );
      expect(background.pointCount, inline.pointCount);
      expect(background.package.plan.name, plan.name);
      expect(
        background.package.plan.points.map((point) => point.id),
        inline.package.plan.points.map((point) => point.id),
      );
    });

    test('limit errors keep their type across the isolate boundary', () {
      final oversized = Uint8List(4 * 1024 * 1024 + 1);
      expect(
        readPlanImportPackageInBackground(oversized, sourceName: 'big.json'),
        throwsA(isA<PlanImportLimitException>()),
      );
    });

    test('cancellation stops the worker and reports cancellation', () async {
      final cancellation = PlanTransferCancellation();
      final result = runPlanTransferTask(
        _spinForever,
        cancellation: cancellation,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      cancellation.cancel();
      await expectLater(
        result.timeout(const Duration(seconds: 5)),
        throwsA(isA<PlanTransferCancelledException>()),
      );
    });

    test('an already-cancelled task never starts', () {
      final cancellation = PlanTransferCancellation()..cancel();
      expect(
        runPlanTransferTask(() => 1, cancellation: cancellation),
        throwsA(isA<PlanTransferCancelledException>()),
      );
    });
  });
}

int _spinForever() {
  var value = 0;
  while (true) {
    value = (value + 1) & 0xffff;
  }
}
