import 'package:flutter/widgets.dart';

import '../../plan/plan_memo_markdown.dart';
import '../plan_session.dart';
import 'memo_editing.dart';

/// Outcome of [PlanMemoEditor.save].
enum MemoSaveResult {
  /// Nothing happened (a save was already running).
  ignored,

  /// 「计划备忘录已保存」.
  saved,

  /// The user kept typing while saving: 「已保存，后续输入仍待保存」.
  savedWithPendingInput,

  /// 「计划备忘录保存失败」.
  failed,
}

/// Outcome of [PlanMemoEditor.toggleTask].
enum MemoToggleResult { ignored, saved, failed }

/// State and save logic of the plan memo page, ported from the old
/// `PlanMemoScreen` (view/edit modes, immediate task toggling with
/// rollback, "keep typing while saving", external memo sync).
///
/// The saved memo is always read from the [PlanSession], never cached.
class PlanMemoEditor extends ChangeNotifier {
  PlanMemoEditor({required this.session})
    : _planId = session.isReady ? session.plan.id : null {
    text = TextEditingController(text: savedMemo)..addListener(_onTextChanged);
    session.addListener(_onSessionChanged);
  }

  final PlanSession session;
  late final TextEditingController text;

  String? _planId;
  bool _editing = false;
  bool _saving = false;
  bool _togglingTask = false;
  bool _updatingText = false;
  bool _disposed = false;

  String get savedMemo => session.isReady ? session.plan.memo : '';

  bool get isEditing => _editing;
  bool get isSaving => _saving;
  bool get isTogglingTask => _togglingTask;
  bool get isBusy => _saving || _togglingTask;
  bool get hasUnsavedChanges => text.text != savedMemo;

  /// Whether the page may be left without asking (old `PopScope.canPop`).
  bool get canLeaveFreely => !isBusy && (!_editing || !hasUnsavedChanges);

  /// Whether leaving needs the 「放弃未保存内容？」 confirmation.
  bool get needsDiscardConfirmation => _editing && hasUnsavedChanges;

  void startEditing() {
    if (_togglingTask) return;
    _editing = true;
    _notify();
  }

  /// Leaves edit mode and restores the saved memo.
  void discardChanges() {
    _editing = false;
    _setText(savedMemo);
    _notify();
  }

  /// Saves the editor text. Typing during the save keeps edit mode on.
  Future<MemoSaveResult> save() async {
    if (_saving) return MemoSaveResult.ignored;
    final savedText = text.text;
    _saving = true;
    _notify();
    try {
      await session.controller.updatePlanMemo(savedText);
      if (_disposed) return MemoSaveResult.saved;
      _editing = text.text != savedText;
      return _editing
          ? MemoSaveResult.savedWithPendingInput
          : MemoSaveResult.saved;
    } catch (_) {
      return MemoSaveResult.failed;
    } finally {
      _saving = false;
      _notify();
    }
  }

  /// Toggles the [taskIndex]-th rendered task checkbox and saves at once;
  /// rolls back on failure (「待办状态保存失败」).
  Future<MemoToggleResult> toggleTask(int taskIndex) async {
    if (_togglingTask || _editing) return MemoToggleResult.ignored;
    final current = savedMemo;
    final toggled = toggleMemoMarkdownTask(current, taskIndex);
    if (toggled == current) return MemoToggleResult.ignored;
    _togglingTask = true;
    _setText(toggled);
    _notify();
    try {
      await session.controller.updatePlanMemo(toggled);
      return MemoToggleResult.saved;
    } catch (_) {
      if (!_disposed) _setText(current);
      return MemoToggleResult.failed;
    } finally {
      _togglingTask = false;
      _notify();
    }
  }

  /// Applies a toolbar action to the editor.
  void apply(MemoMarkdownAction action) {
    text.value = applyMemoMarkdownAction(text.value, action);
  }

  void _setText(String value) {
    _updatingText = true;
    text.text = value;
    _updatingText = false;
  }

  void _onTextChanged() {
    if (_editing && !_updatingText) _notify();
  }

  void _onSessionChanged() {
    if (!session.isReady) return;
    final planId = session.plan.id;
    if (planId != _planId) {
      // Another plan became active: never carry an unsaved draft over.
      _planId = planId;
      _editing = false;
      _setText(savedMemo);
      _notify();
      return;
    }
    if (_editing || _togglingTask || text.text == savedMemo) return;
    _setText(savedMemo);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    session.removeListener(_onSessionChanged);
    text
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }
}
