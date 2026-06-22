import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_theme.dart';
import '../data/user_reference_image_stub.dart'
    if (dart.library.io) '../data/user_reference_image_io.dart';
import '../widgets/snackbar_helper.dart';
import '../map/map_navigation_launcher.dart';
import '../plan/pilgrimage_models.dart';
import '../records/visit_record_photo_stub.dart'
    if (dart.library.io) '../records/visit_record_photo_io.dart';
import '../widgets/copyable_text.dart';
import '../widgets/image_viewer_screen.dart';
import '../widgets/reference_thumbnail_stub.dart'
    if (dart.library.io) '../widgets/reference_thumbnail_io.dart';

enum PointDetailActionScope { visit, manage, assign }

class PointDetailSheet extends StatelessWidget {
  const PointDetailSheet({
    required this.point,
    required this.status,
    required this.onReplaceReference,
    this.onSetCurrent,
    this.onOpenCamera,
    this.onComplete,
    this.actionScope = PointDetailActionScope.visit,
    this.groups = const [],
    this.onMoveToGroup,
    this.records = const [],
    this.onOpenRecords,
    this.onOpenRecord,
    this.navigationLauncher = const MapNavigationLauncher(),
    super.key,
  });

  final PilgrimagePoint point;
  final VisitStatus status;
  final VoidCallback? onSetCurrent;
  final VoidCallback? onOpenCamera;
  final VoidCallback? onComplete;
  final Future<void> Function(
    PilgrimagePoint point,
    StoredUserReferenceImage image,
  )
  onReplaceReference;
  final PointDetailActionScope actionScope;
  final List<PilgrimagePlanGroup> groups;
  final Future<void> Function(PilgrimagePoint point, String? groupId)?
  onMoveToGroup;
  final List<PilgrimageVisitRecord> records;
  final VoidCallback? onOpenRecords;
  final ValueChanged<PilgrimageVisitRecord>? onOpenRecord;
  final MapNavigationLauncher navigationLauncher;

