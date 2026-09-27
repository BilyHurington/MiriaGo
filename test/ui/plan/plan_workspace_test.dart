import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:miriago/ui/features/plan/plan_workspace.dart';

import '../../helpers/pump_app.dart' show TestSizes;
import '../camera/camera_test_harness.dart';

/// A workspace page that registers a leave guard answering [allow].
class _GuardedPage extends StatefulWidget {
  const _GuardedPage({required this.label, required this.guard});

  final String label;
  final _Guard guard;

  @override
  State<_GuardedPage> createState() => _GuardedPageState();
}

class _Guard {
  bool allow = false;
  int calls = 0;
}

class _GuardedPageState extends State<_GuardedPage> {
  PlanWorkspaceScope? _scope;

  Future<bool> _canLeave() async {
    widget.guard.calls++;
    return widget.guard.allow;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = PlanWorkspaceScope.maybeOf(context);
    if (!identical(scope, _scope)) {
      _scope?.removeLeaveGuard(_canLeave);
      _scope = scope?..addLeaveGuard(_canLeave);
    }
  }

  @override
  void dispose() {
    _scope?.removeLeaveGuard(_canLeave);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(widget.label)));
}

void main() {
  Future<(GoRouter, _Guard)> pumpWorkspace(
    WidgetTester tester, {
    required String location,
  }) async {
    setTestWindow(tester, TestSizes.desktop);
    final stores = await FeatureTestStores.load();
    final guard = _Guard();
    Widget page(String label) => Scaffold(body: Center(child: Text(label)));
    final router = GoRouter(
      initialLocation: location,
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              PlanWorkspaceScaffold(location: state.uri.path, child: child),
          routes: [
            GoRoute(
              path: '/plan',
              builder: (context, state) => page('overview-page'),
              routes: [
                GoRoute(
                  path: 'works',
                  builder: (context, state) =>
                      _GuardedPage(label: 'works-root', guard: guard),
                  routes: [
                    GoRoute(
                      path: 'bangumi',
                      builder: (context, state) =>
                          _GuardedPage(label: 'works-sub', guard: guard),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'memo',
                  builder: (context, state) => page('memo-page'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      featureTestRouterApp(stores: stores, router: router),
    );
    await tester.pumpAndSettle();
    return (router, guard);
  }

  String path(GoRouter router) =>
      router.routeInformationProvider.value.uri.path;

  testWidgets('re-selecting the section from a sub page asks the guards', (
    tester,
  ) async {
    final (router, guard) = await pumpWorkspace(
      tester,
      location: '/plan/works/bangumi',
    );
    expect(find.text('works-sub'), findsOneWidget);

    await tester.tap(find.text('作品'));
    await tester.pumpAndSettle();
    expect(guard.calls, greaterThan(0));
    expect(path(router), '/plan/works/bangumi');
    expect(find.text('works-sub'), findsOneWidget);

    guard.allow = true;
    await tester.tap(find.text('作品'));
    await tester.pumpAndSettle();
    expect(path(router), '/plan/works');
    expect(find.text('works-root'), findsOneWidget);
  });

  testWidgets('re-selecting the current section root does nothing', (
    tester,
  ) async {
    final (router, guard) = await pumpWorkspace(
      tester,
      location: '/plan/works',
    );
    await tester.tap(find.text('作品'));
    await tester.pumpAndSettle();
    expect(guard.calls, 0);
    expect(path(router), '/plan/works');
  });

  testWidgets('another section is blocked until the guard allows it', (
    tester,
  ) async {
    final (router, guard) = await pumpWorkspace(
      tester,
      location: '/plan/works',
    );
    await tester.tap(find.text('备忘录'));
    await tester.pumpAndSettle();
    expect(guard.calls, 1);
    expect(path(router), '/plan/works');

    guard.allow = true;
    await tester.tap(find.text('备忘录'));
    await tester.pumpAndSettle();
    expect(path(router), '/plan/memo');
    expect(find.text('memo-page'), findsOneWidget);
  });
}
