import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/settings/privacy_policy_screen.dart';
import 'package:miriago/settings/settings_screen.dart';
import 'package:miriago/widgets/app_back_button.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _PolicyBundle extends CachingAssetBundle {
  _PolicyBundle(this.read);

  final Future<String> Function() read;
  var reads = 0;

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    if (key != PrivacyPolicyScreen.assetPath) return rootBundle.loadString(key);
    expect(cache, isFalse);
    reads++;
    return read();
  }

  @override
  Future<ByteData> load(String key) => rootBundle.load(key);
}

Widget _app({AssetBundle? bundle, Widget? home, double scale = 1}) {
  final app = MaterialApp(
    theme: AppTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: home ?? const PrivacyPolicyScreen(),
  );
  return bundle == null ? app : DefaultAssetBundle(bundle: bundle, child: app);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String bundledPolicy;
  setUpAll(() async {
    // Browser asset I/O must complete outside the widget fake clock.
    bundledPolicy = await rootBundle.loadString(PrivacyPolicyScreen.assetPath);
  });

  testWidgets(
    'real bundled policy renders both languages without remote content',
    (tester) async {
      final bundle = _PolicyBundle(() async => bundledPolicy);
      await tester.pumpWidget(_app(bundle: bundle));
      await tester.pumpAndSettle();
      final markdown = tester.widget<Markdown>(find.byType(Markdown));
      expect(markdown.data, bundledPolicy);
      expect(markdown.data, contains('# MiriaGo Privacy Policy'));
      expect(markdown.data, contains('# MiriaGo 隐私政策'));
      expect(markdown.selectable, isTrue);
      expect(markdown.onTapLink, isNull);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('remote markdown images stay text and links have no launcher', (
    tester,
  ) async {
    final bundle = _PolicyBundle(
      () async =>
          '# Policy\n\n![remote image](https://invalid.example/pixel.png)\n\n[external link](https://invalid.example/policy)',
    );
    await tester.pumpWidget(_app(bundle: bundle));
    await tester.pumpAndSettle();
    expect(find.text('remote image'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    final markdown = tester.widget<Markdown>(find.byType(Markdown));
    expect(markdown.onTapLink, isNull);
    await tester.tap(find.text('external link', findRichText: true));
    await tester.pump();
    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
    expect(bundle.reads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading failure retries the asset and rebuilds do not reread', (
    tester,
  ) async {
    final first = Completer<String>();
    final retry = Completer<String>();
    var attempt = 0;
    final bundle = _PolicyBundle(
      () => ++attempt == 1 ? first.future : retry.future,
    );
    await tester.pumpWidget(_app(bundle: bundle));
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
    await tester.pumpWidget(_app(bundle: bundle, scale: 1.2));
    await tester.pumpAndSettle();
    expect(bundle.reads, 2);
    expect(tester.takeException(), isNull);
  });

  for (final fail in [false, true]) {
    testWidgets(
      'leaving during asset load handles late completion fail=$fail',
      (tester) async {
        final pending = Completer<String>();
        final bundle = _PolicyBundle(() => pending.future);
        await tester.pumpWidget(
          _app(
            bundle: bundle,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PrivacyPolicyScreen(),
                    ),
                  ),
                  child: const Text('Open policy'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open policy'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.byType(AppBackButton));
        await tester.pumpAndSettle();
        expect(find.byType(PrivacyPolicyScreen), findsNothing);
        if (fail) {
          pending.completeError(StateError('late asset failure'));
        } else {
          pending.complete('# Late policy');
        }
        await tester.pumpAndSettle();
        expect(bundle.reads, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('settings about entry opens bundled policy and returns', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'MiriaGo',
      packageName: 'app.miriago',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await tester.pumpWidget(
      _app(
        bundle: _PolicyBundle(() async => bundledPolicy),
        home: SettingsScreen(
          settings: const AppSettings(),
          repository: SamplePilgrimageRepository(),
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('关于 MiriaGo'), 400);
    await tester.tap(find.text('关于 MiriaGo'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('隐私政策'), 250);
    await tester.tap(find.text('隐私政策'));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
    expect(find.byType(Markdown), findsOneWidget);
    await tester.tap(find.byType(AppBackButton).last);
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyPolicyScreen), findsNothing);
    expect(find.text('关于 MiriaGo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bundled text scrolls at narrow width and large text scale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(bundle: _PolicyBundle(() async => bundledPolicy), scale: 2),
    );
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(640));
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