  static Future<void> show(
    BuildContext context, {
    required PilgrimagePoint point,
    required VisitStatus status,
    required Future<void> Function(
      PilgrimagePoint point,
      StoredUserReferenceImage image,
    )
    onReplaceReference,
    VoidCallback? onSetCurrent,
    VoidCallback? onOpenCamera,
    VoidCallback? onComplete,
    PointDetailActionScope actionScope = PointDetailActionScope.visit,
    List<PilgrimagePlanGroup> groups = const [],
    Future<void> Function(PilgrimagePoint point, String? groupId)?
    onMoveToGroup,
    List<PilgrimageVisitRecord> records = const [],
    VoidCallback? onOpenRecords,
    ValueChanged<PilgrimageVisitRecord>? onOpenRecord,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) {
        return PointDetailSheet(
          point: point,
          status: status,
          onSetCurrent: onSetCurrent,
          onOpenCamera: onOpenCamera,
          onComplete: onComplete,
          onReplaceReference: onReplaceReference,
          actionScope: actionScope,
          groups: groups,
          onMoveToGroup: onMoveToGroup,
          records: records,
          onOpenRecords: onOpenRecords,
          onOpenRecord: onOpenRecord,
        );
      },
    );
  }

  Future<void> _replaceReferenceImage(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !context.mounted) {
      return;
    }

    messenger.showReplacingSnackBar(
      const SnackBar(content: Text('正在替换参考图...')),
    );
    final stored = await storeUserReferenceImage(
      sourcePath: picked.path,
      pointId: point.id,
    );
    if (stored == null || !context.mounted) {
      messenger.showReplacingSnackBar(
        const SnackBar(content: Text('参考图替换失败，请稍后重试。')),
      );
      return;
    }

    await onReplaceReference(point, stored);
    if (!context.mounted) {
      return;
    }

    messenger.showReplacingSnackBar(const SnackBar(content: Text('已替换参考图')));
    navigator.pop();
  }

  Future<void> _openNavigation(BuildContext context) async {
    final opened = await navigationLauncher.openGoogleMapsWalking(point);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showReplacingSnackBar(
        const SnackBar(content: Text('无法打开 Google Maps。')),
      );
    }
  }

  Future<void> _showMoveGroupSheet(BuildContext context) async {
    final moveToGroup = onMoveToGroup;
    if (moveToGroup == null) {
      return;
    }

    final selectedGroupId = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (context) {
        return SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const Text(
                '移动到片区',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              _GroupOptionTile(
                title: '未分入片区',
                selected: point.groupId == null,
                onTap: () => Navigator.of(context).pop(''),
              ),
              for (final group in groups)
                _GroupOptionTile(
                  title: group.name,
                  selected: point.groupId == group.id,
                  onTap: () => Navigator.of(context).pop(group.id),
                ),
            ],
          ),
        );
      },
    );
    if (!context.mounted || selectedGroupId == null) {
      return;
    }

    final groupId = selectedGroupId.isEmpty ? null : selectedGroupId;
    await moveToGroup(point, groupId);
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.84;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: sheetHeight,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ReferenceColumn(
                      point: point,
                      status: status,
                      onReplace: () => _replaceReferenceImage(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StatusBadge(status: status),
                          const SizedBox(height: 8),
                          CopyableText(
                            text: point.name,
                            copyLabel: '点位名称',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${point.work.title} / ${point.subtitle}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.movie_filter_outlined,
                  label: '作品',
                  value: '${point.work.title} / ${point.work.subtitle}',
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.local_movies_outlined,
                  label: '场景',
                  value: point.displayEpisodeLabel,
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: '坐标',
                  value:
                      '${point.position.latitude.toStringAsFixed(5)}, ${point.position.longitude.toStringAsFixed(5)}',
                ),
                const SizedBox(height: 8),
                _GroupInfoRow(
                  groupName: _groupName,
                  anchorLabel: _groupAnchorLabel,
                  onMove: onMoveToGroup == null
                      ? null
                      : () => _showMoveGroupSheet(context),
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.image_outlined,
                  label: '参考',
                  value: point.referenceLabel,
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.source_outlined,
                  label: '来源',
                  value: _sourceText,
                ),
                if (point.sourceId != null) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.tag_outlined,
                    label: 'ID',
                    value: point.sourceId!,
                  ),
                ],
                if (point.sourceUrl != null) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.link_outlined,
                    label: '链接',
                    value: point.sourceUrl!,
                  ),
                ],
                if (point.note?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.sticky_note_2_outlined,
                    label: '备注',
                    value: point.note!,
                  ),
                ],
                if (records.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _PointRecordsPreview(
                    records: records,
                    onOpenRecords: onOpenRecords == null
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            onOpenRecords!();
                          },
                    onOpenRecord: onOpenRecord == null
                        ? null
                        : (record) {
                            Navigator.of(context).pop();
                            onOpenRecord!(record);
                          },
                  ),
                ],
                const SizedBox(height: 18),
                _PointDetailActions(
                  scope: actionScope,
                  status: status,
                  onOpenNavigation: () => _openNavigation(context),
                  onOpenCamera: onOpenCamera == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          onOpenCamera!();
                        },
                  onSetCurrent: onSetCurrent == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          onSetCurrent!();
                        },
                  statusAction: onComplete == null ? null : _statusAction,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _sourceText {
    return switch (point.source) {
      PointSource.anitabi => 'Anitabi / ${point.referenceLabel}',
      PointSource.manual => '手动录入 / ${point.referenceLabel}',
    };
  }

  _PointStatusAction get _statusAction {
    return switch (status) {
      VisitStatus.completed => _PointStatusAction(
        label: '撤回打卡',
        icon: Icons.replay_outlined,
        onTap: onComplete!,
      ),
      VisitStatus.current => _PointStatusAction(
        label: '标记完成',
        icon: Icons.check_circle_outline,
        onTap: onComplete!,
      ),
      VisitStatus.pending => _PointStatusAction(
        label: '标记完成',
        icon: Icons.check_circle_outline,
        onTap: onComplete!,
      ),
    };
  }

  String get _groupName {
    final groupId = point.groupId;
    if (groupId == null) {
      return '未分入片区';
    }
    return groups
        .firstWhere(
          (group) => group.id == groupId,
          orElse: () => PilgrimagePlanGroup(
            id: groupId,
            name: '未知片区',
            orderIndex: 0,
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        )
        .name;
  }

  String get _groupAnchorLabel {
    final groupId = point.groupId;
    if (groupId == null) {
      return '未设置关键点';
    }
    final group = groups.where((group) => group.id == groupId).firstOrNull;
    final anchorName = group?.anchorName;
    if (anchorName == null || anchorName.trim().isEmpty) {
      return '未设置关键点';
    }
    return anchorName;
  }
}

class _PointDetailActions extends StatelessWidget {
  const _PointDetailActions({
    required this.scope,
    required this.status,
    required this.onOpenNavigation,
    required this.onOpenCamera,
    required this.onSetCurrent,
    required this.statusAction,
  });

  final PointDetailActionScope scope;
  final VisitStatus status;
  final VoidCallback onOpenNavigation;
  final VoidCallback? onOpenCamera;
  final VoidCallback? onSetCurrent;
  final _PointStatusAction? statusAction;

