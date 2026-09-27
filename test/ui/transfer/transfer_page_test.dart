import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:miriago/application/plan_session.dart';
import 'package:miriago/application/plans_store.dart';
import 'package:miriago/application/platform_capabilities.dart';
import 'package:miriago/application/transfer/plan_transfer_service.dart';
import 'package:miriago/data/pilgrimage_repository.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan_transfer/my_maps_csv_export.dart';
import 'package:miriago/plan_transfer/plan_export_delivery_result.dart';
import 'package:miriago/plan_transfer/plan_export_size_estimator.dart';
import 'package:miriago/plan_transfer/plan_export_v2.dart';
import 'package:miriago/plan_transfer/plan_import_package.dart';
import 'package:miriago/plan_transfer/plan_package.dart';
import 'package:miriago/ui/app/toast.dart';
import 'package:miriago/ui/components/components.dart';
import 'package:miriago/ui/features/plans/plan_actions.dart';
import 'package:miriago/ui/features/plans/plans_page.dart';
import 'package:miriago/ui/features/transfer/import_preview_page.dart';
import 'package:miriago/ui/features/transfer/transfer_page.dart';
import 'package:provider/provider.dart';

import '../../helpers/pump_app.dart';

/// Sample data whose active plan can fail to load.
class _FlakyRepository extends SamplePilgrimageRepository {
  bool failActivePlan = false;

  @override
  Future<PilgrimagePlan> loadActivePlan() {
    if (failActivePlan) throw StateError('disk unavailable');
    return super.loadActivePlan();
  }
}

/// Sample data whose import can be held open.
class _SlowImportRepository extends SamplePilgrimageRepository {
  final gate = Completer<void>();

  @override
  Future<PilgrimagePlan> importPlanPackage({
    required PilgrimagePlan plan,
    required List<PilgrimageVisitRecord> visitRecords,
  }) async {
    await gate.future;
    return super.importPlanPackage(plan: plan, visitRecords: visitRecords);
  }
}

/// Export backend whose build and delivery can be held open.
class _GatedBackend {
  Completer<void>? buildGate;
  Completer<void>? deliverGate;
  int deliveries = 0;

  PlanTransferBackend get backend => PlanTransferBackend(
    estimate:
        ({required plan, required visitRecords, required options}) async =>
            const PlanExportSizeEstimate(
              knownBytes: 2048,
              missingFullReferenceCount: 0,
              missingThumbnailCount: 0,
              missingUserReferenceCount: 0,
              missingVisitPhotoCount: 0,
              missingGradedPhotoCount: 0,
              hasUnknownLocalAssets: false,
            ),
    buildPackage:
        ({
          required plan,
          required visitRecords,
          required options,
          required exportedAt,
          required cancellation,
        }) async {
          final gate = buildGate;
          if (gate != null) {
            await Future.any([gate.future, cancellation.whenCancelled]);
            cancellation.throwIfCancelled();
          }
          return const PlanExportV2Result(
            bytes: [1, 2, 3],
            fileName: 'plan.sjhplan',
            warnings: [],
            warningCounts: {},
          );
        },
    prepareDestination:
        ({required fileName, required mimeType, required extension}) async =>
            null,
    deliver:
        ({
          required bytes,
          required fileName,
          required mimeType,
          required shareSubject,
          required shareText,
          required extension,
          destination,
        }) async {
          deliveries++;
          await deliverGate?.future;
          return const PlanExportDeliveryResult(PlanExportDeliveryAction.saved);
        },
    buildCsv: (plan) => const MyMapsCsvExportResult(
      bytes: [0x41],
      fileName: 'plan.csv',
      mimeType: myMapsCsvMimeType,
      skippedPointCount: 0,
    ),
  );
}

/// Pumps a [TransferPage] with an injected [backend] on top of a home page.
Future<ToastController> _pumpWithBackend(
  WidgetTester tester,
  PlanTransferBackend backend,
) async {
  final repository = SamplePilgrimageRepository();
  final session = PlanSession(repository: repository);
  await session.load();
  final plans = PlansStore(repository: repository, session: session);
  final toasts = ToastController();
  addTearDown(() {
    plans.dispose();
    session.dispose();
    toasts.dispose();
  });
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/transfer',
        builder: (_, _) => TransferPage(backend: backend),
      ),
    ],
  );
  addTearDown(router.dispose);
  tester.view.physicalSize = TestSizes.phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<PilgrimageRepository>.value(value: repository),
        Provider<PlatformCapabilities>.value(
          value: const PlatformCapabilities(
            isWeb: false,
            isTauri: false,
            isAndroid: true,
            isIOS: false,
            isDesktopNative: false,
          ),
        ),
        ChangeNotifierProvider<PlanSession>.value(value: session),
        ChangeNotifierProvider<PlansStore>.value(value: plans),
        ChangeNotifierProvider<ToastController>.value(value: toasts),
      ],
      child: MaterialApp.router(
        theme: buildMiriaTheme(MiriaColors.light),
        routerConfig: router,
      ),
    ),
  );
  unawaited(router.push('/transfer'));
  await _settle(tester);
  expect(find.byType(TransferPage), findsOneWidget);
  return toasts;
}

