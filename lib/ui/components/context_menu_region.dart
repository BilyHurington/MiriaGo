import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../layout/adaptive_modal.dart';

/// Opens the same [actions] on long press (touch) and secondary click
/// (mouse / trackpad) — DESIGN §5.5 "右键菜单与长按菜单内容相同".
///
/// On pointer input the menu pops up at the click position; on touch it is
/// a bottom action list. Screen readers get each action as a custom
/// semantics action.
///
/// ```dart
/// ContextMenuRegion(
///   actions: [
///     MenuAction(label: '重命名', icon: Symbols.edit_rounded, onSelected: rename),
///     MenuAction(label: '删除', icon: Symbols.delete_rounded, destructive: true, onSelected: delete),
///   ],
///   child: WorkCard(work),
/// )
/// ```
///
/// [ListRow] and [MiriaCard] have this built in (`contextActions` /
/// `onContextMenu`); wrap other widgets with this.
class ContextMenuRegion extends StatelessWidget {
  const ContextMenuRegion({
    required this.actions,
    required this.child,
    this.title,
    this.enabled = true,
    this.longPress = true,
    super.key,
  });

  final List<MenuAction> actions;
  final Widget child;

  /// Optional menu title (e.g. the item name).
  final String? title;
  final bool enabled;

  /// Also open on long press (set false when long press starts
  /// multi-select).
  final bool longPress;

  @override
  Widget build(BuildContext context) {
    if (!enabled || actions.isEmpty) return child;
    void open(Offset position) => showActionMenu(
      context,
      actions: actions,
      title: title,
      position: position,
    );
    return Semantics(
      customSemanticsActions: {
        for (final action in actions.where((a) => a.enabled))
          CustomSemanticsAction(label: action.label): action.onSelected,
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapUp: (details) => open(details.globalPosition),
        onLongPressStart: longPress
            ? (details) => open(details.globalPosition)
            : null,
        child: child,
      ),
    );
  }
}