  @override
  Widget build(BuildContext context) {
    final primaryActions = <Widget>[
      Expanded(
        child: FilledButton.icon(
          onPressed: onOpenNavigation,
          icon: const Icon(Icons.near_me_outlined, size: 18),
          label: const Text('导航'),
        ),
      ),
      if (scope == PointDetailActionScope.visit && onOpenCamera != null) ...[
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onOpenCamera,
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: const Text('拍摄参考'),
          ),
        ),
      ],
    ];

    final managementActions = <Widget>[
      if (scope != PointDetailActionScope.assign && onSetCurrent != null)
        Expanded(
          child: OutlinedButton.icon(
            onPressed: status == VisitStatus.current ? null : onSetCurrent,
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: const Text('设为当前'),
          ),
        ),
      if (scope != PointDetailActionScope.assign && statusAction != null) ...[
        if (onSetCurrent != null) const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              statusAction!.onTap();
            },
            icon: Icon(statusAction!.icon, size: 18),
            label: Text(statusAction!.label),
          ),
        ),
      ],
    ];

    return Column(
      children: [
        Row(children: primaryActions),
        if (managementActions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: managementActions),
        ],
      ],
    );
  }
}

class _PointStatusAction {
  const _PointStatusAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _GroupOptionTile extends StatelessWidget {
  const _GroupOptionTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? AppColors.accent : AppColors.textSecondary,
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0),
      ),
      onTap: onTap,
    );
  }
}

class _ReferenceColumn extends StatelessWidget {
  const _ReferenceColumn({
    required this.point,
    required this.status,
    required this.onReplace,
  });

  final PilgrimagePoint point;
  final VisitStatus status;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      VisitStatus.current => AppColors.accent,
      VisitStatus.completed => AppColors.textSecondary,
      VisitStatus.pending => AppColors.accentDark,
    };

    return SizedBox(
      width: 76,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => ImageViewerScreen.show(
              context,
              filePath: point.referenceFullImagePath,
              imageUrl: point.referenceImageUrl,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  border: Border.all(color: AppColors.border),
                ),
                child: ReferenceThumbnail(
                  localPath: point.referenceThumbnailPath,
                  imageUrl: point.referenceImageUrl,
                  fit: BoxFit.cover,
                  placeholder: Icon(
                    Icons.image_outlined,
                    color: color,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 30,
            child: OutlinedButton(
              onPressed: onReplace,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              child: const Text('替换'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupInfoRow extends StatelessWidget {
  const _GroupInfoRow({
    required this.groupName,
    required this.anchorLabel,
    required this.onMove,
  });

  final String groupName;
  final String anchorLabel;
  final VoidCallback? onMove;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.grid_view_outlined,
          color: AppColors.textSecondary,
          size: 19,
        ),
        const SizedBox(width: 8),
        const SizedBox(
          width: 42,
          child: Text(
            '片区',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CopyableText(
                text: groupName,
                copyLabel: '片区',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 2),
              CopyableText(
                text: anchorLabel,
                copyLabel: '片区关键点',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        if (onMove != null) ...[
          const SizedBox(width: 8),
          SizedBox(
            height: 32,
            child: OutlinedButton(
              onPressed: onMove,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              child: const Text('更改'),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final VisitStatus status;

  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      VisitStatus.current => '当前目标',
      VisitStatus.completed => '已完成',
      VisitStatus.pending => '待访问',
    };

    final color = switch (status) {
      VisitStatus.current => AppColors.accent,
      VisitStatus.completed => AppColors.textSecondary,
      VisitStatus.pending => AppColors.warning,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 19),
        const SizedBox(width: 8),
        SizedBox(
          width: 42,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: CopyableText(
            text: value,
            copyLabel: label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _PointRecordsPreview extends StatelessWidget {
  const _PointRecordsPreview({
    required this.records,
    required this.onOpenRecords,
    required this.onOpenRecord,
  });

  final List<PilgrimageVisitRecord> records;
  final VoidCallback? onOpenRecords;
  final ValueChanged<PilgrimageVisitRecord>? onOpenRecord;

  @override
  Widget build(BuildContext context) {
    final recentRecords = records.take(6).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.collections_bookmark_outlined,
              color: AppColors.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              '本点记录 ${records.length}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const Spacer(),
            if (onOpenRecords != null)
              TextButton.icon(
                onPressed: onOpenRecords,
                icon: const Icon(Icons.chevron_right, size: 18),
                label: const Text('全部'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final record = recentRecords[index];
              return SizedBox(
                width: 92,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onOpenRecord == null
                        ? null
                        : () => onOpenRecord!(record),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: VisitRecordPhoto(
                            path: record.displayPhotoPath,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatRecordTime(record.capturedAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemCount: recentRecords.length,
          ),
        ),
      ],
    );
  }

  String _formatRecordTime(DateTime capturedAt) {
    final month = capturedAt.month.toString().padLeft(2, '0');
    final day = capturedAt.day.toString().padLeft(2, '0');
    final hour = capturedAt.hour.toString().padLeft(2, '0');
    final minute = capturedAt.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }
}
