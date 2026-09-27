import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/ui/design/theme.dart';
import 'package:miriago/ui/features/settings/privacy_page.dart';

import '../../helpers/pump_app.dart';

class _PolicyBundle extends CachingAssetBundle {
  _PolicyBundle(this.read);

  final Future<String> Function() read;
  var reads = 0;

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    if (key != PrivacyPage.assetPath) return rootBundle.loadString(key);
    expect(cache, isFalse);
    reads++;
    return read();
  }

  @override
  Future<ByteData> load(String key) => rootBundle.load(key);
}

Widget _app(AssetBundle bundle, {double scale = 1}) {
  return DefaultAssetBundle(
    bundle: bundle,
    child: MaterialApp(
      theme: buildMiriaTheme(MiriaColors.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const PrivacyPage(),
    ),
  );
}

void main() {
  late String bundledPolicy;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    bundledPolicy = await rootBundle.loadString(PrivacyPage.assetPath);
  });

  testWidgets('the settings route renders the bundled policy', (tester) async {
    await pumpMiriaApp(tester, location: '/settings/about/privacy');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    final markdown = tester.widget<Markdown>(find.byType(Markdown));
    expect(markdown.data, contains('# MiriaGo Privacy Policy'));
    expect(markdown.data, contains('# MiriaGo 隐私政策'));
    expect(markdown.selectable, isTrue);
    expect(markdown.onTapLink, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('remote images stay text and links have no launcher', (
    tester,
  ) async {
    final bundle = _PolicyBundle(
      () async =>
          '# Policy\n\n![remote image](https://invalid.example/pixel.png)\n\n[external link](https://invalid.example/policy)',
    );
    await tester.pumpWidget(_app(bundle));
    await tester.pumpAndSettle();
    expect(find.text('remote image'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    await tester.tap(find.text('external link', findRichText: true));
    await tester.pump();
    expect(find.byType(PrivacyPage), findsOneWidget);
    expect(bundle.reads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading failure retries; rebuilds do not reread', (
    tester,
  ) async {
    final first = Completer<String>();
    final retry = Completer<String>();
    var attempt = 0;
    final bundle = _PolicyBundle(
      () => ++attempt == 1 ? first.future : retry.future,
    );
    await tester.pumpWidget(_app(bundle));
    expect(find.text('正在读取隐私政策...'), findsOneWidget);
    first.completeError(StateError('asset unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('隐私政策读取失败'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(find.text('正在读取隐私政策...'), findsOneWidget);
    retry.complete('# Recovered policy');
    await tester.pumpAndSettle();
    expect(
      tester.widget<Markdown>(find.byType(Markdown)).data,
      '# Recovered policy',
    );
    await tester.pumpWidget(_app(bundle, scale: 1.2));
    await tester.pumpAndSettle();
    expect(bundle.reads, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolls at narrow width and text scale 2', (tester) async {
    tester.view.physicalSize = TestSizes.phoneSmall;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(_PolicyBundle(() async => bundledPolicy), scale: 2),
    );
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(Markdown),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(568));
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
