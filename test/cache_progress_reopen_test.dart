import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/pilgrimage_plan_controller.dart';
import 'package:miriago/plan/plan_screen.dart';
import 'package:miriago/plan/point_manager_screen.dart';
import 'package:miriago/plan/reference_cache_progress_dialog.dart';
import 'package:miriago/plan/reference_full_cache_runner.dart';
import 'package:miriago/plan_transfer/import_export_screen.dart';

void main() {
  test(
    'cache tasks are scoped by repository and plan and cannot start twice',
    () async {
      final repository = Object();
      final task = ReferenceCacheTask.forPlan(repository, 'a');
      expect(ReferenceCacheTask.forPlan(repository, 'a'), same(task));
      expect(ReferenceCacheTask.forPlan(repository, 'b'), isNot(same(task)));
      expect(ReferenceCacheTask.forPlan(Object(), 'a'), isNot(same(task)));
      final hold = Completer<void>();
      var calls = 0;
      Future<void> run(ValueChangedProgress progress) async {
        calls++;
        await hold.future;
      }

      final first = task.start(run);
      final second = task.start(run);
      expect(calls, 1);
      hold.complete();
      await first;
      await second;
      expect(task.isRunning, isFalse);
    },
  );

  for (final manager in [false, true]) {
    testWidgets(
      '${manager ? 'manager' : 'plan'} cache entry reopens latest live progress',
      (tester) async {
        final repository = SamplePilgrimageRepository();
        final plan = await repository.loadActivePlan();
        final controller = PilgrimagePlanController(plan: plan);
        final task = ReferenceCacheTask.forPlan(repository, plan.id);
        final hold = Completer<void>();
        late ValueChangedProgress report;
        var starts = 0;
        final running = task.start((onProgress) async {
          starts++;
          report = onProgress;
          report(
            const ReferenceFullCacheProgress(
              total: 10,
              processed: 2,
              succeeded: 2,
            ),
          );
          await hold.future;
        });
        addTearDown(() {
          if (!hold.isCompleted) hold.complete();
          controller.dispose();
        });
        await tester.binding.setSurfaceSize(const Size(430, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: manager
                ? PointManagerScreen(
                    plan: plan,
                    repository: repository,
                    settings: const AppSettings(),
                  )
                : PlanScreen(
                    controller: controller,
                    repository: repository,
                    settings: const AppSettings(),
                    onOpenMap: () {},
                    onOpenPlanManager: () {},
                    onOpenAddPoints: () {},
                    onOpenPointManager: () {},
                    onOpenImportExport: () {},
                  ),
          ),
        );
        await tester.pump();
        if (!manager) {
          tester
              .widget<IconButton>(
                find.byKey(const ValueKey('plan-actions-toggle')),
              )
              .onPressed!();
          await tester.pump(const Duration(milliseconds: 220));
        }
        void openProgress() {
          if (manager) {
            tester
                .widget<IconButton>(
                  find
                      .ancestor(
                        of: find.byTooltip(task.progress!.label),
                        matching: find.byType(IconButton),
                      )
                      .first,
                )
                .onPressed!();
          } else {
            final entry = find.byKey(
              const ValueKey('plan-action-cache-references'),
            );
            tester
                .widget<InkWell>(
                  find
                      .descendant(of: entry, matching: find.byType(InkWell))
                      .first,
                )
                .onTap!();
          }
        }

        openProgress();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));
        expect(find.text('2 / 10'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(milliseconds: 220));
        expect(
          find.byKey(const ValueKey('reference-cache-progress-dialog')),
          findsNothing,
        );
        report(
          const ReferenceFullCacheProgress(
            total: 10,
            processed: 7,
            succeeded: 6,
            failed: 1,
          ),
        );
        await tester.pump();
        openProgress();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));
        expect(find.text('7 / 10'), findsOneWidget);
        expect(find.text('70%'), findsOneWidget);
        expect(starts, 1);
        report(
          const ReferenceFullCacheProgress(
            total: 10,
            processed: 10,
            succeeded: 9,
            failed: 1,
            done: true,
          ),
        );
        hold.complete();
        await running;
        await tester.pump();
        expect(find.text('9 / 10 张成功 · 1 张失败'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'an exception before receiving progress is never reported as success',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReferenceCacheProgressDialog(
              run: (_) async => throw StateError('repository unavailable'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('参考图缓存失败'), findsOneWidget);
      expect(find.textContaining('缓存中断'), findsOneWidget);
      expect(find.text('参考图缓存完成'), findsNothing);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'export cache switch remains visibly enabled when off ($dark)',
      (tester) async {
        final repository = SamplePilgrimageRepository();
        final plan = await repository.loadActivePlan();
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: ImportExportScreen(plan: plan, repository: repository),
          ),
        );
        await tester.pump();
        final finder = find.byKey(
          const ValueKey('export-include-reference-cache'),
        );
        var toggle = tester.widget<SwitchListTile>(finder);
        expect(toggle.value, isFalse);
        expect(toggle.onChanged, isNotNull);
        expect(toggle.thumbColor!.resolve({}), AppColors.accent);
        expect(toggle.trackOutlineColor!.resolve({}), AppColors.accent);
        expect(toggle.thumbColor!.resolve({WidgetState.disabled}), isNull);
        toggle.onChanged!(true);
        await tester.pump();
        toggle = tester.widget<SwitchListTile>(finder);
        expect(toggle.value, isTrue);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
