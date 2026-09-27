import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../application/plan/memo_editing.dart';
import '../../../application/plan/plan_memo_editor.dart';
import '../../../application/plan_session.dart';
import '../../app/toast.dart';
import '../../components/components.dart';
import '../plan/plan_workspace.dart';
import 'memo_markdown_view.dart';

/// Width from which the editor shows a live preview beside it.
const double _sideBySideMinWidth = 720;

/// 计划备忘录 (`/plan/memo`, DESIGN §8.13). Ported from the old
/// `PlanMemoScreen`; state and save logic live in [PlanMemoEditor].
class MemoPage extends StatefulWidget {
  const MemoPage({super.key});

  @override
  State<MemoPage> createState() => _MemoPageState();
}

class _MemoPageState extends State<MemoPage> {
  late final PlanMemoEditor _editor;
  PlanWorkspaceScope? _scope;

  @override
  void initState() {
    super.initState();
    _editor = PlanMemoEditor(session: context.read<PlanSession>());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = PlanWorkspaceScope.maybeOf(context);
    if (!identical(scope, _scope)) {
      _scope?.removeLeaveGuard(_leaveGuard);
      _scope = scope?..addLeaveGuard(_leaveGuard);
    }
  }

  @override
  void dispose() {
    _scope?.removeLeaveGuard(_leaveGuard);
    _editor.dispose();
    super.dispose();
  }

  void _toast(String title, ToastKind kind) {
    context.read<ToastController>().show(ToastData(kind: kind, title: title));
  }

  /// Whether the page may be left; asks to discard unsaved changes.
  Future<bool> _leaveGuard() async {
    if (_editor.isBusy) {
      _toast('正在保存备忘录，请稍候', ToastKind.running);
      return false;
    }
    if (!_editor.needsDiscardConfirmation) return true;
    final discard = await showConfirmDialog(
      context,
      title: '放弃未保存内容？',
      message: '当前备忘录还有未保存的修改。',
      confirmLabel: '放弃',
      cancelLabel: '继续编辑',
      notice: '未保存的修改不会被保留',
      emphasizedValues: const ['未保存的修改'],
    );
    if (discard && mounted) _editor.discardChanges();
    return discard;
  }

