# Miria component library — API reference

Import everything with `import 'package:miriago/ui/components/components.dart';`
(relative: `../../components/components.dart`). The barrel also re-exports
`design/theme.dart` (tokens, `context.colors`, `context.text`),
`context.layout`, all layout primitives and `VisitStatus`.
See `lib/ui/dev/component_gallery.dart` for live examples of every component.

Notes:
- Focus rings only appear during keyboard navigation (`InputMode`).
- `MiriaButton`/`SegmentedControl` re-measure labels when web fonts load; use
  `FontAwareLayoutBuilder` when you measure text in a LayoutBuilder.

## lib/ui/layout/input_mode.dart
- `InputMode.isPointer` / `InputMode.pointer` (ValueListenable) — last input was mouse/trackpad.
- `InputMode.isKeyboardNavigating` / `InputMode.keyboardNavigating`.
- `InputModeBuilder(builder: (ctx, pointer) => …)`.

## lib/ui/layout/content_column.dart
- `ContentColumn({child, maxWidth = 720, padding, gutter})`
- `SliverContentColumn({sliver, maxWidth = 720, gutter, top, bottom})`

## lib/ui/layout/list_detail_layout.dart
- `ListDetailLayout({list, detail?, detailPlaceholder?, minListWidth = 320, maxListWidth = 520, initialListWidth?, forceSinglePane?})` — below `expanded` only `list` (push detail as a route). Pointer: draggable divider (double-click reset, ←/→). Aligns to fold hinge.

## lib/ui/layout/adaptive_grid.dart
- `adaptiveMinTileWidth(windowClass)` (168 compact / 220), `adaptiveColumnCount(width, {minTileWidth, spacing, minColumns = 2})`
- `AdaptiveGrid({children, minTileWidth?, spacing = 12, runSpacing?, minColumns = 2, childAspectRatio?})` (non-lazy, natural height)
- `SliverAdaptiveGrid({itemCount, itemBuilder, minTileWidth?, spacing, runSpacing?, minColumns, childAspectRatio?, mainAxisExtent?})` (lazy)

## lib/ui/layout/editor_layout.dart
- `EditorLayout({preview, controls, controlsWidth = 340, previewFlex = 5, controlsFlex = 6, previewBackground?, controlsBackground?, forceSideBySide?})` — side by side when width ≥ 720 or landscape ≥ 560; else stacked. `controls` must scroll itself. `EditorLayout.sideBySideFor(size)`.

## lib/ui/layout/page_scaffold.dart
- `MiriaPageScaffold({title, subtitle?, actions, leading?, body? | slivers?, padSlivers = false, bottomBar?, floatingActionButton?, largeTitle = true, appBarBottom?, backgroundColor?, scrollController?})` — large collapsing title on compact in sliver mode; `bottomBar` gets surface bg, hairline, gutters, safe area.

## lib/ui/layout/adaptive_modal.dart
- `usesBottomSheet(context)` — compact && !short.
- `showAdaptiveSheet<T>(context, {builder, title?, maxWidth = 560, scrollable = true, headerActions, padding?, isDismissible = true})` — bottom sheet on compact, 480–560 dialog otherwise.
- `AdaptiveMenuItem<T>(label, value, icon?, subtitle?, destructive, enabled, checked)`; `showAdaptiveMenu<T>(context, {items, title?, anchor: BuildContext?, position: Offset?})` — popup at anchor on pointer/wide, bottom list otherwise.
- `MenuAction(label, onSelected, icon?, subtitle?, destructive, enabled)`; `showActionMenu(context, {actions, title?, anchor?, position?})` runs the chosen action.
- `showConfirmDialog(context, {title, message, confirmLabel, cancelLabel = '取消', destructive, notice?, emphasizedValues, extraContent?})` → `Future<bool>`; destructive → red button + 「此操作无法撤销」.
- `showConfirmDialogWithCheckbox(context, {…, checkboxLabel, checkboxInitialValue})` → `Future<ConfirmResult>` = `({bool confirmed, bool checked})`.
- `showInputDialog(context, {title, label?, hint?, helper?, initialValue, confirmLabel = '确定', cancelLabel, validator, keyboardType?, maxLines = 1, maxLength?, trim = true, showPasteButton = false})` → `Future<String?>`.
- `showAdaptivePanel<T>(context, {builder, title, actions, dismissible = true, maxWidth = 960})` — full-height sheet on compact, large dialog otherwise; `dismissible:false` closes only via Navigator.pop.
- `showBlockingProgress<T>(context, {task, message = '请稍候…'})`; `BlockingProgress({busy, child, message})`.
- Building blocks: `MiriaDialog({title, content, actions?, maxWidth = 420})`, `DialogActionRow({confirmLabel, onConfirm, onCancel, cancelLabel, destructive, confirmLoading, autofocusConfirm})`, `EmphasizedMessage(message, {emphasizedValues})`, `ConfirmDialog`.

