import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../components/buttons.dart';
import '../components/surfaces.dart';
import '../design/theme.dart';
import 'input_mode.dart';
import 'window_class.dart';

// ---------------------------------------------------------------------------
// Decisions
// ---------------------------------------------------------------------------

/// Whether adaptive sheets appear as bottom sheets in this window
/// (compact and not short). Otherwise they are centred dialogs.
bool usesBottomSheet(BuildContext context) {
  final layout = context.layout;
  return layout.isCompact && !layout.isShort;
}

double _dialogMaxHeight(BuildContext context) {
  final media = MediaQuery.of(context);
  return math.max(
    160,
    media.size.height - media.viewInsets.bottom - media.padding.vertical - 48,
  );
}

// ---------------------------------------------------------------------------
// Sheet
// ---------------------------------------------------------------------------

/// Shows [builder]'s content as a draggable modal bottom sheet on compact
/// windows (max 90 % height, safe area, keyboard insets) and as a centred
/// dialog (480–[maxWidth] wide) otherwise. DESIGN §5.4 `sheet`.
///
/// The content is wrapped in a scroll view unless [scrollable] is false
/// (pass false when [builder] returns its own `ListView`; it then gets
/// bounded height via `Flexible`). Close with `Navigator.pop(context, value)`.
///
/// ```dart
/// final group = await showAdaptiveSheet<String>(
///   context,
///   title: '选择片区',
///   builder: (context) => GroupList(onPick: (id) => Navigator.pop(context, id)),
/// );
/// ```
Future<T?> showAdaptiveSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  double maxWidth = 560,
  bool scrollable = true,
  List<Widget> headerActions = const [],
  EdgeInsetsGeometry? padding,
  bool isDismissible = true,
  bool useRootNavigator = true,
}) {
  final contentPadding =
      padding ?? const EdgeInsets.fromLTRB(Space.x4, 0, Space.x4, Space.x4);
  if (usesBottomSheet(context)) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      showDragHandle: false,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sheetContext) => _SheetFrame(
        title: title,
        headerActions: headerActions,
        scrollable: scrollable,
        padding: contentPadding,
        child: builder(sheetContext),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: isDismissible,
    builder: (dialogContext) => _DialogFrame(
      title: title,
      maxWidth: maxWidth,
      headerActions: headerActions,
      scrollable: scrollable,
      padding: contentPadding,
      showClose: isDismissible,
      child: builder(dialogContext),
    ),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.headerActions,
    required this.scrollable,
    required this.padding,
    required this.child,
  });

  final String? title;
  final List<Widget> headerActions;
  final bool scrollable;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = math.max(
      200.0,
      media.size.height * 0.9 - media.viewInsets.bottom,
    );
    final body = scrollable
        ? SingleChildScrollView(padding: padding, child: child)
        : Padding(padding: padding, child: child);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            if (title != null || headerActions.isNotEmpty)
              _Header(title: title, actions: headerActions),
            Flexible(child: body),
            SizedBox(height: media.padding.bottom),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    this.actions = const [],
    this.onClose,
    this.leadingClose = false,
  });

  final String? title;
  final List<Widget> actions;
  final VoidCallback? onClose;
  final bool leadingClose;

  @override
  Widget build(BuildContext context) {
    final close = onClose == null
        ? null
        : MiriaIconButton(
            icon: Symbols.close_rounded,
            tooltip: '关闭',
            onPressed: onClose,
          );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        leadingClose && close != null ? Space.x1 : Space.x4,
        Space.x2,
        Space.x2,
        Space.x2,
      ),
      child: Row(
        children: [
          if (leadingClose && close != null) ...[
            close,
            const SizedBox(width: Space.x1),
          ],
          Expanded(
            child: title == null
                ? const SizedBox(height: 44)
                : Semantics(
                    header: true,
                    child: Text(title!, style: context.text.titleLarge),
                  ),
          ),
          ...actions,
          if (!leadingClose && close != null) close,
        ],
      ),
    );
  }
}

