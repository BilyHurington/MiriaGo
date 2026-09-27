import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/pilgrimage_plan_controller.dart';
import 'package:miriago/records/records_screen.dart';
import 'package:miriago/widgets/app_status_banner.dart';

double contrast(Color a, Color b) {
  final values = [a.computeLuminance(), b.computeLuminance()]..sort();
  return (values.last + 0.05) / (values.first + 0.05);
}

void main() {
  tearDown(AppTheme.light);

  for (final dialog in [false, true]) {
    testWidgets(
      'overlay timeout preserves a newer ${dialog ? 'dialog' : 'page'}',
      (tester) async {
        final navigator = GlobalKey<NavigatorState>();
        late BuildContext home;
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            home: Builder(
              builder: (context) {
                home = context;
                return const Scaffold(body: Text('home'));
              },
            ),
          ),
        );
        var closed = false;
        final overlay = showStatusBannerOverlay(
          context: home,
          builder: (_) => const Text('old overlay'),
        ).then((_) => closed = true);
        await tester.pumpAndSettle();
        if (dialog) {
          showDialog<void>(
            context: home,
            builder: (_) => const AlertDialog(content: Text('new route')),
          );
        } else {
          navigator.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('new route')),
            ),
          );
        }
        await tester.pumpAndSettle();
        await tester.pump(appStatusSnackDuration);
        await tester.pumpAndSettle();
        await overlay;
        expect(closed, isTrue);
        expect(find.text('new route'), findsOneWidget);
        expect(find.text('old overlay', skipOffstage: false), findsNothing);
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.text('home'), findsOneWidget);
      },
    );
  }

  testWidgets('manually dismissed overlay cannot close its replacement', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    late BuildContext home;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: Builder(
          builder: (context) {
            home = context;
            return const Scaffold();
          },
        ),
      ),
    );
    showStatusBannerOverlay(context: home, builder: (_) => const Text('first'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    showStatusBannerOverlay(
      context: home,
      builder: (_) => const Text('second'),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1800));
    expect(find.text('second'), findsOneWidget);
    await tester.pump(appStatusSnackDuration);
    await tester.pumpAndSettle();
    expect(find.text('second'), findsNothing);
  });

  test(
    'dark foregrounds contrast with neutral/tinted surfaces without changing brand fills',
    () {
      for (final palette in AppThemePalette.values) {
        for (final custom in [
          0xFF000000,
          0xFF18214A,
          0xFF888888,
          0xFFFFFF00,
          0xFFFFFFFF,
        ]) {
          final theme = AppTheme.dark(
            palette: palette,
            customAccentValue: custom,
          );
          final fill = AppColors.accent;
          for (final color in [
            AppColors.accentForeground,
            AppColors.accentStrongForeground,
          ]) {
            for (final surface in [
              AppColors.background,
              AppColors.surface,
              Color.alphaBlend(fill.withValues(alpha: 0.16), AppColors.surface),
            ]) {
              expect(
                contrast(color, surface),
                greaterThanOrEqualTo(4.5),
                reason: '$palette/$custom',
              );
            }
          }
          expect(theme.colorScheme.primary, fill);
          expect(contrast(AppColors.onAccent, fill), greaterThanOrEqualTo(4.5));
          final button = theme.textButtonTheme.style!;
          expect(
            button.foregroundColor!.resolve({}),
            AppColors.accentStrongForeground,
          );
          expect(
            button.foregroundColor!.resolve({WidgetState.disabled}),
            isNot(AppColors.accentStrongForeground),
          );
          AppTheme.light(palette: palette, customAccentValue: custom);
          expect(AppColors.accentForeground, AppColors.accent);
          expect(AppColors.accentStrongForeground, AppColors.accentDark);
        }
      }
    },
  );

  for (final width in [320.0, 360.0, 430.0]) {
    for (final dark in [false, true]) {
      testWidgets('record cards fit width=$width dark=$dark with large text', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = SamplePilgrimageRepository();
        final controller = PilgrimagePlanController(
          plan: await repository.loadActivePlan(),
          visitRepository: repository,
        );
        await controller.loadVisitRecords();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
            home: RecordsScreen(
              controller: controller,
              settings: const AppSettings(),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        final dates = find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(
                'record-captured-row-',
              ),
        );
        expect(dates, findsWidgets);
        for (final element in dates.evaluate()) {
          final date = find.byElementPredicate((e) => identical(e, element));
          final text = find.descendant(of: date, matching: find.byType(Text));
          final rowRect = tester.getRect(date);
          final textRect = tester.getRect(text);
          expect(textRect.right, lessThanOrEqualTo(rowRect.right + 0.01));
          expect(textRect.bottom, lessThanOrEqualTo(rowRect.bottom + 0.01));
        }
        expect(find.byType(SliverList), findsWidgets);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