## components/pressable.dart
- `MiriaPressable({child, onTap, onLongPress, onContextMenu: ValueChanged<Offset>, borderRadius, selected, enabled, semanticLabel, excludeSemantics, button, hoverColor, focusNode, autofocus, customSemanticsActions})`; `FocusRing({focused, child, borderRadius})`.

## components/buttons.dart
- `MiriaButton({label, onPressed, variant: primary|secondary|ghost|danger|tonal, size: lg 48|md 44|sm 36, icon?, shortLabel?, loading, expand, tooltip?, semanticLabel?, trailingIcon?, focusNode, autofocus})`; `.secondary`, `.ghost`, `.danger`. Label collapses full → short → icon. Don't wrap icon/short-label buttons in `IntrinsicWidth`.
- `MiriaIconButton({icon, tooltip (required), onPressed, variant: plain|filled|primary|overlay, selected, selectedIcon?, compact, badgeCount?, badgeDot, color?})`
- `SplitNavButton({onNavigate, onOpenExternal, label = '导航', available = true, size, inAppKey, externalKey})` — `available:false` → disabled 「坐标待补充」.

## components/inputs.dart
- `SearchField({controller?, focusNode?, hint = '搜索', onChanged, onSubmitted, onCleared, autofocus, enabled})` (clear 「清空搜索」, Esc clears)
- `MiriaTextField({label?, hint?, helper?, error?, required, controller?, initialValue?, focusNode, onChanged, onSubmitted, validator, keyboardType, textInputAction, inputFormatters, maxLines, minLines, maxLength, obscureText, enabled, readOnly, autofocus, prefixIcon?, suffix?, labelTrailing?, locale?})` — label above, red * when required, works in `Form`.

## components/selection.dart
- `SegmentedControl<T>({options: [SegmentOption(value, label, icon?)], value, onChanged, expand = true, forceStacked?, collapseToIcons = true, semanticLabel?})`
- `ChipGroup<T>({options: [ChipOption(value, label, icon?, count?, color?, locale?)], selected: Set<T>, onChanged, multiSelect = true, scrollable = false, padding})`; `ChipGroup<T>.single({options, value, onSelected, scrollable, padding})`
- `SelectField<T>({options: [SelectOption(value, label, subtitle?, icon?)], value, onChanged, label?, hint = '请选择', pickerTitle?, helper?, error?})`

## components/rows.dart
- `ListRow({title, subtitle?, leading?, trailing?, below?, onTap, onLongPress, contextActions: List<MenuAction>, contextMenuTitle?, selected, enabled, showChevron, titleLocale?, subtitleLocale?, titleMaxLines = 2, subtitleMaxLines = 2, titleStyle?, routeLine: RouteLine?, padding?, minHeight = 56, borderRadius, semanticLabel?})` — right-click (and long-press when onLongPress null) open contextActions.
- `SectionHeader({title, count?, trailing?, actionLabel?, onAction?, padding})`
- `KeyValueRow({label, value, copyable = true, copyValue?, valueLocale?, monospaceDigits, onTap, valueWidget?, padding})`
- `SwitchRow({title, value, onChanged, subtitle?, leading?})`
- `SliderRow({title, value, onChanged, min, max, divisions?, logScale, format?, subtitle?, onChangeStart?, onChangeEnd?})`; `ValueCapsule({label, enabled})`

