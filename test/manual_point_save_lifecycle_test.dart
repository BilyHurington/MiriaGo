import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/add_points_screen.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/widgets/app_back_button.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

const _work = PilgrimageWork(
  id: 'work',
  title: 'Work',
  subtitle: 'Work',
  city: 'City',
  source: WorkSource.manual,
);
const _point = PilgrimagePoint(
  id: 'point',
  work: _work,
  name: 'Point',
  subtitle: 'Place',
  position: PilgrimagePoint.pendingPosition,
  episodeLabel: 'EP 1',
  referenceLabel: 'Reference',
);
final _plan = PilgrimagePlan(
  id: 'plan',
  name: 'Plan',
  area: 'City',
  works: const [_work],
  points: const [_point],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

enum _Result { success, beforeCommitError, afterCommitError }

class _Repository extends SamplePilgrimageRepository {
  _Repository({this.result = _Result.success}) : super(plans: [_plan]);
  _Result result;
  final release = Completer<void>();
  PilgrimagePoint? submitted;
  int calls = 0;

  Future<PilgrimagePlan> _save(
    PilgrimagePoint point,
    Future<PilgrimagePlan> Function() commit,
  ) async {
    submitted = point;
    calls++;
    await release.future;
    if (result == _Result.beforeCommitError) throw StateError('save failed');
    final saved = await commit();
    if (result == _Result.afterCommitError) {
      throw StateError('reread failed after commit');
    }
    return saved;
  }

  @override
  Future<PilgrimagePlan> addPointToPlan({
    required String planId,
    required PilgrimagePoint point,
  }) => _save(point, () => super.addPointToPlan(planId: planId, point: point));

  @override
  Future<PilgrimagePlan> updatePointInPlan({
    required String planId,
    required PilgrimagePoint point,
  }) =>
      _save(point, () => super.updatePointInPlan(planId: planId, point: point));
}

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  Completer<void>? gate;
  bool requested = false;
  @override
  Future<String?> getApplicationDocumentsPath() async {
    requested = true;
    await gate?.future;
    return path;
  }
}

void _press(WidgetTester tester, Finder finder) {
  tester.widget<ButtonStyleButton>(finder).onPressed!();
}

Finder get _save => find.byKey(const ValueKey('point-form-save'));
Finder get _pick => find.widgetWithText(OutlinedButton, '上传参考图');

bool _manualCanPop(WidgetTester tester) => tester
    .widget<PopScope>(
      find
          .ancestor(
            of: _save,
            matching: find.byWidgetPredicate((widget) => widget is PopScope),
          )
          .first,
    )
    .canPop;

class _PopObserver extends NavigatorObserver {
  int pops = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pops++;
  }
}

Future<void> _waitFor(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
  expect(done(), isTrue, reason: 'asynchronous file operation did not settle');
}

