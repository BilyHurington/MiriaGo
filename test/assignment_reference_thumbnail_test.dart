import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/data/anitabi_image_source_scope.dart';
import 'package:miriago/data/reference_image_cache_io.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/nearest_group_assign_screen.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/widgets/auto_caching_reference_thumbnail.dart';
import 'package:miriago/widgets/reference_thumbnail_io.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getApplicationCachePath() async => path;
}

void main() {
  late Directory directory;
  late PathProviderPlatform previousPaths;
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jS1sAAAAASUVORK5CYII=',
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'miriago-assign-thumbnail-',
    );
    previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(directory.path);
  });
  tearDown(() async {
    PathProviderPlatform.instance = previousPaths;
    await directory.delete(recursive: true);
  });

  Future<SamplePilgrimageRepository> openCard(
    WidgetTester tester, {
    required bool box,
    AnitabiImageSource source = AnitabiImageSource.mirror,
    String? localPath,
    bool upload = false,
  }) async {
    final initial = await SamplePilgrimageRepository().loadActivePlan();
    final point = initial.points.first.copyWith(
      groupId: null,
      source: upload ? PointSource.manual : PointSource.anitabi,
      referenceImageUrl: upload
          ? null
          : 'https://image.anitabi.cn/points/assign.jpg',
      referenceThumbnailPath: localPath,
      referenceFullImagePath: null,
    );
    final plan = initial.copyWith(id: directory.path, points: [point]);
    final repository = SamplePilgrimageRepository(plans: [plan]);
    final settings = AppSettings(anitabiImageSource: source);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: box
            ? BoxGroupAssignScreen(
                plan: plan,
                settings: settings,
                repository: repository,
              )
            : NearestGroupAssignScreen(
                plan: plan,
                settings: settings,
                repository: repository,
              ),
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<IconButton>(find.widgetWithIcon(IconButton, LucideIcons.mapPin))
        .onPressed!();
    await tester.pumpAndSettle();
    return repository;
  }

  for (final box in [false, true]) {
    for (final source in [
      AnitabiImageSource.official,
      AnitabiImageSource.mirror,
    ]) {
      testWidgets(
        'assign box=$box honors ${source.name} and uses on-demand caching',
        (tester) async {
          await openCard(tester, box: box, source: source);
          expect(find.byType(AutoCachingReferenceThumbnail), findsOneWidget);
          expect(
            tester
                .widget<ReferenceThumbnail>(find.byType(ReferenceThumbnail))
                .imageSource,
            source,
          );
          await tester.runAsync(
            () async => Future<void>.delayed(const Duration(milliseconds: 40)),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }

    testWidgets('assign box=$box displays uploaded local thumbnail offline', (
      tester,
    ) async {
      final file = File('${directory.path}/uploaded.png');
      await tester.runAsync(() => file.writeAsBytes(png));
      await openCard(tester, box: box, localPath: file.path, upload: true);
      final thumbnail = tester.widget<ReferenceThumbnail>(
        find.byType(ReferenceThumbnail),
      );
      expect(thumbnail.localPath, file.path);
      expect(thumbnail.imageUrl, isNull);
      expect(
        find.byWidgetPredicate((w) => w is Image && w.image is FileImage),
        findsOneWidget,
      );
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      'assign box=$box restores cached thumbnail path into repository',
      (tester) async {
        final initial = await SamplePilgrimageRepository().loadActivePlan();
        String? cachedPath;
        await tester.runAsync(() async {
          cachedPath = await http.runWithClient(
            () => cacheReferenceThumbnail(
              initial.points.first.copyWith(
                source: PointSource.anitabi,
                referenceImageUrl: 'https://image.anitabi.cn/points/assign.jpg',
              ),
            ),
            () => MockClient((_) async => http.Response.bytes(png, 200)),
          );
        });
        expect(cachedPath, isNotNull);
        final repository = await openCard(tester, box: box);
        for (var i = 0; i < 30; i++) {
          await tester.runAsync(
            () async => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
          if ((await repository.loadActivePlan())
                  .points
                  .first
                  .referenceThumbnailPath !=
              null) {
            break;
          }
        }
        await tester.pumpAndSettle();
        final updated = (await repository.loadActivePlan()).points.first;
        expect(updated.referenceThumbnailPath, cachedPath);
        expect(updated.referenceFullImagePath, isNull);
        expect(updated.groupId, isNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'same point switches from remote to uploaded thumbnail without blanking',
    (tester) async {
      final plan = await SamplePilgrimageRepository().loadActivePlan();
      final repository = SamplePilgrimageRepository();
      final remote = plan.points.first.copyWith(
        source: PointSource.anitabi,
        referenceImageUrl: 'https://image.anitabi.cn/points/changing.jpg',
        referenceThumbnailPath: null,
      );
      final file = File('${directory.path}/upload.png');
      await tester.runAsync(() => file.writeAsBytes(png));
      Widget thumbnail(PilgrimagePoint point) => MaterialApp(
        home: AnitabiImageSourceScope(
          source: AnitabiImageSource.mirror,
          child: AutoCachingReferenceThumbnail(
            planId: directory.path,
            point: point,
            repository: repository,
            placeholder: const Icon(LucideIcons.image),
          ),
        ),
      );
      await tester.pumpWidget(thumbnail(remote));
      await tester.pumpWidget(
        thumbnail(
          remote.copyWith(
            referenceImageUrl: null,
            referenceThumbnailPath: file.path,
          ),
        ),
      );
      expect(
        tester
            .widget<ReferenceThumbnail>(find.byType(ReferenceThumbnail))
            .localPath,
        file.path,
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('returning to a point joins its pending thumbnail cache', (
    tester,
  ) async {
    final initial = await SamplePilgrimageRepository().loadActivePlan();
    final a = initial.points.first.copyWith(
      id: 'a',
      source: PointSource.anitabi,
      referenceImageUrl: 'https://image.anitabi.cn/points/returning.jpg',
      referenceThumbnailPath: null,
      referenceFullImagePath: null,
    );
    final b = a.copyWith(id: 'b', referenceImageUrl: null);
    final plan = initial.copyWith(id: directory.path, points: [a, b]);
    final repository = SamplePilgrimageRepository(plans: [plan]);
    String? path;
    await tester.runAsync(() async {
      path = await http.runWithClient(
        () => cacheReferenceThumbnail(a),
        () => MockClient((_) async => http.Response.bytes(png, 200)),
      );
    });
    Widget thumbnail(PilgrimagePoint point) => MaterialApp(
      home: AutoCachingReferenceThumbnail(
        key: ValueKey(point.id),
        planId: plan.id,
        point: point,
        repository: repository,
        placeholder: const Icon(LucideIcons.image),
      ),
    );
    await tester.pumpWidget(thumbnail(a));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpWidget(thumbnail(b));
    await tester.pumpWidget(thumbnail(a));
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 1));
      if ((await repository.loadActivePlan())
              .points
              .first
              .referenceThumbnailPath !=
          null) {
        break;
      }
    }
    expect(
      (await repository.loadActivePlan()).points.first.referenceThumbnailPath,
      path,
    );
    expect(
      tester
          .widget<ReferenceThumbnail>(find.byType(ReferenceThumbnail))
          .localPath,
      path,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
