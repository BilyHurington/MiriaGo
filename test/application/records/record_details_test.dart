import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/application/records/record_details.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/records/comparison_export_config.dart';

import 'records_fixture.dart';

void main() {
  group('reference resolution', () {
    test('local: record path, then point full image, only when present', () {
      final details = RecordDetails(
        localFileExists: (path) => path == 'full/bridge.jpg',
        isWeb: false,
      );
      final point = pointBridge.copyWith(
        referenceFullImagePath: 'full/bridge.jpg',
      );
      final record = makeRecord(
        'r',
        pointId: 'p-bridge',
        referenceImagePath: 'missing/record.jpg',
      );
      expect(details.referenceImagePath(record, point), 'full/bridge.jpg');
      expect(
        const RecordDetails(
          isWeb: false,
          localFileExists: _never,
        ).referenceImagePath(record, point),
        isNull,
      );
    });

    test('web accepts desktop asset paths', () {
      const details = RecordDetails(localFileExists: _never, isWeb: true);
      final record = makeRecord(
        'r',
        pointId: 'p-bridge',
        referenceImagePath: 'assets/references/a.jpg',
      );
      expect(
        details.referenceImagePath(record, null),
        'assets/references/a.jpg',
      );
    });

    test('url: record url, then point remote url', () {
      const details = RecordDetails(localFileExists: _never, isWeb: false);
      final withUrl = makeRecord(
        'r',
        pointId: 'p-bridge',
        referenceImageUrl: 'https://example.com/r.jpg',
      );
      expect(
        details.referenceImageUrl(withUrl, pointBridge),
        'https://example.com/r.jpg',
      );
      final bare = makeRecord('r', pointId: 'p-bridge');
      expect(
        details.referenceImageUrl(bare, pointBridge),
        pointBridge.referenceImageUrl,
      );
      expect(details.referenceImageUrl(bare, pointPeak), isNull);
      expect(details.referenceImageUrl(bare, null), isNull);
    });
  });

  test('titles fall back to the record snapshot', () {
    final orphan = testRecords.last;
    expect(RecordDetails.title(orphan, null), '消えた場所');
    expect(RecordDetails.subtitle(orphan, null), '旧作品 / 旧副标题');
    expect(
      RecordDetails.subtitle(makeRecord('x', pointId: 'x'), null),
      'work-a',
    );
    expect(
      RecordDetails.subtitle(testRecords.first, pointBridge),
      '吹响吧！上低音号 / 京阪宇治駅前',
    );
    expect(RecordDetails.groupName(testPlan, pointBridge), '宇治站附近');
    expect(RecordDetails.groupName(testPlan, pointLoose), '未分组');
    expect(
      RecordDetails.groupName(
        testPlan,
        pointLoose.copyWith(groupId: 'g-deleted'),
      ),
      '未知片区',
    );
    expect(
      RecordDetails.formatDateTime(DateTime(2026, 6, 1, 9, 5)),
      '2026-06-01 09:05',
    );
  });

  test('comparison metadata uses point values or the snapshot', () {
    final meta = RecordDetails.comparisonMetadata(
      testRecords.first,
      pointBridge,
    );
    expect(meta[ComparisonMetadataField.pointName], '宇治橋');
    expect(meta[ComparisonMetadataField.coordinates], '34.88941, 135.80775');
    expect(meta[ComparisonMetadataField.anitabiId], 'anitabi-001');
    expect(meta[ComparisonMetadataField.capturedAt], '2026-06-01 09:12');

    final loose = RecordDetails.comparisonMetadata(testRecords[3], pointLoose);
    expect(loose.containsKey(ComparisonMetadataField.coordinates), isFalse);

    final orphan = RecordDetails.comparisonMetadata(testRecords.last, null);
    expect(orphan[ComparisonMetadataField.pointName], '消えた場所');
    expect(orphan[ComparisonMetadataField.workTitle], '旧作品');
    expect(orphan.containsKey(ComparisonMetadataField.episodeLabel), isFalse);
  });

  test('colour grading summary applies intensity and skips defaults', () {
    expect(
      RecordDetails.colorGradingSummary(makeRecord('x', pointId: 'x')),
      isNull,
    );
    final record = makeRecord(
      'x',
      pointId: 'x',
      colorGradingParamsJson:
          '{"exposure":0.2,"contrast":1.2,"redMidCurve":-0.1,"brightness":0.001}',
      colorGradingIntensity: 0.5,
    );
    expect(
      RecordDetails.colorGradingSummary(record),
      '曝光 +0.10  对比 1.10  R中 -0.05',
    );
    expect(
      RecordDetails.colorGradingSummary(
        makeRecord('x', pointId: 'x', colorGradingParamsJson: 'not json'),
      ),
      isNull,
    );
  });

  group('delete', () {
    final repository = SamplePilgrimageRepository(visitRecords: []);

    test('failed metadata deletion never removes photos', () async {
      var photoCalls = 0;
      final outcome = await deleteVisitRecordWithPhotos(
        record: testRecords.first,
        deleteRecord: () async => throw StateError('disk full'),
        repository: repository,
        deleteFiles: true,
        deletePhotos: ({required record, required repository}) async =>
            photoCalls++,
      );
      expect(outcome, RecordDeleteOutcome.failed);
      expect(photoCalls, 0);
    });

    test('photos only when asked; leftovers are reported', () async {
      var photoCalls = 0;
      Future<void> photos({required record, required repository}) async =>
          photoCalls++;
      expect(
        await deleteVisitRecordWithPhotos(
          record: testRecords.first,
          deleteRecord: () async {},
          repository: repository,
          deleteFiles: false,
          deletePhotos: photos,
        ),
        RecordDeleteOutcome.deleted,
      );
      expect(photoCalls, 0);
      expect(
        await deleteVisitRecordWithPhotos(
          record: testRecords.first,
          deleteRecord: () async {},
          repository: repository,
          deleteFiles: true,
          deletePhotos: photos,
        ),
        RecordDeleteOutcome.deleted,
      );
      expect(photoCalls, 1);
      expect(
        await deleteVisitRecordWithPhotos(
          record: testRecords.first,
          deleteRecord: () async {},
          repository: repository,
          deleteFiles: true,
          deletePhotos: ({required record, required repository}) async =>
              throw StateError('locked'),
        ),
        RecordDeleteOutcome.deletedWithLeftovers,
      );
    });
  });
}

bool _never(String path) => false;