Future<GlobalKey<NavigatorState>> _open(
  WidgetTester tester,
  _Repository repository, {
  bool editing = true,
  NavigatorObserver? observer,
}) async {
  await tester.binding.setSurfaceSize(const Size(1100, 2600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      navigatorObservers: [?observer],
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () {
              if (editing) {
                EditPointScreen.open(
                  context,
                  plan: _plan,
                  repository: repository,
                  point: _point,
                );
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AddPointsScreen(
                      plan: _plan,
                      repository: repository,
                      settings: const AppSettings(),
                    ),
                  ),
                );
              }
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  if (!editing) {
    final action = find.byKey(const ValueKey('add-points-manual-point'));
    await tester.tap(action);
    await tester.pumpAndSettle();
    for (final field in tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    )) {
      if (field.key == const ValueKey('point-form-latitude')) {
        field.controller!.text = '35';
      } else if (field.key == const ValueKey('point-form-longitude')) {
        field.controller!.text = '135';
      }
      if (field.validator != null &&
          field.key != const ValueKey('point-form-latitude') &&
          field.key != const ValueKey('point-form-longitude')) {
        field.controller!.text = 'New point';
      }
    }
  }
  return navigator;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late String source;
  late PathProviderPlatform previousPaths;
  late _Paths paths;
  Completer<String?>? pickerGate;
  var pickerCalls = 0;
  const channel = MethodChannel('plugins.flutter.io/image_picker');
  List<File> images() => root
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.contains('user_reference_images'))
      .toList();

  setUp(() {
    root = Directory.systemTemp.createTempSync('manual-point-lifecycle-');
    source = '${root.path}/source.png';
    File(
      source,
    ).writeAsBytesSync(img.encodePng(img.Image(width: 2, height: 2)));
    previousPaths = PathProviderPlatform.instance;
    paths = _Paths(root.path);
    PathProviderPlatform.instance = paths;
    pickerGate = null;
    pickerCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'pickImage');
          pickerCalls++;
          return pickerGate == null ? source : await pickerGate!.future;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    PathProviderPlatform.instance = previousPaths;
    root.deleteSync(recursive: true);
  });

  Future<void> choose(WidgetTester tester) async {
    _press(tester, _pick);
    await tester.pump();
    await _waitFor(
      tester,
      () => tester.widget<ButtonStyleButton>(_save).onPressed != null,
    );
    expect(images(), hasLength(2));
  }

  for (final editing in [false, true]) {
    testWidgets(
      '${editing ? 'edit' : 'add'} blocks back and input until save completes',
      (tester) async {
        final repository = _Repository();
        final navigator = await _open(tester, repository, editing: editing);
        expect(_manualCanPop(tester), isTrue);
        await choose(tester);
        expect(_manualCanPop(tester), isTrue);
        _press(tester, _save);
        await tester.pump();
        expect(_manualCanPop(tester), isFalse);
        expect(repository.calls, 1);
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const ValueKey('point-form-name')),
              )
              .enabled,
          isFalse,
        );
        expect(
          tester
              .widget<ButtonStyleButton>(
                find.widgetWithText(OutlinedButton, '重新选择'),
              )
              .onPressed,
          isNull,
        );
        await navigator.currentState!.maybePop();
        tester
            .widget<AppBackButton>(find.byType(AppBackButton).last)
            .onPressed!();
        await tester.pump();
        expect(_save, findsOneWidget);
        expect(images(), hasLength(2));
        repository.release.complete();
        await tester.pumpAndSettle();
        expect(_save, findsNothing);
        expect(images(), hasLength(2));
        expect(
          (await repository.loadActivePlan()).points.any(
            (point) =>
                point.referenceFullImagePath ==
                repository.submitted!.referenceFullImagePath,
          ),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );

    for (final result in _Result.values) {
      testWidgets(
        '${editing ? 'edit' : 'add'} forced dispose during $result preserves submitted images',
        (tester) async {
          final repository = _Repository(result: result);
          await _open(tester, repository, editing: editing);
          await choose(tester);
          _press(tester, _save);
          await tester.pump();
          expect(repository.calls, 1);
          await tester.pumpWidget(const SizedBox());
          expect(images(), hasLength(2));
          repository.release.complete();
          await tester.pumpAndSettle();
          expect(images(), hasLength(2));
          if (result == _Result.afterCommitError) {
            expect(
              (await repository.loadActivePlan()).points.any(
                (point) =>
                    point.referenceFullImagePath ==
                    repository.submitted!.referenceFullImagePath,
              ),
              isTrue,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('uncertain edit cancellation never deletes submitted images', (
    tester,
  ) async {
    final repository = _Repository(result: _Result.afterCommitError);
    final navigator = await _open(tester, repository);
    await choose(tester);
    _press(tester, _save);
    repository.release.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<ButtonStyleButton>(_save).onPressed, isNotNull);
    await navigator.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(images(), hasLength(2));
  });

  testWidgets(
    'picker blocks stale save and repeated pick callbacks; late native result after dispose is ignored',
    (tester) async {
      final repository = _Repository();
      final navigator = await _open(tester, repository);
      final save = tester.widget<ButtonStyleButton>(_save).onPressed!;
      final pick = tester.widget<ButtonStyleButton>(_pick).onPressed!;
      pickerGate = Completer<String?>();
      pick();
      pick();
      save();
      await tester.pump();
      expect(pickerCalls, 1);
      expect(repository.calls, 0);
      expect(_manualCanPop(tester), isFalse);
      expect(tester.widget<ButtonStyleButton>(_save).onPressed, isNull);
      await navigator.currentState!.maybePop();
      expect(_save, findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      pickerGate!.complete(source);
      await tester.pumpAndSettle();
      expect(paths.requested, isFalse);
      expect(images(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dispose during image storage cleans the late result', (
    tester,
  ) async {
    final repository = _Repository();
    await _open(tester, repository);
    paths.gate = Completer<void>();
    final parentZone = Zone.current;
    String? createdThumbnail;
    IOOverrides.runZoned(
      () => _press(tester, _pick),
      createFile: (path) {
        if (path.contains('user_reference_images') &&
            path.endsWith('/thumb.jpg')) {
          createdThumbnail = path;
        }
        return parentZone.run(() => File(path));
      },
    );
    await _waitFor(tester, () => paths.requested);
    await tester.pumpWidget(const SizedBox());
    paths.gate!.complete();
    await tester.pump();
    // Wait for both storage and the subsequent asynchronous deletion.
    await _waitFor(
      tester,
      () =>
          createdThumbnail != null &&
          !File(createdThumbnail!).parent.existsSync() &&
          images().isEmpty,
    );
    await tester.pump();
    expect(createdThumbnail, isNotNull);
    expect(File(source).existsSync(), isTrue);
    expect(images(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ordinary cancellation deletes only new pending images', (
    tester,
  ) async {
    final repository = _Repository();
    final navigator = await _open(tester, repository);
    await choose(tester);
    expect(_manualCanPop(tester), isTrue);
    await navigator.currentState!.maybePop();
    await tester.pumpAndSettle();
    await _waitFor(tester, () => images().isEmpty);
    expect(File(source).existsSync(), isTrue);
    expect(repository.calls, 0);
  });

  testWidgets(
    'idle system pop locks stale callbacks while retaining draft through transition',
    (tester) async {
      final repository = _Repository();
      final observer = _PopObserver();
      final navigator = await _open(
        tester,
        repository,
        editing: false,
        observer: observer,
      );
      await choose(tester);
      expect(_manualCanPop(tester), isTrue);
      final save = tester.widget<ButtonStyleButton>(_save).onPressed!;
      final back = tester
          .widget<AppBackButton>(find.byType(AppBackButton).last)
          .onPressed!;
      final paths = images().map((image) => image.path).toList();
      await navigator.currentState!.maybePop();
      back();
      save();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(paths.every((path) => File(path).existsSync()), isTrue);
      expect(observer.pops, 1);
      expect(repository.calls, 0);
      await tester.pumpAndSettle();
      await _waitFor(tester, () => images().isEmpty);
      expect(find.text('添加内容'), findsOneWidget);
      expect(navigator.currentState!.canPop(), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  for (final delay in [Duration.zero, const Duration(milliseconds: 80)]) {
    testWidgets(
      'cancellation retains preview files through pop animation ($delay)',
      (tester) async {
        final repository = _Repository();
        final observer = _PopObserver();
        final navigator = await _open(
          tester,
          repository,
          editing: false,
          observer: observer,
        );
        await choose(tester);
        final back = tester
            .widget<AppBackButton>(find.byType(AppBackButton).last)
            .onPressed!;
        final save = tester.widget<ButtonStyleButton>(_save).onPressed!;
        final paths = images().map((image) => image.path).toList();
        final preview = tester.widget<Image>(
          find.byKey(const ValueKey('manual-reference-preview')),
        );
        expect(preview.image, isA<MemoryImage>());
        expect(preview.errorBuilder, isNotNull);
        back();
        back();
        save();
        await tester.pump();
        await tester.pump(delay);
        expect(paths.every((path) => File(path).existsSync()), isTrue);
        expect(observer.pops, 1);
        expect(repository.calls, 0);
        expect(find.text('添加内容'), findsOneWidget);
        await tester.pumpAndSettle();
        await _waitFor(tester, () => images().isEmpty);
        expect(navigator.currentState!.canPop(), isTrue);
        expect(find.text('添加内容'), findsOneWidget);
        expect(observer.pops, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'pending preview resolves from snapshot after its draft files are gone',
    (tester) async {
      final repository = _Repository();
      await _open(tester, repository);
      await choose(tester);
      final preview = tester.widget<Image>(
        find.byKey(const ValueKey('manual-reference-preview')),
      );
      final provider = preview.image as MemoryImage;
      // A fresh provider must decode without reopening the deleted draft file.
      for (final image in images()) {
        image.deleteSync();
      }
      final bytes = Uint8List.fromList(provider.bytes);
      await tester.pumpWidget(
        MaterialApp(
          home: Image.memory(bytes, errorBuilder: preview.errorBuilder),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      final decoded = tester.widget<RawImage>(find.byType(RawImage));
      expect(decoded.image, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'uncertain new save disables duplicate insertion even via stale callback',
    (tester) async {
      final repository = _Repository(result: _Result.afterCommitError);
      final navigator = await _open(tester, repository, editing: false);
      await choose(tester);
      final save = tester.widget<ButtonStyleButton>(_save).onPressed!;
      save();
      final submittedId = repository.submitted!.id;
      expect(
        repository.submitted!.referenceFullImagePath,
        contains(submittedId),
      );
      repository.release.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<ButtonStyleButton>(_save).onPressed, isNull);
      expect(find.textContaining('保存结果未确认，请返回并刷新计划'), findsOneWidget);
      save();
      await tester.pump();
      expect(repository.calls, 1);
      expect(
        (await repository.loadActivePlan()).points.where(
          (point) => point.id == submittedId,
        ),
        hasLength(1),
      );
      await navigator.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(images(), hasLength(2));
    },
  );

  testWidgets(
    'uncertain edit retries same id successfully without deleting reference',
    (tester) async {
      final repository = _Repository(result: _Result.afterCommitError);
      await _open(tester, repository);
      await choose(tester);
      _press(tester, _save);
      repository.release.complete();
      await tester.pumpAndSettle();
      repository.result = _Result.success;
      _press(tester, _save);
      await tester.pumpAndSettle();
      expect(repository.calls, 2);
      expect(repository.submitted!.id, _point.id);
      expect((await repository.loadActivePlan()).points, hasLength(1));
      expect(_save, findsNothing);
      expect(images(), hasLength(2));
    },
  );
}
