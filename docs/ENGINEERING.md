# MiriaGo Next · Engineering conventions

Read this together with `docs/DESIGN.md` (what to build) and
`docs/FEATURE_CHECKLIST.md` (what must not be lost).

## 0. Hard rules

1. **Never write to `/Users/bilyhurington/Documents/Seichi-Junrei-Helper`.**
   It is the old app and is read-only reference material:
   - old UI (behaviour, strings, edge cases): `…/Seichi-Junrei-Helper/lib/**`
   - old tests (edge cases to port): `…/Seichi-Junrei-Helper/test/**`
2. Only edit files in the directories your task owns. Shared files
   (`lib/ui/app/**`, `lib/ui/design/**`, `lib/ui/layout/**`,
   `lib/application/*.dart` at top level, `pubspec.yaml`, backend files)
   belong to the lead; request changes in your final report.
3. **Do not modify backend files** (everything under `lib/` that is not
   `lib/ui/**`, `lib/application/**` or `lib/main.dart`). They are copied
   verbatim from the old repo at commit 849fd9a so fixes can be synced.
   If a backend change is unavoidable, describe it in your report.
4. Keep user-facing Chinese strings **identical** to the old app unless
   DESIGN §10 changes them. Copy them from the old source.
5. No git commands that change state. The lead commits.
6. Leave `flutter analyze` clean for your files; run your tests.

## 1. Layout of the code

```
lib/
  <backend>                 copied verbatim (data/, plan/, plan_transfer/, records/,
                            color_grading/, map/, camera_reference/, desktop/, …)
  app_theme.dart            LEGACY theme kept only because backend map helpers read
                            AppColors.*. Do not use it in new UI.
  application/              use-case layer (no widgets). Top-level files are shared:
    app_services.dart         AppServices, StartupService
    platform_capabilities.dart
    settings_store.dart       SettingsStore
    plan_session.dart         PlanSession  (single source of truth for the active plan)
    plans_store.dart          PlansStore   (plan library)
    reference_cache_task.dart ReferenceCacheTask / ReferenceCacheCenter
    <area>/                   feature-owned services, e.g. application/capture/
  ui/
    app/                    app root, router, shell, toasts, task indicator (lead)
    design/                 tokens + theme (lead); components live in ui/components
    components/             Miria component library
    layout/                 window classes + layout primitives
    map/                    map foundation (PlanMap, markers, panels)
    features/<area>/        feature pages
    dev/                    component gallery / layout lab (debug + web preview)
```

## 2. State and data access

All app-wide objects are provided with `provider` in `lib/ui/app/app.dart`:

| Type | Use |
|---|---|
| `PilgrimageRepository` | `context.read<PilgrimageRepository>()` for reads/writes not tied to the active plan |
| `PlanSession` | `context.watch<PlanSession>()`; `session.plan`, `session.controller` |
| `PlansStore` | plan library (list/switch/create/duplicate/delete/reorder) |
| `SettingsStore` | `store.settings`; `store.patch((s) => s.copyWith(...))` |
| `ReferenceCacheCenter` | start full reference caching; tasks shown by the shell |
| `ToastController` | use `context.showToast(...)` |
| `PlatformCapabilities` | "can we …?" questions instead of platform checks |
| `AppServices` | repository + capabilities + desktop launcher info |

**Writes to the active plan structure** go through the session so every
pane updates together:

```dart
final session = context.read<PlanSession>();
await session.mutate(
  (repo, planId) => repo.renamePlanGroup(planId: planId, groupId: id, name: name),
);
```

Runtime state (current/selected point, completion, visit records) uses the
controller: `session.controller.completePoint(point)`,
`session.controller.setCurrentPoint(point)`, `createVisitRecord(...)` etc.
`session.refresh()` re-reads the active plan; `session.load()` rebuilds
after a plan switch. Never keep your own copy of the plan that can drift;
derive from `session.plan` in `build`.

Business flows that the old UI implemented inside screens must be ported
**line by line** into `lib/application/<area>/…` services (plain Dart +
ChangeNotifier), with logic tests. Pages call the services.

## 3. Routing

- Paths and helpers: `Routes` in `lib/ui/app/router.dart`
  (`context.push(Routes.works)`, `context.go(Routes.go)`,
  `context.push(Routes.editPoint(id))`, …).
- Tabs are `StatefulShellRoute` branches (计划 / 巡礼 / 记录 / 设置).
- Full-screen routes on the root navigator: `/camera/:pointId`,
  `/route/:pointId`, `/navigate` (extra = args), `/plans`.
