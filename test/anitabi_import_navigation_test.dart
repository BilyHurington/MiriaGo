import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';
import 'package:miriago/data/anitabi_client.dart';
import 'package:miriago/data/pilgrimage_repository.dart';
import 'package:miriago/data/reference_image_cache_io.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/anitabi_map_import_screen.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/widgets/app_back_button.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _Client extends AnitabiClient {
  _Client({this.withImage = false});
  final bool withImage;
  AnitabiPoint get point => AnitabiPoint(
    bangumiId: 12345,
    id: 'first',
    name: 'Import point',
    subtitle: 'Place',
    position: const LatLng(35, 135),
    episodeLabel: 'EP 1',
    referenceImageUrl: withImage
        ? 'https://image.anitabi.cn/points/lifecycle.jpg'
        : null,
    origin: 'Anitabi',
    originUrl: 'https://anitabi.cn/',
  );
  @override
  Future<AnitabiBangumiLite> fetchBangumiLite(int bangumiId) async =>
      AnitabiBangumiLite(
        bangumiId: bangumiId,
        title: 'Work',
        subtitle: 'Work',
        city: 'City',
        center: const LatLng(35, 135),
        zoom: 14,
        pointsLength: 1,
      );
  @override
  Future<List<AnitabiPoint>> fetchPoints(
    int bangumiId, {
    AnitabiBangumiLite? lite,
  }) async => [point];
}

class _Repository extends SamplePilgrimageRepository {
  _Repository({this.fail = false, this.delayCache = false}) : super(plans: []);
  final bool fail;
  final bool delayCache;
  final importGate = Completer<void>();
  final cacheGate = Completer<void>();
  bool importing = false;
  bool updatingCache = false;

  @override
  Future<PilgrimagePlan> addPointToPlan({
    required String planId,
    required PilgrimagePoint point,
  }) async {
    importing = true;
    await importGate.future;
    if (fail) throw StateError('injected import failure');
    return super.addPointToPlan(planId: planId, point: point);
  }

  @override
  Future<PilgrimagePlan> updatePointImageCaches({
    required String planId,
    required Map<String, PointImageCacheUpdate> updatesByPointId,
  }) async {
    updatingCache = true;
    if (delayCache) await cacheGate.future;
    return super.updatePointImageCaches(
      planId: planId,
      updatesByPointId: updatesByPointId,
    );
  }
}

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GlobalKey<NavigatorState> navigator;
  bool? returned;

  bool canPop(WidgetTester tester) => tester
      .widget<PopScope>(find.byWidgetPredicate((widget) => widget is PopScope))
      .canPop;

  Future<void> open(
    WidgetTester tester,
    _Repository repository, {
    _Client? client,
    bool startImport = true,
  }) async {
    final plan = await repository.createPlan(name: 'Plan', area: 'City');
    returned = null;
    navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Open'),
              onPressed: () async {
                returned = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => AnitabiMapImportScreen(
                      plan: plan,
                      repository: repository,
                      initialBangumiId: 12345,
                      initialSettings: const AppSettings(),
                      anitabiClient: client ?? _Client(),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(canPop(tester), isTrue);
    if (!startImport) return;
    await tester.tap(find.text('加入计划'));
    await tester.pump();
    expect(repository.importing, isTrue);
    expect(canPop(tester), isFalse);
  }

  for (final fail in [false, true]) {
    testWidgets(
      'import blocks system and toolbar back; idle toolbar returns ${!fail}',
      (tester) async {
        final repository = _Repository(fail: fail);
        await open(tester, repository);
        await navigator.currentState!.maybePop();
        tester
            .widget<AppBackButton>(find.byType(AppBackButton).last)
            .onPressed!();
        await tester.pump();
        expect(find.byType(AnitabiMapImportScreen), findsOneWidget);
        expect(returned, isNull);
        repository.importGate.complete();
        await tester.pumpAndSettle();
        expect(canPop(tester), isTrue);
        tester
            .widget<AppBackButton>(find.byType(AppBackButton).last)
            .onPressed!();
        await tester.pumpAndSettle();
        expect(find.byType(AnitabiMapImportScreen), findsNothing);
        expect(returned, !fail);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('idle system back remains enabled without an explicit result', (
    tester,
  ) async {
    final repository = _Repository();
    await open(tester, repository, startImport: false);
    expect(canPop(tester), isTrue);
    await navigator.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(AnitabiMapImportScreen), findsNothing);
    expect(returned, isNull);
    expect(repository.importing, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'forced dispose during import completion does not update disposed UI',
    (tester) async {
      final repository = _Repository();
      await open(tester, repository);
      await tester.pumpWidget(const SizedBox());
      repository.importGate.complete();
      await tester.pumpAndSettle();
      expect((await repository.loadPlans()).single.points, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'forced dispose during thumbnail metadata write does not call setState',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync(
        'anitabi-lifecycle-',
      );
      final previousPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(directory.path);
      addTearDown(() {
        PathProviderPlatform.instance = previousPaths;
        directory.deleteSync(recursive: true);
      });
      final client = _Client(withImage: true);
      final work = PilgrimageWork(
        id: 'work',
        title: 'Work',
        subtitle: 'Work',
        city: 'City',
        source: WorkSource.manual,
      );
      await tester.runAsync(
        () => http.runWithClient(
          () async {
            final path = await cacheReferenceThumbnail(
              client.point.toPilgrimagePoint(work),
            );
            expect(path, isNotNull);
          },
          () => MockClient(
            (_) async => http.Response.bytes(
              img.encodeJpg(img.Image(width: 2, height: 2)),
              200,
            ),
          ),
        ),
      );
      final repository = _Repository(delayCache: true);
      await open(tester, repository, client: client);
      repository.importGate.complete();
      for (var i = 0; i < 100 && !repository.updatingCache; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump();
      }
      expect(repository.updatingCache, isTrue);
      await navigator.currentState!.maybePop();
      await tester.pump();
      expect(find.byType(AnitabiMapImportScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      repository.cacheGate.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