## components/controls.dart
- `MiriaVerticalSlider({value, onChanged, min, max, onChangeStart?, onChangeEnd?, height = 200, width = 44, semanticLabel?, format?, onDark = true, keyboardStep = 0.05})`
- `MiriaStepper({value, onChanged, min, max, step = 1, format?, semanticLabel?})`

## components/copyable_text.dart
- `copyToClipboard(context, value, {label})` (toast 「已复制」), `showCopyBubble`, `hideCopyBubble`
- `CopyableText({text, copyLabel, copyText?, style, maxLines, overflow, textAlign, locale, onTap})`

## components/status.dart
- `StatusBadge({status: VisitStatus, compact})`, `StatusBadge.labelFor(status)`
- `MiriaTone {neutral, primary, spot, success, warning, danger, info}`, `toneColors(c, tone)`
- `Tag({label, tone, color?, icon?, onTap?, locale?})`, `CountBubble({count, tone, max = 999})`
- `InfoBanner({message, kind: info|success|warning|error, title?, icon?, actionLabel?, onAction?, onDismiss?})`

## components/route.dart
- `RouteLine({status, isFirst, isLast, previousCompleted, nodeY?, width = 28, nodeSize = 18})`, `RouteLine.semanticsFor(status)`
- `RouteDots({statuses, maxDots = 12, dotSize, spacing})`, `RouteDots.counts({completed, total, hasCurrent})`
- `Sparkle({size, color?})`, `RouteMotif({width, height})`

## components/feedback.dart
- `EmptyState({title, message?, icon?, actionLabel?, actionIcon?, onAction?, secondaryActionLabel?, onSecondaryAction?, compact})`
- `ErrorState({title = '加载失败', detail?, onRetry?, retryLabel = '重试', icon, compact})`
- `Skeleton.box({width?, height = 120, borderRadius})`, `Skeleton.line({height = 12, widthFactor = 1, width?})`, `Skeleton.circle({size = 40})`
- `ProgressRing({value?, size = 36, strokeWidth = 4, color?, trackColor?, child?, semanticLabel?})`

## components/photo_compare.dart
- `PhotoCompareMode {stacked, sideBySide, slider, overlay}` (`.label`, `.icon`)
- `PhotoCompare({reference: Widget, photo: Widget, referenceAspectRatio = 16/9, photoAspectRatio?, mode?, onModeChanged?, showModeSelector = true, referenceLabel = '参考图', photoLabel = '巡礼图', onTapReference?, onTapPhoto?, initialOverlayOpacity = 0.5, borderRadius, showLabels})`
- `PhotoCompare.images({reference: ImageProvider, photo: ImageProvider, …})`; `PhotoCompare.autoMode(width, refAspect)`

## components/surfaces.dart
- `MiriaCard({child, onTap?, onLongPress?, onContextMenu?, padding, selected, color?, borderRadius, semanticLabel?, clip})`
- `GlassPanel({child, padding, borderRadius, translucent = true, blurSigma = 18, elevated = true})`
- `SheetHandle({padding})`

## components/context_menu_region.dart
- `ContextMenuRegion({actions: List<MenuAction>, child, title?, enabled, longPress = true})`

## components/font_aware_layout_builder.dart
- `FontAwareLayoutBuilder({builder})`

## Toasts (lib/ui/app/toast.dart)
- `context.showToast(title, {kind: ToastKind.success|running|warning|error|info, message, action: ToastAction(label:, onPressed:), duration})`

## Test harness
- `test/ui/components/harness.dart`: `pumpComponent(tester, child, {size, textScale, dark})`
- `test/helpers/pump_app.dart`: `pumpMiriaApp(tester, {location, size, textScale, repository})`, `TestSizes.*`
