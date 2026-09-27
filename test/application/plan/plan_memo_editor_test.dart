import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/application/plan/plan_memo_editor.dart';
import 'package:miriago/application/plan_session.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

/// Sample repository whose memo writes can fail or be held.
class _MemoRepository extends SamplePilgrimageRepository {
  bool fail = false;
  Completer<void>? gate;

  @override
  Future<PilgrimagePlan> updatePlanMemo({
    required String planId,
    required String memo,
  }) async {
    await gate?.future;
    if (fail) throw StateError('write failed');
    return super.updatePlanMemo(planId: planId, memo: memo);
  }
}

Future<(PlanSession, _MemoRepository)> _session() async {
  final repository = _MemoRepository();
  final session = PlanSession(repository: repository);
  await session.load();
  return (session, repository);
}

void main() {
  test('save writes the memo and leaves edit mode', () async {
    final (session, _) = await _session();
    final editor = PlanMemoEditor(session: session);
    editor.startEditing();
    editor.text.text = '- [ ] 买票';
    expect(editor.hasUnsavedChanges, isTrue);
    expect(editor.canLeaveFreely, isFalse);
    expect(await editor.save(), MemoSaveResult.saved);
    expect(session.plan.memo, '- [ ] 买票');
    expect(editor.isEditing, isFalse);
    expect(editor.canLeaveFreely, isTrue);
    editor.dispose();
  });

  test('typing during a save keeps edit mode with pending input', () async {
    final (session, repository) = await _session();
    final editor = PlanMemoEditor(session: session);
    editor.startEditing();
    editor.text.text = 'a';
    repository.gate = Completer<void>();
    final saving = editor.save();
    expect(editor.isSaving, isTrue);
    expect(editor.canLeaveFreely, isFalse);
    expect(await editor.save(), MemoSaveResult.ignored);
    editor.text.text = 'ab';
    repository.gate!.complete();
    expect(await saving, MemoSaveResult.savedWithPendingInput);
    expect(session.plan.memo, 'a');
    expect(editor.isEditing, isTrue);
    expect(editor.text.text, 'ab');
    editor.dispose();
  });

  test('failed save keeps the draft', () async {
    final (session, repository) = await _session();
    final editor = PlanMemoEditor(session: session);
    editor.startEditing();
    editor.text.text = 'draft';
    repository.fail = true;
    expect(await editor.save(), MemoSaveResult.failed);
    expect(editor.isEditing, isTrue);
    expect(editor.text.text, 'draft');
    expect(editor.isSaving, isFalse);
    editor.dispose();
  });

  test('toggling a task saves at once and rolls back on failure', () async {
    final (session, repository) = await _session();
    await session.controller.updatePlanMemo('- [ ] a\n- [ ] b');
    final editor = PlanMemoEditor(session: session);
    expect(await editor.toggleTask(1), MemoToggleResult.saved);
    expect(session.plan.memo, '- [ ] a\n- [x] b');
    repository.fail = true;
    expect(await editor.toggleTask(0), MemoToggleResult.failed);
    expect(session.plan.memo, '- [ ] a\n- [x] b');
    expect(editor.text.text, '- [ ] a\n- [x] b');
    expect(await editor.toggleTask(9), MemoToggleResult.ignored);
    editor.startEditing();
    expect(await editor.toggleTask(0), MemoToggleResult.ignored);
    editor.dispose();
  });

  test('external memo changes sync only outside edit mode', () async {
    final (session, _) = await _session();
    final editor = PlanMemoEditor(session: session);
    await session.controller.updatePlanMemo('外部修改');
    expect(editor.text.text, '外部修改');
    editor.startEditing();
    editor.text.text = '我的草稿';
    await session.controller.updatePlanMemo('再次外部修改');
    expect(editor.text.text, '我的草稿');
    editor.discardChanges();
    expect(editor.text.text, '再次外部修改');
    expect(editor.isEditing, isFalse);
    editor.dispose();
  });

  test('switching plans drops the draft of the previous plan', () async {
    final (session, repository) = await _session();
    final editor = PlanMemoEditor(session: session);
    editor.startEditing();
    editor.text.text = '草稿';
    final other = await repository.createPlan(name: '其他', area: '京都');
    await repository.setActivePlan(other.id);
    await session.load();
    expect(editor.isEditing, isFalse);
    expect(editor.text.text, '');
    editor.dispose();
  });
}