class _DialogFrame extends StatelessWidget {
  const _DialogFrame({
    required this.title,
    required this.maxWidth,
    required this.headerActions,
    required this.scrollable,
    required this.padding,
    required this.showClose,
    required this.child,
  });

  final String? title;
  final double maxWidth;
  final List<Widget> headerActions;
  final bool scrollable;
  final EdgeInsetsGeometry padding;
  final bool showClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - 40;
    final body = scrollable
        ? SingleChildScrollView(padding: padding, child: child)
        : Padding(padding: padding, child: child);
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: math.min(480, width),
          maxWidth: maxWidth,
          maxHeight: _dialogMaxHeight(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              title: title,
              actions: headerActions,
              onClose: showClose
                  ? () => Navigator.of(context).maybePop()
                  : null,
            ),
            Flexible(child: body),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Menu
// ---------------------------------------------------------------------------

/// One entry of [showAdaptiveMenu].
@immutable
class AdaptiveMenuItem<T> {
  const AdaptiveMenuItem({
    required this.label,
    required this.value,
    this.icon,
    this.subtitle,
    this.destructive = false,
    this.enabled = true,
    this.checked = false,
  });

  final String label;
  final T value;
  final IconData? icon;
  final String? subtitle;

  /// Danger colour (delete, remove).
  final bool destructive;
  final bool enabled;

  /// Shows a check mark (current choice in pickers).
  final bool checked;
}

/// Callback-style menu entry for [showActionMenu], [ContextMenuRegion]
/// and `ListRow.contextActions`.
@immutable
class MenuAction {
  const MenuAction({
    required this.label,
    required this.onSelected,
    this.icon,
    this.subtitle,
    this.destructive = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onSelected;
  final IconData? icon;
  final String? subtitle;
  final bool destructive;
  final bool enabled;
}

/// Shows a list of choices and returns the chosen value (null when
/// dismissed). DESIGN §5.4 `menu`.
///
/// * Anchored ([anchor] = the trigger's context, or a global [position]
///   such as a right-click point) on pointer input or wide windows: a
///   popup menu next to the trigger.
/// * Otherwise: a bottom action list (compact) or a small dialog (short
///   windows).
///
/// ```dart
/// final action = await showAdaptiveMenu<String>(
///   context,
///   anchor: buttonContext,
///   items: const [
///     AdaptiveMenuItem(label: '重命名', icon: Symbols.edit_rounded, value: 'rename'),
///     AdaptiveMenuItem(label: '删除', icon: Symbols.delete_rounded, value: 'delete', destructive: true),
///   ],
/// );
/// ```
Future<T?> showAdaptiveMenu<T>(
  BuildContext context, {
  required List<AdaptiveMenuItem<T>> items,
  String? title,
  BuildContext? anchor,
  Offset? position,
  bool useRootNavigator = true,
}) {
  final anchored = anchor != null || position != null;
  final layout = context.layout;
  final popup = anchored && (InputMode.isPointer || !layout.isCompact);
  if (popup) {
    return _showPopupMenu<T>(
      context,
      items: items,
      title: title,
      anchor: anchor,
      position: position,
      useRootNavigator: useRootNavigator,
    );
  }
  final list = _MenuList<T>(items: items);
  if (usesBottomSheet(context)) {
    return showModalBottomSheet<T>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      useRootNavigator: useRootNavigator,
      showDragHandle: false,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sheetContext) => _SheetFrame(
        title: title,
        headerActions: const [],
        scrollable: true,
        padding: const EdgeInsets.only(bottom: Space.x2),
        child: list,
      ),
    );
  }
  return showDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    builder: (dialogContext) => _DialogFrame(
      title: title,
      maxWidth: 400,
      headerActions: const [],
      scrollable: true,
      padding: const EdgeInsets.only(bottom: Space.x2),
      showClose: true,
      child: list,
    ),
  );
}

