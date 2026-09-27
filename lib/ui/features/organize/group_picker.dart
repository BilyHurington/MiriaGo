import 'package:flutter/material.dart';

import '../../../plan/pilgrimage_models.dart';

/// Id used for the synthetic 「未分组 / 未分入片区」 bucket.
const String kUngroupedId = 'ungrouped';

/// Adaptive "choose a group" picker (radio list + 「新建片区」).
/// Returns a group id, [kUngroupedId], or null when cancelled.
/// OWNER: feature agent C (organize).
Future<String?> pickGroup(
  BuildContext context, {
  required String title,
  String? subtitle,
  String? selectedGroupId,
  bool includeUngrouped = true,
  bool allowCreate = true,
}) async => null;

/// The single 「新建片区」 dialog of the app (validates 「片区名不能为空」)
/// and creates the group through the PlanSession. Returns the new group,
/// or null when cancelled / failed (failure toast 「片区创建失败」 shown).
/// OWNER: feature agent C (organize).
Future<PilgrimagePlanGroup?> showCreateGroupDialog(
  BuildContext context,
) async => null;

/// Group chooser used by the 巡礼 header (片区选择器 with progress).
/// Returns a group id / [kUngroupedId] or null.
/// OWNER: feature agent C (organize).
Future<String?> showGroupSwitcherSheet(
  BuildContext context, {
  String? selectedGroupId,
  bool showProgress = true,
  bool emphasizeTotalCount = false,
}) async => null;
