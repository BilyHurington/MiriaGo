import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:miriago/camera_reference/photo_location.dart';
import 'package:miriago/camera_reference/photo_location_save_stub.dart'
    if (dart.library.io) 'package:miriago/camera_reference/photo_location_save_io.dart';
import 'package:miriago/camera_reference/photo_location_status_panel.dart';
import 'package:miriago/camera_reference/auto_comparison_gallery_backup.dart';
import 'package:miriago/camera_reference/visit_record_confirmation_screen.dart';
import 'package:miriago/camera_reference/visit_record_save_assets.dart';
import 'package:miriago/data/pilgrimage_repository.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/pilgrimage_plan_controller.dart';

final _location = PhotoLocationData(
  latitude: 35,
  longitude: 139,
  accuracy: 20,
  timestamp: DateTime.utc(2026, 9, 22),
);
final _referenceBytes = Uint8List.fromList(
  img.encodePng(img.Image(width: 2, height: 2)),
);

class _Repository extends SamplePilgrimageRepository {
  _Repository() : super(visitRecords: const []);
  int creates = 0;
  int completes = 0;
  String? failure;
  Completer<void>? completionGate;
  bool completionFails = false;

  @override
  Future<PilgrimageVisitRecord> createVisitRecord({
    required String planId,
    required String pointId,
    required String workId,
    String? workTitle,
    String? workSubtitle,
    String? pointName,
    String? pointSubtitle,
    required String photoPath,
    String? referenceImagePath,
    String? referenceImageUrl,
    required String referenceMode,
    DateTime? capturedAt,
  }) async {
    creates++;
    if (failure == 'rollback') {
      throw const VisitRecordNotCommittedException('injected rollback');
    }
    if (failure == 'unknown') throw StateError('transport response lost');
    final record = await super.createVisitRecord(
      planId: planId,
      pointId: pointId,
      workId: workId,
      workTitle: workTitle,
      workSubtitle: workSubtitle,
      pointName: pointName,
      pointSubtitle: pointSubtitle,
      photoPath: photoPath,
      referenceImagePath: referenceImagePath,
      referenceImageUrl: referenceImageUrl,
      referenceMode: referenceMode,
      capturedAt: capturedAt,
    );
    if (failure == 'committed') throw StateError('response lost after commit');
    return record;
  }

  @override
  Future<void> completePoint({
    required String planId,
    required String pointId,
    required String? nextCurrentPointId,
  }) async {
    completes++;
    await completionGate?.future;
    if (completionFails) throw StateError('completion failed');
    await super.completePoint(
      planId: planId,
      pointId: pointId,
      nextCurrentPointId: nextCurrentPointId,
    );
  }
}

class _Observer extends NavigatorObserver {
  late Route<dynamic> confirmation;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name == '/confirm') confirmation = route;
  }
}

class _Fixture {
  _Fixture(this.repository, this.controller, this.route);
  final _Repository repository;
  final PilgrimagePlanController controller;
  final Route<dynamic> route;
}

Future<PreparedPhotoLocation> _prepare({
  required String sourcePath,
  required PhotoLocationData location,
  required PhotoLocationWriter writer,
}) async {
  final written = await writer('/owned/working.jpg', location);
  return PreparedPhotoLocation(
    path: written ? '/owned/working.jpg' : sourcePath,
    written: written,
  );
}