/// Shows [actions] with [showAdaptiveMenu] and runs the chosen one.
Future<void> showActionMenu(
  BuildContext context, {
  required List<MenuAction> actions,
  String? title,
  BuildContext? anchor,
  Offset? position,
}) async {
  final index = await showAdaptiveMenu<int>(
    context,
    title: title,
    anchor: anchor,
    position: position,
    items: [
      for (var i = 0; i < actions.length; i++)
        AdaptiveMenuItem(
          label: actions[i].label,
          value: i,
          icon: actions[i].icon,
          subtitle: actions[i].subtitle,
          destructive: actions[i].destructive,
          enabled: actions[i].enabled,
        ),
    ],
  );
  if (index != null) actions[index].onSelected();
}

Future<T?> _showPopupMenu<T>(
  BuildContext context, {
  required List<AdaptiveMenuItem<T>> items,
  required String? title,
  required BuildContext? anchor,
  required Offset? position,
  required bool useRootNavigator,
}) {
  final overlay =
      Navigator.of(
            context,
            rootNavigator: useRootNavigator,
          ).overlay!.context.findRenderObject()!
          as RenderBox;
  Rect target;
  final anchorBox = anchor?.findRenderObject() as RenderBox?;
  if (anchorBox != null && anchorBox.hasSize) {
    final topLeft = anchorBox.localToGlobal(Offset.zero, ancestor: overlay);
    target = Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy + anchorBox.size.height + 4,
      anchorBox.size.width,
      0,
    );
  } else {
    final local = overlay.globalToLocal(position ?? Offset.zero);
    target = Rect.fromLTWH(local.dx, local.dy, 0, 0);
  }
  final c = context.colors;
  final text = context.text;
  return showMenu<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    position: RelativeRect.fromRect(target, Offset.zero & overlay.size),
    constraints: const BoxConstraints(minWidth: 200, maxWidth: 320),
    items: [
      if (title != null)
        PopupMenuItem<T>(
          enabled: false,
          height: 32,
          child: Text(
            title,
            style: text.labelMedium?.copyWith(color: c.textTertiary),
          ),
        ),
      for (final item in items)
        PopupMenuItem<T>(
          value: item.value,
          enabled: item.enabled,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: Space.x3),
          child: _MenuItemContent(item: item, dense: true),
        ),
    ],
  );
}

class _MenuList<T> extends StatelessWidget {
  const _MenuList({required this.items});

