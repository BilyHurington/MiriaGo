import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/local/app_database.dart';
import 'package:miriago/data/local/sqlite_pilgrimage_repository.dart';
import 'package:miriago/data/pilgrimage_repository.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/desktop/desktop_repository_state.dart';

void main() {
  for (final sqlite in [false, true]) {
    test(
      'conditional thumbnail cache preserves newer image and metadata sqlite=$sqlite',
      () async {
        final database = sqlite ? AppDatabase(NativeDatabase.memory()) : null;
        if (database != null) addTearDown(database.close);
        final PilgrimageRepository repository = database == null
            ? SamplePilgrimageRepository()
            : SqlitePilgrimageRepository(database: database);
        final plan = await repository.createPlan(
          name: 'Cache test',
          area: 'Tokyo',
        );
        final sample =
            (await SamplePilgrimageRepository().loadActivePlan()).points.first;
        final point = sample.copyWith(
          groupId: null,
          referenceImageUrl: 'https://image.anitabi.cn/points/original.jpg',
          referenceThumbnailPath: null,
          referenceFullImagePath: '/cache/new-full.jpg',
          note: 'Keep this note',
        );
        await repository.addPointToPlan(planId: plan.id, point: point);
        final updated = await repository.updatePointImageCaches(
          planId: plan.id,
          updatesByPointId: {
            point.id: PointImageCacheUpdate(
              referenceThumbnailPath: '/cache/thumbnail.jpg',
              expectedReferenceImageUrl: point.referenceImageUrl,
              preserveFullImagePath: true,
            ),
          },
        );
        expect(
          updated.points.single.referenceThumbnailPath,
          '/cache/thumbnail.jpg',
        );
        expect(
          updated.points.single.referenceFullImagePath,
          '/cache/new-full.jpg',
        );
        expect(updated.points.single.note, 'Keep this note');
        await repository.updatePointInPlan(
          planId: plan.id,
          point: updated.points.single.copyWith(
            referenceImageUrl: null,
            referenceThumbnailPath: '/user_reference_images/upload-thumb.jpg',
            referenceFullImagePath: '/user_reference_images/upload-full.jpg',
          ),
        );
        final rejected = await repository.updatePointImageCaches(
          planId: plan.id,
          updatesByPointId: {
            point.id: PointImageCacheUpdate(
              referenceThumbnailPath: '/cache/late.jpg',
              expectedReferenceImageUrl: point.referenceImageUrl,
              preserveFullImagePath: true,
            ),
          },
        );
        expect(rejected.points.single.referenceImageUrl, isNull);
        expect(
          rejected.points.single.referenceThumbnailPath,
          '/user_reference_images/upload-thumb.jpg',
        );
        expect(
          rejected.points.single.referenceFullImagePath,
          '/user_reference_images/upload-full.jpg',
        );
        if (repository is SamplePilgrimageRepository) {
          final restored = decodeDesktopRepositoryState(
            encodeDesktopRepositoryState(repository.snapshot()),
          )!;
          final saved = restored.plans
              .firstWhere((p) => p.id == plan.id)
              .points
              .single;
          expect(
            saved.referenceThumbnailPath,
            rejected.points.single.referenceThumbnailPath,
          );
          expect(
            saved.referenceFullImagePath,
            rejected.points.single.referenceFullImagePath,
          );
        }
      },
    );
  }
}
