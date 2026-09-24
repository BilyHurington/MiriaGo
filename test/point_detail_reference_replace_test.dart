import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:miriago/app_theme.dart';
import 'package:miriago/data/user_reference_image_stub.dart'
    if (dart.library.io) 'package:miriago/data/user_reference_image_io.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/point_detail/point_detail_sheet.dart';
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

Future<void> _waitFor(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
  expect(done(), isTrue, reason: 'asynchronous file operation did not settle');
}

void main() {
  late Directory root;
  late String source;
  late PathProviderPlatform previousPaths;
  late _Paths paths;
  const channel = MethodChannel('plugins.flutter.io/image_picker');

  List<File> images() => root
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.contains('user_reference_images'))
      .toList();

  setUp(() {
    root = Directory.systemTemp.createTempSync('point-detail-replace-');
    source = '${root.path}/source.png';
    File(
      source,
    ).writeAsBytesSync(img.encodePng(img.Image(width: 2, height: 2)));
    previousPaths = PathProviderPlatform.instance;
    paths = _Paths(root.path);
    PathProviderPlatform.instance = paths;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => source);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    PathProviderPlatform.instance = previousPaths;
    root.deleteSync(recursive: true);
  });

  Future<void> openSheet(
    WidgetTester tester,
    Future<void> Function(PilgrimagePoint, StoredUserReferenceImage) replace,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => PointDetailSheet.show(
                context,
                point: _point,
                status: VisitStatus.pending,
                onReplaceReference: replace,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapReplace(WidgetTester tester) async {
    await tester.ensureVisible(find.text('替换'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('替换'));
    await tester.pump();
  }

  testWidgets('closing the sheet before commit drops the stored copy', (
    tester,
  ) async {
    var replaceCalls = 0;
    await openSheet(tester, (_, _) async => replaceCalls++);
    paths.gate = Completer<void>();
    await tapReplace(tester);
    await _waitFor(tester, () => paths.requested);
    expect(find.text('正在替换参考图...'), findsOneWidget);

    Navigator.of(tester.element(find.byType(PointDetailSheet))).pop();
    await tester.pumpAndSettle();
    paths.gate!.complete();
    await _waitFor(tester, () => find.text('参考图替换已取消').evaluate().isNotEmpty);

    expect(replaceCalls, 0);
    expect(images(), isEmpty);
    expect(find.text('正在替换参考图...'), findsNothing);
    expect(find.text('参考图替换失败，请稍后重试'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed save clears the banner and keeps the stored image', (
    tester,
  ) async {
    await openSheet(tester, (_, _) async => throw StateError('reread failed'));
    await tapReplace(tester);
    await _waitFor(
      tester,
      () => find.text('参考图替换失败，请稍后重试').evaluate().isNotEmpty,
    );

    expect(find.text('正在替换参考图...'), findsNothing);
    // The commit outcome is unknown, so the image must not be deleted.
    expect(images(), hasLength(2));
    expect(find.byType(PointDetailSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a committed replacement is kept and closes the sheet', (
    tester,
  ) async {
    StoredUserReferenceImage? committed;
    await openSheet(tester, (_, image) async => committed = image);
    await tapReplace(tester);
    await _waitFor(tester, () => find.text('已替换参考图').evaluate().isNotEmpty);
    await tester.pumpAndSettle();

    expect(committed, isNotNull);
    expect(images(), hasLength(2));
    expect(File(committed!.fullImagePath).existsSync(), isTrue);
    expect(find.byType(PointDetailSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