  final List<AdaptiveMenuItem<T>> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items)
          Semantics(
            button: true,
            enabled: item.enabled,
            selected: item.checked,
            child: InkWell(
              onTap: item.enabled
                  ? () => Navigator.of(context).pop(item.value)
                  : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.x5,
                    vertical: Space.x2,
                  ),
                  child: _MenuItemContent(item: item),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MenuItemContent<T> extends StatelessWidget {
  const _MenuItemContent({required this.item, this.dense = false});

  final AdaptiveMenuItem<T> item;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final color = !item.enabled
        ? c.textDisabled
        : item.destructive
        ? c.danger
        : c.textPrimary;
    final iconColor = !item.enabled
        ? c.textDisabled
        : item.destructive
        ? c.danger
        : c.textSecondary;
    return Row(
      children: [
        if (item.icon != null) ...[
          Icon(item.icon, size: dense ? 20 : 22, color: iconColor),
          SizedBox(width: dense ? Space.x3 : Space.x4),
        ],
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: (dense ? text.bodyMedium : text.bodyLarge)?.copyWith(
                  color: color,
                  fontWeight: item.checked ? FontWeight.w600 : null,
                ),
              ),
              if (item.subtitle != null)
                Text(
                  item.subtitle!,
                  style: text.bodySmall?.copyWith(
                    color: item.enabled ? c.textSecondary : c.textDisabled,
                  ),
                ),
            ],
          ),
        ),
        if (item.checked) ...[
          const SizedBox(width: Space.x2),
          Icon(Symbols.check_rounded, size: 20, color: c.primaryText),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dialogs
// ---------------------------------------------------------------------------

/// A Miria dialog body: title, content and an action row, max 420 wide,
/// scrolls when the window is short. Use it inside `showDialog` for custom
/// dialogs; prefer [showConfirmDialog] / [showInputDialog] when they fit.
class MiriaDialog extends StatelessWidget {
  const MiriaDialog({
    required this.title,
    required this.content,
    this.actions,
    this.maxWidth = 420,
    super.key,
  });

  final String title;
  final Widget content;

  /// Usually a [DialogActionRow].
  final Widget? actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: _dialogMaxHeight(context),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.x5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: context.text.titleLarge),
              ),
              const SizedBox(height: Space.x3),
              content,
              if (actions != null) ...[
                const SizedBox(height: Space.x5),
                actions!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Cancel + confirm buttons side by side; stacks vertically when narrow
/// (old `AppDialogActionRow` / `ResponsiveTwoButtonRow`).
class DialogActionRow extends StatelessWidget {
  const DialogActionRow({
    required this.confirmLabel,
    required this.onConfirm,
    required this.onCancel,
    this.cancelLabel = '取消',
    this.destructive = false,
    this.confirmLoading = false,
    this.autofocusConfirm = false,
    super.key,
  });

  final String confirmLabel;
  final VoidCallback? onConfirm;
  final VoidCallback onCancel;
  final String cancelLabel;
  final bool destructive;
  final bool confirmLoading;
  final bool autofocusConfirm;

  @override
  Widget build(BuildContext context) {
    final cancel = MiriaButton.secondary(
      label: cancelLabel,
      onPressed: onCancel,
      size: MiriaButtonSize.lg,
      expand: true,
      autofocus: !autofocusConfirm && destructive,
    );
    final confirm = MiriaButton(
      label: confirmLabel,
      onPressed: onConfirm,
      variant: destructive
          ? MiriaButtonVariant.danger
          : MiriaButtonVariant.primary,
      size: MiriaButtonSize.lg,
      loading: confirmLoading,
      expand: true,
      autofocus: autofocusConfirm,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1, 2);
        final stack = constraints.maxWidth < 240 * scale;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              confirm,
              const SizedBox(height: Space.x2),
              cancel,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cancel),
            const SizedBox(width: Space.x2 + 2),
            Expanded(child: confirm),
          ],
        );
      },
    );
  }
}

/// Message text with [emphasizedValues] rendered bold in the primary text
/// colour (old `_EmphasizedMessage`).
class EmphasizedMessage extends StatelessWidget {
  const EmphasizedMessage(
    this.message, {
    this.emphasizedValues = const [],
    this.style,
    super.key,
  });

  final String message;
  final List<String> emphasizedValues;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base =
        style ??
        context.text.bodyMedium!.copyWith(color: c.textSecondary, height: 1.55);
    final values =
        emphasizedValues
            .where((value) => value.isNotEmpty && message.contains(value))
            .toSet()
            .toList()
          ..sort((a, b) => b.length.compareTo(a.length));
    if (values.isEmpty) return Text(message, style: base);
    final pattern = RegExp(values.map(RegExp.escape).join('|'));
    final spans = <TextSpan>[];
    var start = 0;
    for (final match in pattern.allMatches(message)) {
      if (match.start > start) {
        spans.add(TextSpan(text: message.substring(start, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700),
        ),
      );
      start = match.end;
    }
    if (start < message.length) {
      spans.add(TextSpan(text: message.substring(start)));
    }
    return Text.rich(TextSpan(children: spans), style: base);
  }
}

/// The confirmation dialog behind [showConfirmDialog]. Destructive dialogs
/// show a red confirm button and the 「此操作无法撤销」 line.
class ConfirmDialog extends StatefulWidget {
  const ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = '取消',
    this.destructive = false,
    this.notice,
    this.emphasizedValues = const [],
    this.checkboxLabel,
    this.checkboxInitialValue = false,
    this.extraContent,
    super.key,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final String? notice;
  final List<String> emphasizedValues;
  final String? checkboxLabel;
  final bool checkboxInitialValue;
  final Widget? extraContent;

  /// Text of the irreversible-action line.
  static const irreversibleText = '此操作无法撤销';

  @override
  State<ConfirmDialog> createState() => _ConfirmDialogState();
}