- Pages can return results with `context.pop(result)` / `context.push<T>`.
- Block leaving while saving with `PopScope(canPop: false, …)` and show the
  old toast (e.g. 「正在保存记录，请稍候。」).

### Cross-feature entry points (import these, don't re-implement)

| Function / widget | File | Owner |
|---|---|---|
| `showPointDetail(context, pointId:, scope:)`, `PointInspectorScope/Controller/Panel` | `features/points/point_detail_entry.dart` | A |
| `showPlanSwitcher`, `PlanSwitcherButton` | `features/plans/plan_switcher.dart` | B |
| `PlanWorkspaceScaffold` | `features/plan/plan_workspace.dart` | B |
| `pickGroup`, `showCreateGroupDialog`, `showGroupSwitcherSheet`, `kUngroupedId` | `features/organize/group_picker.dart` | C |
| `pickLocation`, `showCoordinateInputDialog` | `features/organize/location_picker.dart` | C |
| `showAddMenu`, `openPointEditor` | `features/add/add_menu.dart` | D |
| `showComparisonExport`, `ComparisonExportSettingsPanel` | `features/export/comparison_export.dart` | E |
| `openImageViewer`, `ViewerImage` | `features/viewer/image_viewer.dart` | F |
| `openImportPreview` | `features/transfer/import_preview_page.dart` | F |
| `openCamera(context, pointId:)` | `features/camera/camera_entry.dart` | G |
| `openRoutePreview(context, pointId:)` | `features/navigation/navigation_entry.dart` | G |

Signatures of these are fixed. Owners implement the bodies; everybody
else calls them.

## 4. Design system usage

- Colours: `context.colors` (`MiriaColors`). **No hard-coded colours** in
  pages (exception: user-chosen colours, map data).
- Text: `context.text.titleMedium` etc.; `context.text.caption` for
  time/coordinates; tabular figures via `MiriaFonts.tabular`.
- Point / place names and Japanese subtitles: pass
  `locale: MiriaFonts.japanese` to `Text` so kanji use Japanese glyphs.
- Spacing `Space.x4`, radii `Radii.md` / `Radii.mdAll`, shadows
  `Elevations.level2(context.colors)`, motion `Motion.standard`,
  `Motion.emphasized`; respect `Motion.reduced(context)`.
- Icons: `Symbols.xxx_rounded` from `material_symbols_icons`
  (`import 'package:material_symbols_icons/symbols.dart';`). Selected
  state: `Icon(icon, fill: 1)`.
- Components: prefer `lib/ui/components/**` (see its `components.dart`
  barrel) over ad-hoc widgets; Material widgets are themed already.
- Toasts: `context.showToast('已添加「X」。', kind: ToastKind.success)`.

## 5. Adaptive layout

- `context.layout` → `WindowLayout` (`windowClass`, `isShort`,
  `usesSidePanel`, `showsListDetail`, `gutter`).
- Classes: compact <600, medium 600–839, expanded 840–1199,
  large 1200–1599, xlarge ≥1600; short = height <480.
- Use the layout primitives (`ContentColumn`, `ListDetailLayout`,
  `AdaptiveGrid`, `EditorLayout`, `MapPanelLayout`) and the adaptive modal
  API (`showAdaptiveSheet`, `showAdaptiveMenu`, `showConfirmDialog`,
  `showInputDialog`).
- Never use fixed heights for rows that contain text; use min heights.
- Everything must work from 320×568 to 2560×1440, in landscape, with text
  scale 2.0. Test at 390×844, 820×1180, 1440×900 at least.

## 6. Tests

- Logic tests for services in `test/application/<area>/…`.
- Widget tests in `test/ui/<area>/…` using `test/helpers/pump_app.dart`
  (`pumpMiriaApp(tester, location: '/plan/works', size: const Size(390, 844))`).
- Port relevant edge-case tests from the old repo's `test/` (they were
  removed here because they referenced old screens).
- Run: `flutter test --no-pub test/ui/<area> test/application/<area>`.

## 7. Web preview

```
flutter build web --no-pub   # or --debug
npm run preview:web           # http://127.0.0.1:8792 (Anitabi static proxy included)
```
Plain web uses `SamplePilgrimageRepository` (1 plan, 7 groups, 27 points,
15 records). Preview seeds: `?seed=empty|stress|many-plans` (dev only).