Future<void> _tapExport(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('export-package-button'));
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await _settle(tester);
}

MiriaButton _cancelButton(WidgetTester tester) => tester.widget<MiriaButton>(
  find.byKey(const ValueKey('export-cancel-button')),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _settleAsync(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await _settle(tester);
}

void main() {
  testWidgets('transfer page shows import, package options and estimate', (
    tester,
  ) async {
    await pumpMiriaApp(tester, location: '/plan/transfer');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await _settle(tester);
    expect(find.byType(TransferPage), findsOneWidget);
    expect(find.text('导入 MiriaGo 文件'), findsOneWidget);
    expect(find.text('支持 v2 数据包和旧版 v1 JSON 计划包。'), findsOneWidget);
    expect(find.text('纯计划'), findsOneWidget);
    expect(find.text('计划+记录'), findsOneWidget);
    expect(find.text('包含完整参考图缓存'), findsOneWidget);
    expect(find.text('导出 MiriaGo 数据包'), findsOneWidget);
    expect(find.text('导出 My Maps CSV'), findsOneWidget);
    expect(find.textContaining(' 个片区 / '), findsOneWidget);
    final estimate = tester.widget<Text>(
      find.byKey(const ValueKey('export-size-estimate')),
    );
    expect(estimate.data, startsWith('预计数据包大小'));

    await tester.tap(find.text('计划+记录'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  for (final size in [TestSizes.phoneSmall, TestSizes.desktop]) {
    testWidgets('transfer page has no overflow at $size, text scale 2', (
      tester,
    ) async {
      await pumpMiriaApp(
        tester,
        location: '/plan/transfer',
        size: size,
        textScale: 2,
      );
      await _settle(tester);
      expect(find.byType(TransferPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('import preview imports a v1 package and pops true', (
    tester,
  ) async {
    final repository = await pumpMiriaApp(tester, location: '/plan/transfer');
    final plan = await repository.loadActivePlan();
    final before = (await repository.loadPlans()).length;
    final package = readPlanImportPackageFromBytes(
      utf8.encode(
        PlanPackage(plan: plan, visitRecords: const []).toJsonString(),
      ),
      sourceName: 'shared.sjhplan',
    );
    bool? result;
    final context = tester.element(find.byType(TransferPage));
    openImportPreview(context, package).then((value) => result = value);
    await _settle(tester);

    expect(find.byType(ImportPreviewPage), findsOneWidget);
    expect(find.textContaining('shared.sjhplan'), findsOneWidget);
    expect(find.text('计划结构'), findsOneWidget);
    expect(find.text('v1 文件不包含照片资源，仅导入计划结构。'), findsOneWidget);
    expect(find.text('这个包里没有可恢复的资源文件。'), findsOneWidget);
    expect(find.text('点位 ${plan.points.length}'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('import-selected-button')));
    await _settle(tester);
    expect(result, isTrue);
    expect((await repository.loadPlans()).length, before + 1);
    expect(find.textContaining('已导入计划「'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('import preview has no overflow on a small phone', (
    tester,
  ) async {
    final repository = await pumpMiriaApp(
      tester,
      location: '/plan/transfer',
      size: TestSizes.phoneSmall,
      textScale: 2,
    );
    final plan = await repository.loadActivePlan();
    final package = readPlanImportPackageFromBytes(
      utf8.encode(
        PlanPackage(plan: plan, visitRecords: const []).toJsonString(),
      ),
      sourceName: 'a-very-long-package-file-name-from-chat.sjhplan',
    );
    openImportPreview(tester.element(find.byType(TransferPage)), package);
    await _settle(tester);
    expect(find.byType(ImportPreviewPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('?plan= exports that plan without switching the active one', (
    tester,
  ) async {
    final repository = SamplePilgrimageRepository();
    final active = await repository.loadActivePlan();
    final other = await repository.createPlan(name: '京都备用计划', area: '京都');
    await repository.setActivePlan(active.id);
    await pumpMiriaApp(
      tester,
      location: TransferPage.locationFor(other.id),
      repository: repository,
    );
    await _settleAsync(tester);
    expect(find.byType(TransferPage), findsOneWidget);
    expect(find.text('京都备用计划'), findsOneWidget);
    expect(find.text(active.name), findsNothing);
    expect(find.text('0 个片区 / 0 个点位'), findsOneWidget);
    expect((await repository.loadActivePlan()).id, active.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plan menu 导入导出 on another plan keeps the active plan', (
    tester,
  ) async {
    final repository = SamplePilgrimageRepository();
    final active = await repository.loadActivePlan();
    final other = await repository.createPlan(name: '京都备用计划', area: '京都');
    await repository.setActivePlan(active.id);
    await pumpMiriaApp(tester, location: '/plans', repository: repository);
    await _settleAsync(tester);
    final context = tester.element(find.byType(PlansPage));
    unawaited(openPlanTransfer(context, other));
    await _settleAsync(tester);
    expect(find.byType(TransferPage), findsOneWidget);
    expect(find.text('京都备用计划'), findsWidgets);
    expect((await repository.loadActivePlan()).id, active.id);

    // Back returns to the plan library.
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.byType(TransferPage), findsNothing);
    expect(find.byType(PlansPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed plan load shows an error with retry', (tester) async {
    final repository = _FlakyRepository()..failActivePlan = true;
    await pumpMiriaApp(
      tester,
      location: '/plan/transfer',
      repository: repository,
    );
    await _settle(tester);
    expect(find.byKey(const ValueKey('transfer-load-error')), findsOneWidget);
    expect(find.text('计划加载失败'), findsOneWidget);
    expect(find.textContaining('请稍后重试。'), findsOneWidget);
    expect(find.byType(ProgressRing), findsNothing);

    repository.failActivePlan = false;
    await tester.tap(find.text('重试'));
    await _settleAsync(tester);
    expect(find.byKey(const ValueKey('transfer-load-error')), findsNothing);
    expect(find.text('导出 MiriaGo 数据包'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling before delivery shows a warning toast', (
    tester,
  ) async {
    final fake = _GatedBackend()..buildGate = Completer<void>();
    final toasts = await _pumpWithBackend(tester, fake.backend);
    await _tapExport(tester);
    expect(_cancelButton(tester).onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('export-cancel-button')));
    await _settle(tester);
    final toast = toasts.toasts.single;
    expect(toast.title, '已取消导出');
    expect(toast.kind, ToastKind.warning);
    expect(fake.deliveries, 0);
    await tester.pump(const Duration(seconds: 4));
    expect(toasts.toasts, isEmpty);
  });

  testWidgets('once delivery started, cancel and back are ignored', (
    tester,
  ) async {
    final fake = _GatedBackend()..deliverGate = Completer<void>();
    final toasts = await _pumpWithBackend(tester, fake.backend);
    await _tapExport(tester);
    expect(fake.deliveries, 1);
    expect(find.byKey(const ValueKey('export-cancel-button')), findsOneWidget);
    expect(_cancelButton(tester).onPressed, isNull);

    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.byType(TransferPage), findsOneWidget);
    expect(toasts.toasts.map((t) => t.title), isNot(contains('已取消导出')));

    fake.deliverGate!.complete();
    await _settle(tester);
    expect(toasts.toasts.last.title, '数据包已导出');
    expect(toasts.toasts.last.kind, ToastKind.success);
    expect(find.byKey(const ValueKey('export-cancel-button')), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('back while importing shows an info toast, not a spinner', (
    tester,
  ) async {
    final repository = _SlowImportRepository();
    await pumpMiriaApp(
      tester,
      location: '/plan/transfer',
      repository: repository,
    );
    final plan = await repository.loadActivePlan();
    final package = readPlanImportPackageFromBytes(
      utf8.encode(
        PlanPackage(plan: plan, visitRecords: const []).toJsonString(),
      ),
      sourceName: 'shared.sjhplan',
    );
    unawaited(
      openImportPreview(tester.element(find.byType(TransferPage)), package),
    );
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('import-selected-button')));
    await _settle(tester);
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.byType(ImportPreviewPage), findsOneWidget);
    final toasts = tester
        .element(find.byType(ImportPreviewPage))
        .read<ToastController>();
    final busy = toasts.toasts.last;
    expect(busy.title, '正在导入，请稍候。');
    expect(busy.kind, ToastKind.info);
    repository.gate.complete();
    await _settle(tester);
  });
}