Future<_Fixture> _pump(
  WidgetTester tester, {
  _Repository? repository,
  PhotoLocationStrategy strategy = PhotoLocationStrategy.disabled,
  PhotoLocationData? pending,
  Future<PhotoLocationData> Function()? resolve,
  PhotoLocationWriter? writer,
  PhotoLocationPreparer prepare = _prepare,
  Uint8List? referenceBytes,
  ReferenceImagePreparer? prepareReference,
  Future<void> Function()? discardSource,
  String photoPath = '/draft/capture.jpg',
  Future<void> Function(String, BuildContext)? retainPreview,
  bool gallery = false,
  bool comparison = false,
  Future<bool> Function(String)? gallerySaver,
  Future<AutoComparisonGalleryResult> Function(PilgrimageVisitRecord)?
  comparisonSaver,
}) async {
  tester.view.physicalSize = const Size(800, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repo = repository ?? _Repository();
  final plan = await repo.loadActivePlan();
  final controller = PilgrimagePlanController(
    plan: plan,
    visitRepository: repo,
  );
  await controller.loadVisitRecords();
  addTearDown(controller.dispose);
  final observer = _Observer();
  await tester.pumpWidget(
    MaterialApp(
      initialRoute: '/confirm',
      navigatorObservers: [observer],
      routes: {
        '/': (_) => const Scaffold(),
        '/confirm': (_) => VisitRecordConfirmationScreen(
          point: plan.points.first,
          controller: controller,
          photoPath: photoPath,
          referenceMode: 'test',
          photoLocationStrategy: strategy,
          pendingPhotoLocation: pending,
          resolvePhotoLocation: resolve,
          writePhotoLocation: writer,
          prepareLocation: prepare,
          referenceBytes: referenceBytes,
          prepareReference:
              prepareReference ??
              (_) async => const PreparedRecordImage(path: '/owned/ref.jpg'),
          discardSourcePhoto: discardSource,
          retainPhotoPreview: retainPreview ?? retainPhotoPreviewUntilRead,
          saveVisitPhotoToGallery: gallery,
          autoSaveComparisonToGallery: comparison,
          savePhotoToGallery: gallerySaver ?? (_) async => false,
          backupComparison:
              comparisonSaver ??
              (_) async => const AutoComparisonGalleryResult(
                AutoComparisonGalleryStatus.renderFailed,
              ),
        ),
      },
    ),
  );
  await tester.pump();
  return _Fixture(repo, controller, observer.confirmation);
}

VoidCallback _save(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!;

void main() {
  for (final pendingRead in [false, true]) {
    testWidgets(
      'committed GPS save keeps source readable throughout reverse animation; pending read=$pendingRead',
      (tester) async {
        final directory = Directory.systemTemp.createTempSync(
          'confirmation-exit-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final source = File('${directory.path}/capture.png')
          ..writeAsBytesSync(_referenceBytes);
        final saved = File('${directory.path}/saved.png')
          ..writeAsBytesSync(_referenceBytes);
        // Load the fixture in the real async zone, not Flutter's fake test clock.
        await tester.runAsync(() async {
          final provider = FileImage(source);
          final stream = provider.resolve(ImageConfiguration.empty);
          final loaded = Completer<void>();
          late ImageStreamListener listener;
          listener = ImageStreamListener(
            (info, _) {
              info.dispose();
              if (!loaded.isCompleted) loaded.complete();
            },
            onError: (Object error, StackTrace? stack) {
              if (!loaded.isCompleted) loaded.completeError(error, stack);
            },
          );
          stream.addListener(listener);
          try {
            await loaded.future.timeout(const Duration(seconds: 5));
          } finally {
            stream.removeListener(listener);
          }
        });
        var discarded = 0;
        final readFinished = Completer<void>();
        if (!pendingRead) readFinished.complete();
        final fixture = await _pump(
          tester,
          photoPath: source.path,
          strategy: PhotoLocationStrategy.useRecentLocation,
          pending: _location,
          writer: (_, _) async => true,
          prepare:
              ({
                required sourcePath,
                required location,
                required writer,
              }) async =>
                  PreparedPhotoLocation(path: saved.path, written: true),
          retainPreview: (_, _) => readFinished.future,
          discardSource: () async {
            discarded++;
            source.deleteSync();
          },
        );
        await tester.pumpAndSettle();
        final confirmation = tester.state(
          find.byType(VisitRecordConfirmationScreen),
        );
        _save(tester)();
        await tester.pump();
        expect(await fixture.route.popped, VisitRecordConfirmationResult.saved);
        expect(fixture.controller.visitRecords.single.photoPath, saved.path);
        expect(confirmation.mounted, isTrue);
        expect(discarded, 0);
        expect(source.readAsBytesSync(), _referenceBytes);
        await tester.pump(const Duration(milliseconds: 100));
        expect(confirmation.mounted, isTrue);
        expect(discarded, 0);
        expect(await tester.runAsync(source.readAsBytes), _referenceBytes);
        await tester.pumpAndSettle();
        expect(confirmation.mounted, isFalse);
        if (pendingRead) {
          expect(discarded, 0);
          expect(source.existsSync(), isTrue);
          readFinished.complete();
          await tester.pump();
        }
        expect(discarded, 1);
        expect(source.existsSync(), isFalse);
        expect(saved.readAsBytesSync(), _referenceBytes);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final valid in [false, true]) {
    testWidgets(
      'preview read lease finishes after owner disposal; valid=$valid',
      (tester) async {
        final directory = Directory.systemTemp.createTempSync('preview-read-');
        addTearDown(() => directory.deleteSync(recursive: true));
        final source = File('${directory.path}/capture.png')
          ..writeAsBytesSync(valid ? _referenceBytes : [1, 2, 3]);
        late BuildContext previewContext;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) {
                previewContext = context;
                return const SizedBox();
              },
            ),
          ),
        );
        await tester.runAsync(() async {
          final read = retainPhotoPreviewUntilRead(source.path, previewContext);
          await tester.pumpWidget(const SizedBox());
          await read.timeout(const Duration(seconds: 5));
          source.deleteSync();
        });
        await tester.pump();
        expect(source.existsSync(), isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final afterResolution in [false, true]) {
    testWidgets(
      'skip ${afterResolution ? 'ready' : 'pending'} location never writes',
      (tester) async {
        final resolver = Completer<PhotoLocationData>();
        var writes = 0;
        final fixture = await _pump(
          tester,
          strategy: PhotoLocationStrategy.waitOnConfirmation,
          resolve: () => resolver.future,
          writer: (_, _) async {
            writes++;
            return true;
          },
        );
        if (afterResolution) {
          resolver.complete(_location);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('跳过'));
        if (!afterResolution) resolver.complete(_location);
        await tester.pumpAndSettle();
        _save(tester)();
        await tester.pumpAndSettle();
        expect(writes, 0);
        expect(fixture.repository.creates, 1);
        expect(await fixture.route.popped, VisitRecordConfirmationResult.saved);
      },
    );
  }

  testWidgets(
    'recent fix is staged unchanged; write blocks skip/back/double save',
    (tester) async {
      final gate = Completer<bool>();
      var writes = 0;
      PhotoLocationData? writtenLocation;
      final fixture = await _pump(
        tester,
        strategy: PhotoLocationStrategy.useRecentLocation,
        pending: _location,
        resolve: () async => throw StateError('must not refresh'),
        writer: (path, location) {
          writes++;
          writtenLocation = location;
          return gate.future;
        },
      );
      await tester.pumpAndSettle();
      expect(writes, 0);
      final save = _save(tester);
      final staleSkip = tester
          .widget<PhotoLocationStatusPanel>(
            find.byType(PhotoLocationStatusPanel),
          )
          .onSkip!;
      save();
      save();
      staleSkip();
      await tester.pump();
      await tester.pump();
      expect(writes, 1);
      expect(writtenLocation, same(_location));
      expect(
        tester
            .widget<PhotoLocationStatusPanel>(
              find.byType(PhotoLocationStatusPanel),
            )
            .onSkip,
        isNull,
      );
      expect(find.text('跳过'), findsNothing);
      expect(find.text('正在写入照片定位，请稍候...'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<PopScope>(find.byWidgetPredicate((w) => w is PopScope))
            .canPop,
        isFalse,
      );
      expect(
        tester
            .widgetList<AbsorbPointer>(find.byType(AbsorbPointer))
            .any((w) => w.absorbing),
        isTrue,
      );
      await Navigator.of(
        tester.element(find.byType(VisitRecordConfirmationScreen)),
      ).maybePop();
      await tester.pump();
      expect(fixture.route.isCurrent, isTrue);
      gate.complete(true);
      await tester.pumpAndSettle();
      expect(fixture.repository.creates, 1);
      expect(
        fixture.controller.visitRecords.single.photoPath,
        '/owned/working.jpg',
      );
      expect(await fixture.route.popped, VisitRecordConfirmationResult.saved);
    },
  );

  testWidgets(
    'disabled gallery flow ignores pending location and keeps original metadata path',
    (tester) async {
      var writes = 0;
      final fixture = await _pump(
        tester,
        pending: _location,
        writer: (_, _) async {
          writes++;
          return true;
        },
      );
      _save(tester)();
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(
        fixture.controller.visitRecords.single.photoPath,
        '/draft/capture.jpg',
      );
    },
  );

  testWidgets('location resolution failure leaves save available', (
    tester,
  ) async {
    var writes = 0;
    final fixture = await _pump(
      tester,
      strategy: PhotoLocationStrategy.waitOnConfirmation,
      resolve: () async => throw StateError('permission denied'),
      writer: (_, _) async {
        writes++;
        return true;
      },
    );
    await tester.pumpAndSettle();
    _save(tester)();
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(fixture.repository.creates, 1);
  });

  testWidgets('preparation failure unlocks retry without any record', (
    tester,
  ) async {
    var attempts = 0;
    final fixture = await _pump(
      tester,
      strategy: PhotoLocationStrategy.useRecentLocation,
      pending: _location,
      writer: (_, _) async => true,
      prepare:
          ({required sourcePath, required location, required writer}) async {
            if (++attempts == 1) throw StateError('copy failed');
            return const PreparedPhotoLocation(
              path: '/owned/retry.jpg',
              written: true,
            );
          },
    );
    _save(tester)();
    await tester.pumpAndSettle();
    expect(fixture.repository.creates, 0);
    _save(tester)();
    await tester.pumpAndSettle();
    expect(fixture.repository.creates, 1);
    expect(await fixture.route.popped, VisitRecordConfirmationResult.saved);
  });

  testWidgets(
    'proven rollback cleans generated drafts and permits one successful retry',
    (tester) async {
      final repo = _Repository()..failure = 'rollback';
      var cleanPhotos = 0;
      var cleanRefs = 0;
      var cleanSources = 0;
      final fixture = await _pump(
        tester,
        repository: repo,
        strategy: PhotoLocationStrategy.useRecentLocation,
        pending: _location,
        writer: (_, _) async => true,
        referenceBytes: _referenceBytes,
        prepareReference: (_) async => PreparedRecordImage(
          path: '/owned/ref.jpg',
          discard: () async {
            cleanRefs++;
          },
        ),
        prepare:
            ({required sourcePath, required location, required writer}) async =>
                PreparedPhotoLocation(
                  path: '/owned/location.jpg',
                  written: true,
                  discard: () async {
                    cleanPhotos++;
                  },
                ),
        discardSource: () async {
          cleanSources++;
        },
      );
      _save(tester)();
      await tester.pumpAndSettle();
      expect(cleanPhotos, 1);
      expect(cleanRefs, 1);
      expect(cleanSources, 0);
      expect(fixture.controller.visitRecords, isEmpty);
      repo.failure = null;
      _save(tester)();
      await tester.pumpAndSettle();
      expect(repo.creates, 2);
      expect(fixture.controller.visitRecords, hasLength(1));
      expect(cleanPhotos, 1);
      expect(cleanRefs, 1);
      expect(cleanSources, 1);
    },
  );

  testWidgets(
    'uncertain failure locks recreation and preserves drafts even on cancel',
    (tester) async {
      var discarded = 0;
      final fixture = await _pump(
        tester,
        repository: _Repository()..failure = 'unknown',
        strategy: PhotoLocationStrategy.useRecentLocation,
        pending: _location,
        writer: (_, _) async => true,
        prepare:
            ({required sourcePath, required location, required writer}) async =>
                PreparedPhotoLocation(
                  path: '/owned/uncertain.jpg',
                  written: true,
                  discard: () async {
                    discarded++;
                  },
                ),
        referenceBytes: _referenceBytes,
        prepareReference: (_) async => PreparedRecordImage(
          path: '/owned/ref.jpg',
          discard: () async {
            discarded++;
          },
        ),
        discardSource: () async {
          discarded++;
        },
      );
      final save = _save(tester);
      save();
      await tester.pumpAndSettle();
      save();
      await tester.pumpAndSettle();
      expect(fixture.repository.creates, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.text('跳过'), findsNothing);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(discarded, 0);
    },
  );

  testWidgets(
    'reference preparation failure permits retry without duplicate records',
    (tester) async {
      var attempts = 0;
      final fixture = await _pump(
        tester,
        referenceBytes: _referenceBytes,
        prepareReference: (_) async {
          if (++attempts == 1) throw StateError('reference storage failed');
          return const PreparedRecordImage(path: '/owned/ref.jpg');
        },
      );
      _save(tester)();
      await tester.pumpAndSettle();
      expect(fixture.repository.creates, 0);
      _save(tester)();
      await tester.pumpAndSettle();
      expect(fixture.repository.creates, 1);
      expect(fixture.controller.visitRecords, hasLength(1));
    },
  );

  testWidgets(
    'rollback then skip discards GPS draft and retries from untouched source',
    (tester) async {
      final repo = _Repository()..failure = 'rollback';
      var prepares = 0;
      var discarded = 0;
      var sourceDiscarded = 0;
      final fixture = await _pump(
        tester,
        repository: repo,
        strategy: PhotoLocationStrategy.useRecentLocation,
        pending: _location,
        writer: (_, _) async => true,
        prepare:
            ({required sourcePath, required location, required writer}) async {
              prepares++;
              return PreparedPhotoLocation(
                path: '/owned/gps.jpg',
                written: true,
                discard: () async {
                  discarded++;
                },
              );
            },
        discardSource: () async {
          sourceDiscarded++;
        },
      );
      _save(tester)();
      await tester.pumpAndSettle();
      expect(discarded, 1);
      await tester.tap(find.text('跳过'));
      await tester.pumpAndSettle();
      repo.failure = null;
      _save(tester)();
      await tester.pumpAndSettle();
      expect(prepares, 1);
      expect(discarded, 1);
      expect(sourceDiscarded, 0);
      expect(
        fixture.controller.visitRecords.single.photoPath,
        '/draft/capture.jpg',
      );
      expect(await fixture.route.popped, VisitRecordConfirmationResult.saved);
    },
  );

  testWidgets(
    'committed record is recovered after lost response without recreating',
    (tester) async {
      final fixture = await _pump(
        tester,
        repository: _Repository()..failure = 'committed',
      );
      _save(tester)();
      await tester.pumpAndSettle();
      expect(fixture.repository.creates, 1);
      expect(fixture.controller.visitRecords, hasLength(1));
      expect(await fixture.route.popped, VisitRecordConfirmationResult.saved);
    },
  );

  for (final fails in [false, true]) {
    testWidgets(
      'completion is awaited; failure=$fails does not duplicate saved record',
      (tester) async {
        final gate = Completer<void>();
        var galleryCalls = 0;
        var comparisonCalls = 0;
        final fixture = await _pump(
          tester,
          repository: _Repository()
            ..completionGate = gate
            ..completionFails = fails,
          gallery: true,
          comparison: true,
          gallerySaver: (_) async {
            galleryCalls++;
            throw StateError('gallery failed');
          },
          comparisonSaver: (_) async {
            comparisonCalls++;
            throw StateError('render failed');
          },
        );
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, '保存并标记完成'),
            )
            .onPressed!();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(fixture.repository.creates, 1);
        expect(galleryCalls, 1);
        expect(comparisonCalls, 1);
        expect(fixture.route.isCurrent, isTrue);
        final point = fixture.controller.plan.points.first;
        expect(
          fixture.controller.completedPointIds.contains(point.id),
          isFalse,
        );
        gate.complete();
        await tester.pumpAndSettle();
        expect(fixture.repository.creates, 1);
        expect(fixture.controller.completedPointIds.contains(point.id), !fails);
        expect(
          await fixture.route.popped,
          fails
              ? VisitRecordConfirmationResult.saved
              : VisitRecordConfirmationResult.completed,
        );
      },
    );
  }

  testWidgets(
    'force dispose during reference write cleans new draft; no setState or location write',
    (tester) async {
      final gate = Completer<PreparedRecordImage>();
      var writes = 0;
      var discarded = 0;
      final fixture = await _pump(
        tester,
        strategy: PhotoLocationStrategy.useRecentLocation,
        pending: _location,
        referenceBytes: _referenceBytes,
        prepareReference: (_) => gate.future,
        writer: (_, _) async {
          writes++;
          return true;
        },
        discardSource: () async {
          discarded++;
        },
      );
      _save(tester)();
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      gate.complete(
        PreparedRecordImage(
          path: '/owned/ref.jpg',
          discard: () async {
            discarded++;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(fixture.repository.creates, 0);
      expect(writes, 0);
      expect(discarded, 2);
    },
  );

  testWidgets(
    'force dispose during location write cleans copy after writer finishes',
    (tester) async {
      final gate = Completer<PreparedPhotoLocation>();
      var discarded = 0;
      final fixture = await _pump(
        tester,
        strategy: PhotoLocationStrategy.useRecentLocation,
        pending: _location,
        writer: (_, _) async => true,
        prepare: ({required sourcePath, required location, required writer}) =>
            gate.future,
        discardSource: () async {
          discarded++;
        },
      );
      _save(tester)();
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      expect(discarded, 0);
      gate.complete(
        PreparedPhotoLocation(
          path: '/owned/location.jpg',
          written: true,
          discard: () async {
            discarded++;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(fixture.repository.creates, 0);
      expect(discarded, 2);
    },
  );

  testWidgets('cancel ready fix discards owned source without writing', (
    tester,
  ) async {
    var discarded = 0;
    var writes = 0;
    await _pump(
      tester,
      strategy: PhotoLocationStrategy.useRecentLocation,
      pending: _location,
      writer: (_, _) async {
        writes++;
        return true;
      },
      discardSource: () async {
        discarded++;
      },
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(discarded, 1);
  });
}
