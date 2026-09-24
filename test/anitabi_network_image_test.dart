import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/widgets/anitabi_network_image.dart';
import 'package:miriago/widgets/image_load_limiter.dart';

void main() {
  testWidgets('auto image source falls back to mirror on display failure', (
    tester,
  ) async {
    const officialUrl = 'https://image.anitabi.cn/points/115908/id.jpg';
    const mirrorUrl = 'https://img-tc.anitabi.cn/points/115908/id.jpg';
    final renderedUrls = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: AnitabiNetworkImage(
          url: officialUrl,
          loadingBuilder: (_) => const Text('loading'),
          errorBuilder: (_) => const Text('error'),
          imageBuilder: (url, frameBuilder, loadingBuilder, errorBuilder) {
            renderedUrls.add(url);
            if (url == officialUrl) {
              return Builder(
                builder: (context) =>
                    errorBuilder(context, Exception('blocked'), null),
              );
            }
            return Text(url);
          },
        ),
      ),
    );

    expect(find.text('loading'), findsOneWidget);
    expect(find.text('error'), findsNothing);

    await tester.pump();

    expect(find.text(mirrorUrl), findsOneWidget);
    expect(renderedUrls, [officialUrl, mirrorUrl]);
  });

  testWidgets('shows error only after every candidate fails', (tester) async {
    const officialUrl = 'https://image.anitabi.cn/points/115908/id.jpg';
    const mirrorUrl = 'https://img-tc.anitabi.cn/points/115908/id.jpg';
    final renderedUrls = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: AnitabiNetworkImage(
          url: officialUrl,
          loadingBuilder: (_) => const Text('loading'),
          errorBuilder: (_) => const Text('error'),
          imageBuilder: (url, frameBuilder, loadingBuilder, errorBuilder) {
            renderedUrls.add(url);
            return Builder(
              builder: (context) =>
                  errorBuilder(context, Exception('blocked'), null),
            );
          },
        ),
      ),
    );

    expect(find.text('loading'), findsOneWidget);
    expect(find.text('error'), findsNothing);

    await tester.pump();

    expect(find.text('error'), findsOneWidget);
    expect(renderedUrls, [officialUrl, mirrorUrl]);
  });

  testWidgets('fixed mirror image source starts from mirror host', (
    tester,
  ) async {
    const officialUrl =
        'https://image.anitabi.cn/points/115908/id.jpg?plan=h160';
    const mirrorUrl =
        'https://img-tc.anitabi.cn/points/115908/id.jpg?plan=h160';

    await tester.pumpWidget(
      MaterialApp(
        home: AnitabiNetworkImage(
          url: officialUrl,
          imageSource: AnitabiImageSource.mirror,
          errorBuilder: (_) => const Text('error'),
          imageBuilder: (url, frameBuilder, loadingBuilder, errorBuilder) {
            return Text(url);
          },
        ),
      ),
    );

    expect(find.text(mirrorUrl), findsOneWidget);
    expect(find.text(officialUrl), findsNothing);
  });

  group('load limiter', () {
    const firstUrl = 'https://image.anitabi.cn/points/1/a.jpg';
    const secondUrl = 'https://image.anitabi.cn/points/2/b.jpg';

    testWidgets('holds the permit until the first frame is decoded', (
      tester,
    ) async {
      final limiter = ImageLoadLimiter(1);
      final frames = _FakeFrames();
      addTearDown(frames.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              _limitedImage(firstUrl, limiter, frames),
              _limitedImage(secondUrl, limiter, frames),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // First build reports a null loading progress before any bytes arrive;
      // that must not release the permit.
      expect(limiter.activeCount, 1);
      expect(frames.rendered, [firstUrl]);
      expect(find.text('loading $firstUrl'), findsOneWidget);
      expect(find.text('loading $secondUrl'), findsOneWidget);

      frames.showFrame(firstUrl);
      await tester.pump();
      await tester.pump();

      expect(find.text(firstUrl), findsOneWidget);
      expect(frames.rendered, contains(secondUrl));
      expect(limiter.activeCount, 1);

      frames.showFrame(secondUrl);
      await tester.pump();

      expect(find.text(secondUrl), findsOneWidget);
      expect(limiter.activeCount, 0);
    });

    testWidgets('releases the permit once every candidate fails', (
      tester,
    ) async {
      final limiter = ImageLoadLimiter(1);

      await tester.pumpWidget(
        MaterialApp(
          home: AnitabiNetworkImage(
            url: firstUrl,
            loadLimiter: limiter,
            loadingBuilder: (_) => const Text('loading'),
            errorBuilder: (_) => const Text('error'),
            imageBuilder: (url, frameBuilder, loadingBuilder, errorBuilder) {
              return Builder(
                builder: (context) =>
                    errorBuilder(context, Exception('blocked'), null),
              );
            },
          ),
        ),
      );
      await tester.pump();
      expect(limiter.activeCount, 1);

      await tester.pump();
      await tester.pump();

      expect(find.text('error'), findsOneWidget);
      expect(limiter.activeCount, 0);
    });

    testWidgets('releases the permit when disposed mid-load', (tester) async {
      final limiter = ImageLoadLimiter(1);
      final frames = _FakeFrames();
      addTearDown(frames.dispose);

      await tester.pumpWidget(
        MaterialApp(home: _limitedImage(firstUrl, limiter, frames)),
      );
      await tester.pump();
      expect(limiter.activeCount, 1);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();

      expect(limiter.activeCount, 0);
    });

    testWidgets('queued request is returned when disposed before grant', (
      tester,
    ) async {
      final limiter = ImageLoadLimiter(1);
      final frames = _FakeFrames();
      addTearDown(frames.dispose);
      final blocker = await limiter.acquire();

      await tester.pumpWidget(
        MaterialApp(home: _limitedImage(firstUrl, limiter, frames)),
      );
      await tester.pump();
      expect(frames.rendered, isEmpty);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      blocker.release();
      await tester.pump();
      await tester.pump();

      expect(limiter.activeCount, 0);
    });

    testWidgets('switching url mid-load releases exactly one permit', (
      tester,
    ) async {
      final limiter = ImageLoadLimiter(2);
      final frames = _FakeFrames();
      addTearDown(frames.dispose);
      final url = ValueNotifier(firstUrl);
      addTearDown(url.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<String>(
            valueListenable: url,
            builder: (context, value, _) =>
                _limitedImage(value, limiter, frames),
          ),
        ),
      );
      await tester.pump();
      expect(limiter.activeCount, 1);

      url.value = secondUrl;
      await tester.pump();
      await tester.pump();

      expect(limiter.activeCount, 1);
      expect(frames.rendered.last, secondUrl);

      frames.showFrame(secondUrl);
      await tester.pump();
      expect(limiter.activeCount, 0);
    });
  });
}

Widget _limitedImage(String url, ImageLoadLimiter limiter, _FakeFrames frames) {
  return AnitabiNetworkImage(
    key: ValueKey('limited-$url'),
    url: url,
    imageSource: AnitabiImageSource.official,
    loadLimiter: limiter,
    loadingBuilder: (_) => Text('loading $url'),
    errorBuilder: (_) => const Text('error'),
    imageBuilder: (candidate, frameBuilder, loadingBuilder, errorBuilder) {
      frames.rendered.add(url);
      return ValueListenableBuilder<int?>(
        valueListenable: frames.frameFor(url),
        builder: (context, frame, _) => loadingBuilder(
          context,
          frameBuilder(context, Text(url), frame, false),
          null,
        ),
      );
    },
  );
}

class _FakeFrames {
  final rendered = <String>[];
  final _frames = <String, ValueNotifier<int?>>{};

  ValueNotifier<int?> frameFor(String url) =>
      _frames.putIfAbsent(url, () => ValueNotifier<int?>(null));

  void showFrame(String url) => frameFor(url).value = 0;

  void dispose() {
    for (final frame in _frames.values) {
      frame.dispose();
    }
  }
}
