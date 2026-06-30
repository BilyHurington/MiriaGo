import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/widgets/anitabi_network_image.dart';

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
          imageBuilder: (url, loadingBuilder, errorBuilder) {
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
          imageBuilder: (url, loadingBuilder, errorBuilder) {
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
          imageBuilder: (url, loadingBuilder, errorBuilder) {
            return Text(url);
          },
        ),
      ),
    );

    expect(find.text(mirrorUrl), findsOneWidget);
    expect(find.text(officialUrl), findsNothing);
  });
}
