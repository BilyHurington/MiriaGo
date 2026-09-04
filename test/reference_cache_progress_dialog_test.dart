import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/plan/reference_cache_progress_dialog.dart';
import 'package:miriago/plan/reference_full_cache_runner.dart';

void main() {
  testWidgets('shows in-progress cache state with percent', (tester) async {
    final started = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReferenceCacheProgressDialog(
            run: (onProgress) async {
              onProgress(
                const ReferenceFullCacheProgress(
                  total: 18,
                  processed: 8,
                  succeeded: 8,
                ),
              );
              started.complete();
              await Completer<void>().future;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await started.future;
    await tester.pump();

    expect(find.text('正在缓存参考图...'), findsOneWidget);
    expect(find.text('8 / 18'), findsOneWidget);
    expect(find.text('44%'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reference-cache-progress-bar')),
      findsOneWidget,
    );
    expect(find.text('提示：缓存过程中请保持网络连接，避免切换页面或锁屏。'), findsOneWidget);
    expect(find.text('重试失败'), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('shows all-success cache state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReferenceCacheProgressDialog(
            run: (onProgress) async {
              onProgress(
                const ReferenceFullCacheProgress(
                  total: 18,
                  processed: 18,
                  succeeded: 18,
                  done: true,
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('参考图缓存完成'), findsOneWidget);
    expect(find.text('18 / 18 张成功，已保存到本地'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.text('重试失败'), findsNothing);
    expect(find.text('重试全部'), findsNothing);
  });

  testWidgets('shows partial-success cache state with retry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReferenceCacheProgressDialog(
            run: (onProgress) async {
              onProgress(
                const ReferenceFullCacheProgress(
                  total: 18,
                  processed: 18,
                  succeeded: 14,
                  failed: 4,
                  done: true,
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('参考图缓存完成'), findsOneWidget);
    expect(find.text('14 / 18 张成功 · 4 张失败'), findsOneWidget);
    expect(find.text('重试失败'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('shows all-failed cache state with retry all', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReferenceCacheProgressDialog(
            run: (onProgress) async {
              onProgress(
                const ReferenceFullCacheProgress(
                  total: 18,
                  processed: 18,
                  failed: 18,
                  done: true,
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('参考图缓存失败'), findsOneWidget);
    expect(find.text('0 / 18 张成功 · 18 张失败'), findsOneWidget);
    expect(find.text('重试全部'), findsOneWidget);
  });

  testWidgets('pins the cache banner to the bottom like a snack bar', (
    tester,
  ) async {
    final started = Completer<void>();
    final hold = Completer<void>();
    addTearDown(() {
      if (!hold.isCompleted) {
        hold.complete();
      }
    });

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: FilledButton(
                  onPressed: () {
                    showReferenceCacheProgressDialog(
                      context: context,
                      run: (onProgress) async {
                        onProgress(
                          const ReferenceFullCacheProgress(
                            total: 18,
                            processed: 8,
                            succeeded: 8,
                          ),
                        );
                        started.complete();
                        await hold.future;
                      },
                    );
                  },
                  child: const Text('start-cache'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('start-cache'));
    await tester.pump();
    await started.future;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final banner = tester.getRect(
      find.byKey(const ValueKey('reference-cache-progress-dialog')),
    );
    expect(banner.top, greaterThan(844 * 0.5));
    expect(banner.bottom, closeTo(844 - 12, 8));
    expect(find.text('正在缓存参考图...'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('tapping outside closes the cache banner', (tester) async {
    final started = Completer<void>();
    final hold = Completer<void>();
    addTearDown(() {
      if (!hold.isCompleted) {
        hold.complete();
      }
    });

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: FilledButton(
                  onPressed: () {
                    showReferenceCacheProgressDialog(
                      context: context,
                      run: (onProgress) async {
                        onProgress(
                          const ReferenceFullCacheProgress(
                            total: 18,
                            processed: 8,
                            succeeded: 8,
                          ),
                        );
                        started.complete();
                        await hold.future;
                      },
                    );
                  },
                  child: const Text('start-cache'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('start-cache'));
    await tester.pump();
    await started.future;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('reference-cache-progress-dialog')),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(24, 24));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('reference-cache-progress-dialog')),
      findsNothing,
    );
  });

  testWidgets('cache banner auto-closes after 3 seconds', (tester) async {
    final started = Completer<void>();
    final hold = Completer<void>();
    addTearDown(() {
      if (!hold.isCompleted) {
        hold.complete();
      }
    });

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: FilledButton(
                  onPressed: () {
                    showReferenceCacheProgressDialog(
                      context: context,
                      run: (onProgress) async {
                        onProgress(
                          const ReferenceFullCacheProgress(
                            total: 18,
                            processed: 8,
                            succeeded: 8,
                          ),
                        );
                        started.complete();
                        await hold.future;
                      },
                    );
                  },
                  child: const Text('start-cache'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('start-cache'));
    await tester.pump();
    await started.future;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('reference-cache-progress-dialog')),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('reference-cache-progress-dialog')),
      findsNothing,
    );
  });

  testWidgets('debug preview shows all cache banner states', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: FilledButton(
                  onPressed: () =>
                      showReferenceCacheBannerDebugPreview(context),
                  child: const Text('start-cache'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('start-cache'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const ValueKey('reference-cache-debug-running')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reference-cache-debug-success')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reference-cache-debug-partial')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reference-cache-debug-failed')),
      findsOneWidget,
    );
    expect(find.text('正在缓存参考图...'), findsOneWidget);
    expect(find.text('重试失败'), findsOneWidget);
    expect(find.text('重试全部'), findsOneWidget);
    expect(find.text('参考图缓存完成'), findsNWidgets(2));

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('reference-cache-debug-running')),
      findsNothing,
    );
  });

  testWidgets('retry returns to the in-progress state', (tester) async {
    var runs = 0;
    final secondRun = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReferenceCacheProgressDialog(
            run: (onProgress) async {
              runs += 1;
              if (runs == 1) {
                onProgress(
                  const ReferenceFullCacheProgress(
                    total: 18,
                    processed: 18,
                    succeeded: 14,
                    failed: 4,
                    done: true,
                  ),
                );
                return;
              }
              onProgress(
                const ReferenceFullCacheProgress(
                  total: 4,
                  processed: 1,
                  succeeded: 1,
                ),
              );
              await secondRun.future;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('重试失败'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reference-cache-retry')));
    await tester.pump();
    await tester.pump();

    expect(find.text('正在缓存参考图...'), findsOneWidget);
    expect(find.text('1 / 4'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    secondRun.complete();
    await tester.pump();
  });
}
