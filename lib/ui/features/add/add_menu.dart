import 'package:flutter/material.dart';

/// Which part of the 添加 menu to show.
enum AddMenuSection { all, points, works }

/// Opens the adaptive 「添加到『计划』」 menu.
/// OWNER: feature agent D (add).
Future<void> showAddMenu(
  BuildContext context, {
  AddMenuSection section = AddMenuSection.all,
}) async {}

/// Opens the point form (create when [pointId] is null, otherwise edit).
/// Returns true when saved.
/// OWNER: feature agent D (add).
Future<bool> openPointEditor(BuildContext context, {String? pointId}) async =>
    false;
