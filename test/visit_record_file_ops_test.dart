import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/app_managed_file_paths_io.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/pilgrimage_plan_controller.dart';
import 'package:miriago/records/visit_record_detail_screen.dart';
import 'package:miriago/records/visit_record_file_ops_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late Directory documents;
  late PathProviderPlatform originalProvider;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp(
      'miriago_record_cleanup_',
    );
    documents = await Directory(p.join(temporary.path, 'Documents')).create();
    originalProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(documents.path);
    setAppManagedFileBaseDirectoriesForTesting([documents.path]);
  });
  tearDown(() async {
    PathProviderPlatform.instance = originalProvider;
    setAppManagedFileBaseDirectoriesForTesting(null);
    await temporary.delete(recursive: true);
  });

  Future<File> file(String relative) async {
    final result = File(p.join(documents.path, relative));
    await result.parent.create(recursive: true);
    await result.writeAsBytes([1, 2, 3]);
    return result;
  }

  PilgrimageVisitRecord record(String photo, {String? reference}) =>
      PilgrimageVisitRecord(
        id: 'deleted',
        planId: samplePilgrimagePlan.id,
        pointId: samplePilgrimagePlan.points.first.id,
        workId: samplePilgrimagePlan.works.first.id,
        photoPath: photo,
        referenceImagePath: reference,
        referenceMode: 'overlay',
        capturedAt: DateTime(2026),
      );

  test(
    'deletes an owned visit photo but always preserves the reference',
    () async {
      final photo = await file('visit_record_images/photo.jpg');
      final reference = await file(
        'imported_plan_assets/package/assets/full_references/ref.jpg',
      );
      await deleteUnreferencedVisitRecordPhotos(
        record: record(photo.path, reference: reference.path),
        repository: SamplePilgrimageRepository(visitRecords: []),
      );
      expect(photo.existsSync(), isFalse);
      expect(reference.existsSync(), isTrue);
    },
  );

  test('a photo still referenced by any plan point is preserved', () async {
    final photo = await file(
      'imported_plan_assets/shared/assets/visit_photos/photo.jpg',
    );
    final otherPlan = samplePilgrimagePlan.copyWith(
      id: 'other',
      points: [
        samplePilgrimagePlan.points.first.copyWith(
          referenceFullImagePath: photo.path,
        ),
      ],
    );
    await deleteUnreferencedVisitRecordPhotos(
      record: record(photo.path),
      repository: SamplePilgrimageRepository(
        plans: [samplePilgrimagePlan, otherPlan],
        visitRecords: [],
      ),
    );
    expect(photo.existsSync(), isTrue);
  });

  test('photo shared by a remaining record is preserved', () async {
    final photo = await file('visit_record_images/shared.jpg');
    await deleteUnreferencedVisitRecordPhotos(
      record: record(photo.path),
      repository: SamplePilgrimageRepository(
        visitRecords: [record(photo.path)],
      ),
    );
    expect(photo.existsSync(), isTrue);
  });

  test('reference reused as photo is never deleted', () async {
    final photo = await file('visit_record_images/reference.jpg');
    await deleteUnreferencedVisitRecordPhotos(
      record: record(photo.path, reference: photo.path),
      repository: SamplePilgrimageRepository(visitRecords: []),
    );
    expect(photo.existsSync(), isTrue);
  });

  test(
    'external originals and reference cache are never owned visit photos',
    () async {
      final external = File(p.join(temporary.path, 'original.jpg'));
      await external.writeAsBytes([1]);
      final cache = await file('reference_full/reference.jpg');
      final repository = SamplePilgrimageRepository(visitRecords: []);
      await deleteUnreferencedVisitRecordPhotos(
        record: record(external.path),
        repository: repository,
      );
      await deleteUnreferencedVisitRecordPhotos(
        record: record(cache.path),
        repository: repository,
      );
      expect(external.existsSync(), isTrue);
      expect(cache.existsSync(), isTrue);
    },
  );

  test(
    'rebased iOS paths compare against current-container references',
    () async {
      final photo = await file('visit_record_images/shared.jpg');
      final oldPath = '/old/container/Documents/visit_record_images/shared.jpg';
      await deleteUnreferencedVisitRecordPhotos(
        record: record(oldPath),
        repository: SamplePilgrimageRepository(
          visitRecords: [record(photo.path)],
        ),
      );
      expect(photo.existsSync(), isTrue);
    },
  );

  test(
    'symlink to an external photo does not grant ownership',
    () async {
      final external = File(p.join(temporary.path, 'outside.jpg'));
      await external.writeAsBytes([1]);
      await Directory(p.join(documents.path, 'visit_record_images')).create();
      final link = Link(
        p.join(documents.path, 'visit_record_images', 'linked.jpg'),
      );
      await link.create(external.path);
      await deleteUnreferencedVisitRecordPhotos(
        record: record(link.path),
        repository: SamplePilgrimageRepository(visitRecords: []),
      );
      expect(external.existsSync(), isTrue);
    },
    skip: Platform.isWindows,
  );

  test('reference scan failure prevents any photo deletion', () async {
    final photo = await file('visit_record_images/photo.jpg');
    await expectLater(
      deleteUnreferencedVisitRecordPhotos(
        record: record(photo.path),
        repository: _FailedReadRepository(),
      ),
      throwsStateError,
    );
    expect(photo.existsSync(), isTrue);
  });

  testWidgets('pending or failed metadata deletion never removes photos', (
    tester,
  ) async {
    final photo = (await tester.runAsync(
      () => file('visit_record_images/photo.jpg'),
    ))!;
    final repository = SamplePilgrimageRepository(visitRecords: []);
    final controller = PilgrimagePlanController(
      plan: samplePilgrimagePlan,
      visitRepository: repository,
    );
    final deletion = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: VisitRecordDetailScreen(
          record: record(photo.path),
          point: null,
          controller: controller,
          settings: const AppSettings(),
          onDelete: () => deletion.future,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('删除记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(photo.existsSync(), isTrue);
    final deleteButton = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == '删除记录',
    );
    expect(tester.widget<IconButton>(deleteButton).onPressed, isNull);
    deletion.completeError(StateError('disk full'));
    await tester.pumpAndSettle();
    expect(photo.existsSync(), isTrue);
    expect(find.text('删除记录失败，照片未删除，请重试'), findsOneWidget);
    expect(tester.widget<IconButton>(deleteButton).onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

class _FailedReadRepository extends SamplePilgrimageRepository {
  @override
  Future<List<PilgrimagePlan>> loadPlans() async =>
      throw StateError('read failed');
}