/// Result of [showConfirmDialogWithCheckbox].
typedef ConfirmResult = ({bool confirmed, bool checked});

class _ConfirmDialogState extends State<ConfirmDialog> {
  late bool _checked = widget.checkboxInitialValue;

  void _close(bool confirmed) {
    final ConfirmResult result = (confirmed: confirmed, checked: _checked);
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return MiriaDialog(
      title: widget.title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EmphasizedMessage(
            widget.message,
            emphasizedValues: widget.emphasizedValues,
          ),
          if (widget.extraContent != null) ...[
            const SizedBox(height: Space.x3),
            widget.extraContent!,
          ],
          if (widget.checkboxLabel != null) ...[
            const SizedBox(height: Space.x2),
            MergeSemantics(
              child: InkWell(
                borderRadius: Radii.smAll,
                onTap: () => setState(() => _checked = !_checked),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _checked,
                        onChanged: (value) =>
                            setState(() => _checked = value ?? false),
                      ),
                      Expanded(
                        child: Text(
                          widget.checkboxLabel!,
                          style: text.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (widget.notice != null && !widget.destructive) ...[
            const SizedBox(height: Space.x4),
            _NoticeBox(
              icon: Symbols.info_rounded,
              text: widget.notice!,
              background: c.primaryContainer.withValues(alpha: 0.6),
              foreground: c.onPrimaryContainer,
            ),
          ],
          if (widget.destructive) ...[
            if (widget.notice != null) ...[
              const SizedBox(height: Space.x3),
              _NoticeBox(
                icon: Symbols.info_rounded,
                text: widget.notice!,
                background: c.surfaceMuted,
                foreground: c.textSecondary,
              ),
            ],
            const SizedBox(height: Space.x3 + 2),
            _NoticeBox(
              icon: Symbols.warning_rounded,
              text: ConfirmDialog.irreversibleText,
              background: c.dangerContainer,
              foreground: c.danger,
              bold: true,
            ),
          ],
        ],
      ),
      actions: DialogActionRow(
        cancelLabel: widget.cancelLabel,
        confirmLabel: widget.confirmLabel,
        destructive: widget.destructive,
        autofocusConfirm: !widget.destructive,
        onCancel: () => _close(false),
        onConfirm: () => _close(true),
      ),
    );
  }
}

class _NoticeBox extends StatelessWidget {
  const _NoticeBox({
    required this.icon,
    required this.text,
    required this.background,
    required this.foreground,
    this.bold = false,
  });

  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: background, borderRadius: Radii.smAll),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground, fill: 1),
          const SizedBox(width: Space.x2),
          Expanded(
            child: Text(
              text,
              style: context.text.bodySmall?.copyWith(
                color: foreground,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks for confirmation; true when confirmed (DESIGN §5.4 `dialog`).
///
/// [destructive] shows a red confirm button and the 「此操作无法撤销」 line.
/// [emphasizedValues] are bolded inside [message]; [notice] is an extra
/// hint box.
///
/// ```dart
/// final ok = await showConfirmDialog(
///   context,
///   title: '删除计划',
///   message: '确定删除「京都之旅」吗？',
///   confirmLabel: '删除',
///   destructive: true,
///   emphasizedValues: const ['京都之旅'],
/// );
/// ```
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = '取消',
  bool destructive = false,
  String? notice,
  List<String> emphasizedValues = const [],
  Widget? extraContent,
}) async {
  final result = await showDialog<ConfirmResult>(
    context: context,
    builder: (_) => ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      notice: notice,
      emphasizedValues: emphasizedValues,
      extraContent: extraContent,
    ),
  );
  return result?.confirmed ?? false;
}

/// [showConfirmDialog] with a checkbox (e.g. 「同时删除照片文件」). Returns
/// whether it was confirmed and the checkbox value.
Future<ConfirmResult> showConfirmDialogWithCheckbox(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String checkboxLabel,
  bool checkboxInitialValue = false,
  String cancelLabel = '取消',
  bool destructive = false,
  String? notice,
  List<String> emphasizedValues = const [],
}) async {
  final result = await showDialog<ConfirmResult>(
    context: context,
    builder: (_) => ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      notice: notice,
      emphasizedValues: emphasizedValues,
      checkboxLabel: checkboxLabel,
      checkboxInitialValue: checkboxInitialValue,
    ),
  );
  return result ?? (confirmed: false, checked: checkboxInitialValue);
}

