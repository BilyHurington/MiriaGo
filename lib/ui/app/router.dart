import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/add/anitabi_import_page.dart';
import '../features/add/bangumi_search_page.dart';
import '../features/add/link_import_page.dart';
import '../features/add/manual_work_page.dart';
import '../features/add/point_form_page.dart';
import '../features/camera/camera_page.dart';
import '../features/go/go_page.dart';
import '../features/grading/grading_page.dart';
import '../features/memo/memo_page.dart';
import '../features/navigation/navigation_page.dart';
import '../features/navigation/route_preview_page.dart';
import '../features/organize/anchor_picker_page.dart';
import '../features/organize/box_assign_page.dart';
import '../features/organize/nearest_assign_page.dart';
import '../features/organize/organize_page.dart';
import '../features/plan/plan_overview_page.dart';
import '../features/plan/plan_workspace.dart';
import '../features/plans/plans_page.dart';
import '../features/points/point_records_page.dart';
import '../features/records/record_detail_page.dart';
import '../features/records/records_page.dart';
import '../features/settings/privacy_page.dart';
import '../features/settings/settings_page.dart';
import '../features/transfer/transfer_page.dart';
import '../features/works/works_page.dart';
import '../dev/component_gallery.dart';
import 'shell.dart';

/// Route paths. Use these constants (or the helpers) instead of literals.
abstract final class Routes {
  static const plan = '/plan';
  static const organize = '/plan/organize';
  static const nearestAssign = '/plan/organize/assign/nearest';
  static const boxAssign = '/plan/organize/assign/box';
  static const works = '/plan/works';
  static const bangumiSearch = '/plan/works/bangumi';
  static const manualWork = '/plan/works/new';
  static const anitabiImport = '/plan/import/anitabi';
  static const linkImport = '/plan/import/link';
  static const newPoint = '/plan/points/new';
  static const memo = '/plan/memo';
  static const transfer = '/plan/transfer';
  static const plans = '/plans';
  static const go = '/go';
  static const records = '/records';
  static const settings = '/settings';
  static const privacy = '/settings/about/privacy';

  static String organizeGroup(String groupId) =>
      '$organize?group=${Uri.encodeQueryComponent(groupId)}';
  static String anchorPicker(String groupId) =>
      '/plan/organize/anchor/${Uri.encodeComponent(groupId)}';
  static String editPoint(String pointId) =>
      '/plan/points/${Uri.encodeComponent(pointId)}/edit';
  static String anitabiImportFor({int? bangumiId, String? pointId}) {
    final query = <String, String>{
      if (bangumiId != null) 'bangumiId': '$bangumiId',
      'pid': ?pointId,
    };
    return Uri(
      path: anitabiImport,
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }

  static String bangumiSearchThenImport() => '$bangumiSearch?then=import';
  static String record(String recordId) =>
      '/records/${Uri.encodeComponent(recordId)}';
  static String recordGrading(String recordId) =>
      '/records/${Uri.encodeComponent(recordId)}/grading';
  static String pointRecords(String pointId) =>
      '/records/point/${Uri.encodeComponent(pointId)}';
  static String settingsSection(String section) => '/settings/$section';
  static String camera(String pointId) =>
      '/camera/${Uri.encodeComponent(pointId)}';
  static String routePreview(String pointId) =>
      '/route/${Uri.encodeComponent(pointId)}';
  static const navigate = '/navigate';
}

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Tabs of the shell, in display order.
enum ShellTab { plan, go, records, settings }

GoRouter buildRouter({required String initialLocation}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              ShellRoute(
                builder: (context, state, child) => PlanWorkspaceScaffold(
                  location: state.uri.path,
                  child: child,
                ),
                routes: [
                  GoRoute(
                    path: Routes.plan,
                    builder: (context, state) => const PlanOverviewPage(),
                    routes: [
                      GoRoute(
                        path: 'organize',
                        builder: (context, state) => OrganizePage(
                          initialGroupId: state.uri.queryParameters['group'],
                        ),
                        routes: [
                          GoRoute(
                            path: 'assign/nearest',
                            builder: (context, state) =>
                                const NearestAssignPage(),
                          ),
                          GoRoute(
                            path: 'assign/box',
                            builder: (context, state) => const BoxAssignPage(),
                          ),
                          GoRoute(
                            path: 'anchor/:groupId',
                            builder: (context, state) => AnchorPickerPage(
                              groupId: state.pathParameters['groupId']!,
                            ),
                          ),
                        ],
                      ),
                      GoRoute(
                        path: 'works',
                        builder: (context, state) => const WorksPage(),
                        routes: [
                          GoRoute(
                            path: 'bangumi',
                            builder: (context, state) => BangumiSearchPage(
                              continueToImport:
                                  state.uri.queryParameters['then'] == 'import',
                            ),
                          ),
                          GoRoute(
                            path: 'new',
                            builder: (context, state) => const ManualWorkPage(),
                          ),
                        ],
                      ),
                      GoRoute(
                        path: 'import/anitabi',
                        builder: (context, state) => AnitabiImportPage(
                          bangumiId: int.tryParse(
                            state.uri.queryParameters['bangumiId'] ?? '',
                          ),
                          pointId: state.uri.queryParameters['pid'],
                        ),
                      ),
                      GoRoute(
                        path: 'import/link',
                        builder: (context, state) => const LinkImportPage(),
                      ),
                      GoRoute(
                        path: 'points/new',
                        builder: (context, state) => const PointFormPage(),
                      ),
                      GoRoute(
                        path: 'points/:pointId/edit',
                        builder: (context, state) => PointFormPage(
                          pointId: state.pathParameters['pointId'],
                        ),
                      ),
                      GoRoute(
                        path: 'memo',
                        builder: (context, state) => const MemoPage(),
                      ),
                      GoRoute(
                        path: 'transfer',
                        builder: (context, state) => const TransferPage(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.go,
                builder: (context, state) => const GoPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.records,
                builder: (context, state) => RecordsPage(
                  selectedRecordId: state.uri.queryParameters['record'],
                ),
                routes: [
                  GoRoute(
                    path: 'point/:pointId',
                    builder: (context, state) => PointRecordsPage(
                      pointId: state.pathParameters['pointId']!,
                    ),
                  ),
                  GoRoute(
                    path: ':recordId',
                    builder: (context, state) => RecordDetailPage(
                      recordId: state.pathParameters['recordId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'grading',
                        builder: (context, state) => GradingPage(
                          recordId: state.pathParameters['recordId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (context, state) =>
                    SettingsPage(section: state.uri.queryParameters['section']),
                routes: [
                  GoRoute(
                    path: 'about/privacy',
                    builder: (context, state) => const PrivacyPage(),
                  ),
                  GoRoute(
                    path: ':section',
                    builder: (context, state) =>
                        SettingsPage(section: state.pathParameters['section']),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/_lab/components',
        builder: (context, state) => const ComponentGalleryPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.plans,
        builder: (context, state) => const PlansPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/camera/:pointId',
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          fullscreenDialog: true,
          child: CameraPage(pointId: state.pathParameters['pointId']!),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/route/:pointId',
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          fullscreenDialog: true,
          child: RoutePreviewPage(pointId: state.pathParameters['pointId']!),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.navigate,
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          fullscreenDialog: true,
          child: NavigationPage(args: state.extra ?? const Object()),
        ),
      ),
    ],
  );
}