  Future<void> _handleBack() async {
    if (!await _leaveGuard() || !mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _save() async {
    final result = await _editor.save();
    if (!mounted) return;
    switch (result) {
      case MemoSaveResult.ignored:
        return;
      case MemoSaveResult.saved:
        _toast('计划备忘录已保存', ToastKind.success);
      case MemoSaveResult.savedWithPendingInput:
        _toast('已保存，后续输入仍待保存', ToastKind.success);
      case MemoSaveResult.failed:
        _toast('计划备忘录保存失败', ToastKind.error);
    }
  }

  Future<void> _toggleTask(int index) async {
    final result = await _editor.toggleTask(index);
    if (mounted && result == MemoToggleResult.failed) {
      _toast('待办状态保存失败', ToastKind.error);
    }
  }

  Future<void> _openLink(String? href) async {
    if (href == null || href.trim().isEmpty) return;
    final uri = Uri.tryParse(href.trim());
    if (uri == null || !uri.hasScheme) {
      _toast('链接格式不正确', ToastKind.warning);
      return;
    }
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!mounted || opened) return;
    _toast('无法打开链接', ToastKind.error);
  }

  @override
  Widget build(BuildContext context) {
    final hasNav = PlanWorkspaceScope.hasSecondaryNav(context);
    return ListenableBuilder(
      listenable: _editor,
      builder: (context, _) {
        final editing = _editor.isEditing;
        final saving = _editor.isSaving;
        return PopScope(
          canPop: _editor.canLeaveFreely,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_handleBack());
          },
          child: MiriaPageScaffold(
            title: '计划备忘录',
            automaticallyImplyLeading: !hasNav,
            actions: [
              if (editing)
                MiriaButton(
                  key: const ValueKey('memo-save'),
                  label: '保存',
                  icon: Symbols.save_rounded,
                  size: MiriaButtonSize.sm,
                  loading: saving,
                  onPressed: saving ? null : () => unawaited(_save()),
                )
              else
                MiriaIconButton(
                  key: const ValueKey('memo-edit'),
                  icon: Symbols.edit_rounded,
                  tooltip: '编辑',
                  onPressed: _editor.isTogglingTask
                      ? null
                      : _editor.startEditing,
                ),
            ],
            body: SafeArea(
              top: false,
              child: editing ? _buildEditor(context) : _buildReader(context),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReader(BuildContext context) {
    final memo = _editor.savedMemo;
    if (memo.trim().isEmpty) {
      return _EmptyMemo(onStart: _editor.startEditing);
    }
    return SingleChildScrollView(
      key: const ValueKey('memo-reader'),
      child: ContentColumn(
        padding: const EdgeInsets.fromLTRB(0, Space.x3, 0, Space.x8),
        child: SizedBox(
          width: double.infinity,
          child: MemoMarkdownView(
            data: memo,
            onTapLink: (href) => unawaited(_openLink(href)),
            onToggleTask: (index) => unawaited(_toggleTask(index)),
          ),
        ),
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    final gutter = context.layout.gutter;
    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
          unawaited(_save()),
      const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () =>
          unawaited(_save()),
    };
    return CallbackShortcuts(
      bindings: shortcuts,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sideBySide = constraints.maxWidth >= _sideBySideMinWidth;
          final editor = Padding(
            padding: EdgeInsets.fromLTRB(gutter, Space.x3, gutter, Space.x4),
            child: TextFieldTapRegion(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MarkdownToolbar(onAction: _editor.apply),
                  const SizedBox(height: Space.x3),
                  Text('备忘录内容', style: context.text.titleSmall),
                  const SizedBox(height: Space.x2),
                  Expanded(child: _MemoTextField(controller: _editor.text)),
                ],
              ),
            ),
          );
          if (!sideBySide) return editor;
          final c = context.colors;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: editor),
              VerticalDivider(width: 1, thickness: 1, color: c.hairline),
              Expanded(
                child: ColoredBox(
                  color: c.surface,
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _editor.text,
                    builder: (context, value, _) => _LivePreview(
                      text: value.text,
                      onTapLink: (href) => unawaited(_openLink(href)),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MemoTextField extends StatelessWidget {
  const _MemoTextField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return TextField(
      key: const ValueKey('plan-memo-editor'),
      controller: controller,
      autofocus: true,
      expands: true,
      maxLines: null,
      minLines: null,
      keyboardType: TextInputType.multiline,
      textAlignVertical: TextAlignVertical.top,
      style: text.bodyLarge?.copyWith(color: c.textPrimary, height: 1.5),
      decoration: InputDecoration(
        hintText: '可以记录交通、预约、补拍事项、同行安排等。',
        hintStyle: text.bodyMedium?.copyWith(
          color: c.textTertiary,
          height: 1.5,
        ),
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.all(Space.x4),
        border: OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: c.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: c.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.text, required this.onTapLink});

  final String text;
  final ValueChanged<String?> onTapLink;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final gutter = context.layout.gutter;
    return SingleChildScrollView(
      key: const ValueKey('memo-live-preview'),
      padding: EdgeInsets.fromLTRB(gutter, Space.x4, gutter, Space.x8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '预览',
            style: context.text.labelMedium?.copyWith(color: c.textTertiary),
          ),
          const SizedBox(height: Space.x3),
          if (text.trim().isEmpty)
            Text(
              '还没有计划备忘',
              style: context.text.bodyMedium?.copyWith(color: c.textTertiary),
            )
          else
            MemoMarkdownView(data: text, onTapLink: onTapLink),
        ],
      ),
    );
  }
}

class _MarkdownToolbar extends StatelessWidget {
  const _MarkdownToolbar({required this.onAction});

  final ValueChanged<MemoMarkdownAction> onAction;

  static IconData _icon(MemoMarkdownAction action) => switch (action) {
    MemoMarkdownAction.heading => Symbols.title_rounded,
    MemoMarkdownAction.bold => Symbols.format_bold_rounded,
    MemoMarkdownAction.list => Symbols.format_list_bulleted_rounded,
    MemoMarkdownAction.task => Symbols.checklist_rounded,
    MemoMarkdownAction.quote => Symbols.format_quote_rounded,
    MemoMarkdownAction.divider => Symbols.horizontal_rule_rounded,
    MemoMarkdownAction.link => Symbols.link_rounded,
    MemoMarkdownAction.code => Symbols.code_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      key: const ValueKey('memo-toolbar'),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.hairline),
        borderRadius: Radii.smAll,
      ),
      padding: const EdgeInsets.all(2),
      child: Wrap(
        children: [
          for (final action in MemoMarkdownAction.values)
            MiriaIconButton(
              key: ValueKey('memo-tool-${action.name}'),
              icon: _icon(action),
              tooltip: action.label,
              compact: true,
              onPressed: () => onAction(action),
            ),
        ],
      ),
    );
  }
}

class _EmptyMemo extends StatelessWidget {
  const _EmptyMemo({required this.onStart});

  final VoidCallback onStart;

  static const _suggestions = [
    (icon: Symbols.train_rounded, label: '交通安排', detail: '如车次、换乘方案、出发时间等'),
    (icon: Symbols.hotel_rounded, label: '酒店预约', detail: '酒店地址、入住时间、联系方式等'),
    (
      icon: Symbols.confirmation_number_rounded,
      label: '活动门票',
      detail: '活动门票、预约时间、注意事项等',
    ),
    (
      icon: Symbols.photo_camera_rounded,
      label: '拍摄计划',
      detail: '拍摄地点、时间、天气备选方案等',
    ),
    (
      icon: Symbols.notifications_rounded,
      label: '注意事项',
      detail: '携带物品、预算、当地注意事项等',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return SingleChildScrollView(
      key: const ValueKey('memo-empty'),
      child: ContentColumn(
        maxWidth: 440,
        padding: const EdgeInsets.fromLTRB(0, Space.x5, 0, Space.x8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: c.primaryContainer,
                  borderRadius: Radii.lgAll,
                ),
                child: Icon(
                  Symbols.sticky_note_2_rounded,
                  size: 34,
                  color: c.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: Space.x4),
            Text(
              '还没有计划备忘',
              textAlign: TextAlign.center,
              style: text.titleMedium,
            ),
            const SizedBox(height: Space.x2),
            Text(
              '记录本次巡礼的重要事项',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: Space.x5),
            MiriaCard(
              color: c.surfaceMuted,
              padding: const EdgeInsets.fromLTRB(
                Space.x4,
                Space.x3,
                Space.x4,
                Space.x2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Symbols.lightbulb_rounded,
                        size: 18,
                        color: c.primary,
                      ),
                      const SizedBox(width: Space.x2),
                      Expanded(
                        child: Text(
                          '可记录内容',
                          style: text.labelLarge?.copyWith(
                            color: c.primaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.x1),
                  for (var i = 0; i < _suggestions.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, indent: 44, color: c.hairline),
                    _SuggestionItem(
                      icon: _suggestions[i].icon,
                      label: _suggestions[i].label,
                      detail: _suggestions[i].detail,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Space.x4),
            MiriaButton(
              key: const ValueKey('memo-start'),
              label: '开始记录',
              icon: Symbols.edit_note_rounded,
              size: MiriaButtonSize.lg,
              expand: true,
              onPressed: onStart,
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionItem extends StatelessWidget {
  const _SuggestionItem({
    required this.icon,
    required this.label,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.x2),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: c.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: c.onPrimaryContainer),
            ),
            const SizedBox(width: Space.x3 - 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: text.labelLarge),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: text.caption.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
