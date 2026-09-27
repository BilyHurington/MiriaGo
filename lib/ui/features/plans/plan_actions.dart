import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/plans_store.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../app/router.dart';
import '../../app/toast.dart';
import '../../components/components.dart';

/// Plan library actions shared by the overview 「⋯」 menu, the plan
/// switcher and the plan library page. Logic and strings from the old
/// `PlanManagerScreen`.

void _toast(BuildContext context, String title, ToastKind kind) {
  context.read<ToastController>().show(ToastData(kind: kind, title: title));
}

/// Result of [showPlanInfoDialog].
typedef PlanInfo = ({String name, String area});

/// The 「计划名称 + 地区 / 区域」 dialog, used for 编辑计划信息 and 新建计划.
Future<PlanInfo?> showPlanInfoDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initialName = '',
  String initialArea = '',
  String? areaHint,
}) {
  return showDialog<PlanInfo>(
    context: context,
    useRootNavigator: true,
    builder: (_) => _PlanInfoDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialName: initialName,
      initialArea: initialArea,
      areaHint: areaHint,
    ),
  );
}

/// Switches the active plan; shows 「切换计划失败，请稍后重试。」 on failure.
Future<bool> switchToPlan(BuildContext context, String planId) async {
  final store = context.read<PlansStore>();
  final toasts = context.read<ToastController>();
  try {
    await store.switchTo(planId);
    return true;
  } catch (_) {
    toasts.show(ToastData(kind: ToastKind.error, title: '切换计划失败，请稍后重试。'));
    return false;
  }
}

/// 「新建计划」: asks for a name (prefilled 「新巡礼计划 N」) and an area,
/// then creates the plan and makes it active (DESIGN §10 Δ4).
Future<PilgrimagePlan?> createPlanWithDialog(BuildContext context) async {
  final store = context.read<PlansStore>();
  final toasts = context.read<ToastController>();
  if (store.plans.isEmpty) await store.refresh();
  if (!context.mounted) return null;
  final info = await showPlanInfoDialog(
    context,
    title: '新建计划',
    confirmLabel: '创建',
    initialName: store.suggestedNewPlanName(),
    areaHint: '未设置区域',
  );
  if (info == null) return null;
  final name = info.name.isEmpty ? store.suggestedNewPlanName() : info.name;
  try {
    return await store.create(name: name, area: info.area);
  } catch (_) {
    toasts.show(ToastData(kind: ToastKind.error, title: '新建计划失败，请稍后重试。'));
    return null;
  }
}

/// 「编辑计划信息」. An empty name is ignored; an empty area is stored as
/// 「未设置区域」; unchanged values are not written.
Future<void> editPlanInfo(BuildContext context, PilgrimagePlan plan) async {
  final store = context.read<PlansStore>();
  final toasts = context.read<ToastController>();
  final info = await showPlanInfoDialog(
    context,
    title: '编辑计划信息',
    confirmLabel: '保存',
    initialName: plan.name,
    initialArea: plan.area,
  );
  if (info == null || info.name.isEmpty) return;
  final area = info.area.isEmpty ? '未设置区域' : info.area;
  if (info.name == plan.name && area == plan.area) return;
  try {
    await store.updateInfo(planId: plan.id, name: info.name, area: area);
  } catch (_) {
    toasts.show(ToastData(kind: ToastKind.error, title: '计划信息保存失败，请稍后重试。'));
  }
}

/// 「复制计划」 as 「{name} 副本」 including its visit records.
Future<void> duplicatePlan(BuildContext context, PilgrimagePlan plan) async {
  final store = context.read<PlansStore>();
  final toasts = context.read<ToastController>();
  try {
    final copy = await store.duplicate(plan);
    toasts.show(ToastData(kind: ToastKind.success, title: '已复制「${copy.name}」'));
  } catch (_) {
    toasts.show(ToastData(kind: ToastKind.error, title: '复制计划失败，请稍后重试。'));
  }
}