/// Single-field input dialog. Returns the entered text (trimmed when
/// [trim]) or null when cancelled. [validator] returns an error message or
/// null; it runs on confirm and the error clears while typing.
///
/// ```dart
/// final name = await showInputDialog(
///   context,
///   title: '重命名片区',
///   label: '片区名称',
///   initialValue: group.name,
///   confirmLabel: '保存',
///   validator: (v) => v.trim().isEmpty ? '请输入片区名称' : null,
/// );
/// ```
Future<String?> showInputDialog(
  BuildContext context, {
  required String title,
  String? label,
  String? hint,
  String? helper,
  String initialValue = '',
  String confirmLabel = '确定',
  String cancelLabel = '取消',
  String? Function(String value)? validator,
  TextInputType? keyboardType,
  int maxLines = 1,
  int? maxLength,
  bool trim = true,
  bool showPasteButton = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _InputDialog(
      title: title,
      label: label,
      hint: hint,
      helper: helper,
      initialValue: initialValue,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      trim: trim,
      showPasteButton: showPasteButton,
    ),
  );
}

class _InputDialog extends StatefulWidget {
  const _InputDialog({
    required this.title,
    required this.label,
    required this.hint,
    required this.helper,
    required this.initialValue,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.validator,
    required this.keyboardType,
    required this.maxLines,
    required this.maxLength,
    required this.trim,
    required this.showPasteButton,
  });

  final String title;
  final String? label;
  final String? hint;
  final String? helper;
  final String initialValue;
  final String confirmLabel;
  final String cancelLabel;
  final String? Function(String value)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final bool trim;
  final bool showPasteButton;

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initialValue.length,
        );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text;
    final value = widget.trim ? raw.trim() : raw;
    final error = widget.validator?.call(value);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(value);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || !mounted) return;
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return MiriaDialog(
      title: widget.title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.label != null || widget.showPasteButton)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.x2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.label ?? '',
                      style: text.labelMedium?.copyWith(color: c.textSecondary),
                    ),
                  ),
                  if (widget.showPasteButton)
                    MiriaButton.ghost(
                      label: '粘贴',
                      icon: Symbols.content_paste_rounded,
                      size: MiriaButtonSize.sm,
                      onPressed: _paste,
                    ),
                ],
              ),
            ),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: widget.keyboardType,
            maxLines: widget.maxLines,
            minLines: 1,
            maxLength: widget.maxLength,
            textInputAction: widget.maxLines == 1
                ? TextInputAction.done
                : TextInputAction.newline,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: widget.maxLines == 1 ? (_) => _submit() : null,
            decoration: InputDecoration(
              hintText: widget.hint,
              helperText: widget.helper,
              errorText: _error,
              errorMaxLines: 3,
              helperMaxLines: 3,
            ),
          ),
        ],
      ),
      actions: DialogActionRow(
        cancelLabel: widget.cancelLabel,
        confirmLabel: widget.confirmLabel,
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _submit,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Panel
// ---------------------------------------------------------------------------

/// Large editor panel (DESIGN §5.4 `panel`, e.g. comparison export):
/// a full-height sheet on compact windows, a large dialog (up to
/// [maxWidth] 960) otherwise.
///
/// [builder] receives bounded height; manage scrolling inside (e.g. with
/// [EditorLayout] or a `ListView`). With [dismissible] false the barrier,
/// drag and back gesture do not close it — close with
/// `Navigator.pop(context, result)`.
///
/// ```dart
/// await showAdaptivePanel<void>(
///   context,
///   title: '导出对比图',
///   actions: [MiriaButton(label: '导出', onPressed: export)],
///   builder: (context) => const ComparisonExportSettingsPanel(),
/// );
/// ```
Future<T?> showAdaptivePanel<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  required String title,
  List<Widget> actions = const [],
  bool dismissible = true,
  double maxWidth = 960,
  bool useRootNavigator = true,
}) {
  if (context.layout.isCompact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: useRootNavigator,
      isDismissible: dismissible,
      enableDrag: dismissible,
      showDragHandle: false,
      builder: (sheetContext) => PopScope(
        canPop: dismissible,
        child: _PanelBody(
          title: title,
          actions: actions,
          dismissible: dismissible,
          sheet: true,
          child: Builder(builder: builder),
        ),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: dismissible,
    builder: (dialogContext) {
      final size = MediaQuery.sizeOf(dialogContext);
      return PopScope(
        canPop: dismissible,
        child: Dialog(
          insetPadding: const EdgeInsets.all(Space.x6),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: math.min(maxWidth, size.width - 48),
            height: math.min(880, size.height - 48),
            child: _PanelBody(
              title: title,
              actions: actions,
              dismissible: dismissible,
              sheet: false,
              child: Builder(builder: builder),
            ),
          ),
        ),
      );
    },
  );
}

class _PanelBody extends StatelessWidget {
  const _PanelBody({
    required this.title,
    required this.actions,
    required this.dismissible,
    required this.sheet,
    required this.child,
  });

  final String title;
  final List<Widget> actions;
  final bool dismissible;
  final bool sheet;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: sheet ? media.viewInsets.bottom : 0),
      child: SizedBox(
        height: sheet ? media.size.height : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sheet && dismissible) const SheetHandle(),
            _Header(
              title: title,
              actions: actions,
              leadingClose: true,
              onClose: dismissible ? () => Navigator.of(context).pop() : null,
            ),
            Divider(height: 1, color: c.hairline),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: child,
              ),
            ),
            if (sheet) SizedBox(height: media.padding.bottom),
          ],
        ),
      ),
    );
  }
}

/// Runs [task] behind a non-dismissible progress dialog (DESIGN §6.9
/// "阻塞保存") and returns its result. Back navigation is blocked while it
/// runs.
///
/// ```dart
/// final saved = await showBlockingProgress(
///   context,
///   message: '正在保存记录…',
///   task: () => service.save(),
/// );
/// ```
Future<T> showBlockingProgress<T>(
  BuildContext context, {
  required Future<T> Function() task,
  String message = '请稍候…',
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  var open = true;
  unawaited(
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) =>
          PopScope(canPop: false, child: _BlockingCard(message: message)),
    ).then((_) => open = false),
  );
  try {
    return await task();
  } finally {
    if (open && navigator.mounted) navigator.pop();
  }
}

class _BlockingCard extends StatelessWidget {
  const _BlockingCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Semantics(
        liveRegion: true,
        label: message,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          margin: const EdgeInsets.all(Space.x6),
          padding: const EdgeInsets.symmetric(
            horizontal: Space.x6,
            vertical: Space.x5,
          ),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: Radii.lgAll,
            boxShadow: Elevations.level3(c),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: c.primary,
                ),
              ),
              const SizedBox(height: Space.x4),
              Text(
                message,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Covers [child] with a translucent scrim, a spinner and [message] while
/// [busy]; blocks input and back navigation underneath. Inline alternative
/// to [showBlockingProgress] for pages that own the busy state.
class BlockingProgress extends StatelessWidget {
  const BlockingProgress({
    required this.busy,
    required this.child,
    this.message = '请稍候…',
    super.key,
  });

  final bool busy;
  final Widget child;
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PopScope(
      canPop: !busy,
      child: Stack(
        children: [
          AbsorbPointer(absorbing: busy, child: child),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !busy,
              child: AnimatedOpacity(
                opacity: busy ? 1 : 0,
                duration: Motion.of(context, Motion.standard),
                child: busy
                    ? ColoredBox(
                        color: c.scrim,
                        child: _BlockingCard(message: message),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