/// 「删除计划」 with the old destructive confirmation. At least one plan must
/// remain (「至少需要保留一个计划」).
Future<bool> deletePlan(BuildContext context, PilgrimagePlan plan) async {
  final store = context.read<PlansStore>();
  final toasts = context.read<ToastController>();
  if (store.plans.isEmpty) await store.refresh();
  if (!context.mounted) return false;
  if (!store.canDelete) {
    _toast(context, '至少需要保留一个计划', ToastKind.warning);
    return false;
  }
  final confirmed = await showConfirmDialog(
    context,
    title: '删除计划',
    message:
        '将删除「${plan.name}」及其中的点位、片区、作品和巡礼记录。'
        '只属于这个计划的巡礼照片、调色图和参考图文件也会一并删除；'
        '其他计划或记录仍在使用的文件会保留。',
    confirmLabel: '删除',
    destructive: true,
    emphasizedValues: [plan.name],
  );
  if (!confirmed) return false;
  try {
    await store.delete(plan);
    return true;
  } catch (_) {
    toasts.show(ToastData(kind: ToastKind.error, title: '删除计划失败，请稍后重试。'));
    return false;
  }
}

/// Opens 导入导出 for [plan], switching to it first when needed.
Future<void> openPlanTransfer(BuildContext context, PilgrimagePlan plan) async {
  final store = context.read<PlansStore>();
  if (store.activePlanId != plan.id) {
    final switched = await switchToPlan(context, plan.id);
    if (!switched || !context.mounted) return;
  }
  context.go(Routes.transfer);
}

/// The per-plan menu (编辑计划信息 / 复制计划 / 导入导出 / 删除计划).
List<MenuAction> planMenuActions(
  BuildContext context,
  PilgrimagePlan plan, {
  bool includeEdit = true,
}) {
  final canDelete = context.read<PlansStore>().canDelete;
  return [
    if (includeEdit)
      MenuAction(
        label: '编辑计划信息',
        icon: Symbols.edit_rounded,
        onSelected: () => unawaited(editPlanInfo(context, plan)),
      ),
    MenuAction(
      label: '复制计划',
      icon: Symbols.content_copy_rounded,
      onSelected: () => unawaited(duplicatePlan(context, plan)),
    ),
    MenuAction(
      label: '导入导出',
      icon: Symbols.swap_vert_rounded,
      onSelected: () => unawaited(openPlanTransfer(context, plan)),
    ),
    MenuAction(
      label: '删除计划',
      icon: Symbols.delete_rounded,
      destructive: true,
      subtitle: canDelete ? null : '至少需要保留一个计划',
      onSelected: () => unawaited(deletePlan(context, plan)),
    ),
  ];
}

class _PlanInfoDialog extends StatefulWidget {
  const _PlanInfoDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialName,
    required this.initialArea,
    required this.areaHint,
  });

  final String title;
  final String confirmLabel;
  final String initialName;
  final String initialArea;
  final String? areaHint;

  @override
  State<_PlanInfoDialog> createState() => _PlanInfoDialogState();
}

class _PlanInfoDialogState extends State<_PlanInfoDialog> {
  // The dialog owns its controllers so they outlive its exit animation.
  late final _name = TextEditingController(text: widget.initialName)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initialName.length,
    );
  late final _area = TextEditingController(text: widget.initialArea);

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(
      context,
    ).pop<PlanInfo>((name: _name.text.trim(), area: _area.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return MiriaDialog(
      title: widget.title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MiriaTextField(
            key: const ValueKey('plan-info-name'),
            label: '计划名称',
            controller: _name,
            autofocus: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: Space.x4),
          MiriaTextField(
            key: const ValueKey('plan-info-area'),
            label: '地区 / 区域',
            hint: widget.areaHint,
            controller: _area,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: DialogActionRow(
        confirmLabel: widget.confirmLabel,
        onConfirm: _submit,
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }
}
