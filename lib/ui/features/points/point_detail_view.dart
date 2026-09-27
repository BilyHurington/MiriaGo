import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../application/go/reference_replacement.dart';
import '../../../application/plan_session.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../../plan/pilgrimage_plan_controller.dart';
import '../../../application/records/record_details.dart';
import '../../app/router.dart';
import '../../app/toast.dart';
import '../../components/components.dart';
import '../add/add_menu.dart';
import '../camera/camera_entry.dart';
import '../navigation/navigation_entry.dart';
import '../organize/group_picker.dart';
import 'point_detail_entry.dart';
import '../records/record_images.dart';
import '../records/records_page.dart' show openRecord;
import 'point_shared.dart';

/// Point details (DESIGN §8.3): reference image with a blurred backdrop,
/// status, name, actions, info rows and the point's records.
///
/// The same view is used in the 巡礼 bottom sheet, the wide inspector and
/// the adaptive modal ([modal]). It follows the active plan live and calls
/// [onClose] (at most once) when it should go away, e.g. after deletion.
class PointDetailView extends StatefulWidget {
  const PointDetailView({
    required this.pointId,
    this.scope = PointDetailScope.go,
    this.onClose,
    this.modal = false,
    this.showTopBar = true,
    super.key,
  });

  final String pointId;
  final PointDetailScope scope;
  final VoidCallback? onClose;

  /// Inside a modal sheet/dialog: sizes to its content, has no own top bar
  /// and closes before navigating elsewhere (as the old sheet did).
  final bool modal;

  /// Shows 「点位详情」 with a close button above the content (ignored in
  /// [modal] mode, where the modal frame has its own header).
  final bool showTopBar;

  @override
  State<PointDetailView> createState() => _PointDetailViewState();
}

class _PointDetailViewState extends State<PointDetailView> {
  bool _closed = false;
  bool _deleting = false;
  bool _replacing = false;

  PilgrimagePlanController get _controller =>
      context.read<PlanSession>().controller;

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    widget.onClose?.call();
  }

  /// Runs [action] with a context that survives closing a modal detail.
  Future<void> _leaveThen(
    Future<void> Function(BuildContext host) action,
  ) async {
    if (!widget.modal) {
      await action(context);
      return;
    }
    final host = Navigator.of(context, rootNavigator: true).context;
    _close();
    await action(host);
  }

  void _closeIfModal() {
    if (widget.modal) _close();
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  void _openCamera(PilgrimagePoint point) {
    if (widget.scope == PointDetailScope.assign) {
      context.showToast('请先完成片区分配', kind: ToastKind.warning);
      return;
    }
    unawaited(_leaveThen((host) => openCamera(host, pointId: point.id)));
  }

  void _openInAppNavigation(PilgrimagePoint point) {
    if (!point.hasCoordinate) return;
    unawaited(_leaveThen((host) => openRoutePreview(host, pointId: point.id)));
  }

  void _toggleCompletion(PilgrimagePoint point) {
    togglePointCompletion(context, point);
    _closeIfModal();
  }

  /// Old map screen `_setCurrentPoint`: the new target is also selected so
  /// the 巡礼 map recentres on it.
  void _setCurrent(PilgrimagePoint point) {
    final controller = _controller;
    controller.setCurrentPoint(point);
    if (point.hasCoordinate) controller.selectPoint(point);
    _closeIfModal();
  }

  void _editPoint(PilgrimagePoint point) {
    if (_controller.repository == null) {
      context.showToast('当前环境无法编辑点位。', kind: ToastKind.warning);
      return;
    }
    unawaited(_leaveThen((host) => openPointEditor(host, pointId: point.id)));
  }

  Future<void> _moveToGroup(PilgrimagePoint point) async {
    final picked = await pickGroup(
      context,
      title: '移动到片区',
      subtitle: '选择一个片区作为当前点位所属片区',
      selectedGroupId: point.groupId ?? kUngroupedId,
    );
    if (picked == null || !mounted) return;
    final groupId = picked == kUngroupedId ? null : picked;
    final controller = _controller;
    final latest = controller.pointById(point.id) ?? point;
    try {
      await controller.movePointToGroup(latest, groupId);
    } catch (_) {
      if (mounted) {
        context.showToast('移动片区失败', kind: ToastKind.error);
      }
    }
  }

  Future<void> _replaceReference(PilgrimagePoint point) async {
    if (_replacing) return;
    final toasts = context.read<ToastController>();
    final picker = PointFeatureOverrides.of(context).pickReferenceImage;
    final controller = _controller;
    String? path;
    try {
      path = await picker();
    } catch (_) {
      toasts.show(
        ToastData(kind: ToastKind.error, title: ReferenceReplaceTexts.failed),
      );
      return;
    }
    if (path == null || !mounted) return;
    setState(() => _replacing = true);
    toasts.show(
      ToastData(kind: ToastKind.running, title: ReferenceReplaceTexts.running),
    );
    final outcome = await replacePointReference(
      point: controller.pointById(point.id) ?? point,
      pickedPath: path,
      isStillOpen: () => mounted && !_closed,
      save: controller.updatePoint,
    );
    toasts.show(
      ToastData(
        kind: switch (outcome) {
          ReferenceReplaceOutcome.replaced => ToastKind.success,
          ReferenceReplaceOutcome.failed => ToastKind.error,
          ReferenceReplaceOutcome.cancelled => ToastKind.warning,
        },
        title: ReferenceReplaceTexts.forOutcome(outcome),
      ),
    );
    if (mounted) setState(() => _replacing = false);
  }

  Future<void> _delete(PilgrimagePoint point) async {
    if (_deleting || _closed) return;
    setState(() => _deleting = true);
    try {
      final confirmed = await showConfirmDialog(
        context,
        title: '删除点位',
        message: '将从计划中删除“${point.name}”。已有巡礼记录及照片将保留。',
        confirmLabel: '删除点位',
        destructive: true,
        emphasizedValues: [point.name],
      );
      if (!confirmed || !mounted || _closed) return;
      await _controller.deletePoint(point);
      if (!mounted) return;
      _close();
    } catch (_) {
      if (mounted && !_closed) {
        context.showToast('删除点位失败，请稍后重试。', kind: ToastKind.error);
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _openRecords(PilgrimagePoint point) {
    unawaited(
      _leaveThen((host) => host.push<void>(Routes.pointRecords(point.id))),
    );
  }

  void _openRecord(PilgrimageVisitRecord record) {
    unawaited(
      _leaveThen((host) async {
        openRecord(host, record.id);
      }),
    );
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url.trim());
    var opened = false;
    if (uri != null && uri.hasScheme) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = false;
      }
    }
    if (!opened && mounted) {
      context.showToast('无法打开链接。', kind: ToastKind.error);
    }
  }

  void _showMore(
    BuildContext anchor,
    PilgrimagePoint point,
    VisitStatus status,
  ) {
    final actions = PointDetailActions.of(
      widget.scope,
      status: status,
      hasCoordinate: point.hasCoordinate,
    );
    unawaited(
      showActionMenu(
        context,
        anchor: anchor,
        title: point.name,
        actions: [
          if (actions.setCurrent)
            MenuAction(
              label: '设为当前目标',
              icon: Symbols.flag_rounded,
              onSelected: () => _setCurrent(point),
            ),
          if (actions.edit)
            MenuAction(
              label: '编辑点位',
              icon: Symbols.edit_rounded,
              onSelected: () => _editPoint(point),
            ),
          MenuAction(
            label: '移动到片区',
            icon: Symbols.drive_file_move_rounded,
            onSelected: () => unawaited(_moveToGroup(point)),
          ),
          MenuAction(
            label: '替换参考图',
            icon: Symbols.swap_horiz_rounded,
            onSelected: () => unawaited(_replaceReference(point)),
          ),
          MenuAction(
            label: '删除点位',
            icon: Symbols.delete_rounded,
            destructive: true,
            enabled: !_deleting,
            onSelected: () => unawaited(_delete(point)),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PlanSession>();
    final controller = session.isReady ? session.controller : null;
    final point = controller?.pointById(widget.pointId);
    if (controller == null || point == null) {
      // Deleted elsewhere (or plan switched): go away.
      if (!_closed) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _close());
      }
      return const SizedBox.shrink();
    }
    final status = controller.statusFor(point);
    final records = controller.recordsForPoint(point.id);
    final actions = PointDetailActions.of(
      widget.scope,
      status: status,
      hasCoordinate: point.hasCoordinate,
    );
    final gutter = Space.x4;

    final children = <Widget>[
      Padding(
        padding: EdgeInsets.fromLTRB(gutter, Space.x2, gutter, 0),
        child: _HeroImage(
          point: point,
          replacing: _replacing,
          onOpen: () => openReferenceViewer(context, point),
          onReplace: () => unawaited(_replaceReference(point)),
        ),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(gutter, Space.x4, gutter, 0),
        child: _TitleBlock(
          point: point,
          status: status,
          recordCount: records.length,
        ),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(gutter, Space.x4, gutter, 0),
        child: _ActionBar(
          point: point,
          status: status,
          actions: actions,
          onNavigate: () => _openInAppNavigation(point),
          onOpenExternal: () =>
              unawaited(openPointInExternalMap(context, point)),
          onCamera: () => _openCamera(point),
          onToggleCompletion: () => _toggleCompletion(point),
          onMore: (anchor) => _showMore(anchor, point, status),
        ),
      ),
      if (!point.hasCoordinate && actions.edit)
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, Space.x3, gutter, 0),
          child: InfoBanner(
            kind: InfoBannerKind.warning,
            message: '坐标待补充，补充坐标后即可导航。',
            actionLabel: '编辑点位',
            onAction: () => _editPoint(point),
          ),
        ),
      SectionHeader(
        title: '信息',
        padding: EdgeInsets.fromLTRB(gutter, Space.x5, Space.x2, Space.x1),
      ),
      ..._infoRows(context, controller.plan, point, gutter),
      if (records.isNotEmpty) ...[
        SectionHeader(
          title: '本点记录',
          count: records.length,
          padding: EdgeInsets.fromLTRB(gutter, Space.x5, Space.x2, Space.x1),
          trailing: TextButton(
            key: const ValueKey('point-detail-all-records'),
            onPressed: () => _openRecords(point),
            child: const Text('全部 ›'),
          ),
        ),
        _RecordsStrip(
          records: records.take(6).toList(growable: false),
          padding: EdgeInsets.symmetric(horizontal: gutter),
          onOpen: _openRecord,
        ),
      ],
      SizedBox(height: Space.x6 + MediaQuery.paddingOf(context).bottom),
    ];

    final list = ListView(
      key: ValueKey('point-detail-list-${point.id}'),
      shrinkWrap: widget.modal,
      padding: EdgeInsets.zero,
      children: children,
    );
    if (widget.modal || !widget.showTopBar) {
      return Semantics(
        container: true,
        label: '点位详情',
        explicitChildNodes: true,
        child: list,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PointDetailTopBar(onClose: widget.onClose == null ? null : _close),
        Expanded(child: list),
      ],
    );
  }

  List<Widget> _infoRows(
    BuildContext context,
    PilgrimagePlan plan,
    PilgrimagePoint point,
    double gutter,
  ) {
    final padding = EdgeInsets.symmetric(
      horizontal: gutter,
      vertical: Space.x2,
    );
    final coordinates = point.hasCoordinate
        ? '${point.position.latitude.toStringAsFixed(5)}, '
              '${point.position.longitude.toStringAsFixed(5)}'
        : '待补充';
    final group = point.groupId == null
        ? null
        : plan.groups.where((g) => g.id == point.groupId).firstOrNull;
    final groupName = point.groupId == null ? '未分入片区' : (group?.name ?? '未知片区');
    final anchorName = group?.anchorName?.trim();
    final anchorLabel = anchorName == null || anchorName.isEmpty
        ? '未设置关键点'
        : '关键点：$anchorName';
    final c = context.colors;
    final note = point.note?.trim();
    return [
      KeyValueRow(
        label: '作品',
        value: '${point.work.title} / ${point.work.subtitle}',
        padding: padding,
      ),
      KeyValueRow(
        label: '场景',
        value: point.displayEpisodeLabel,
        padding: padding,
      ),
      KeyValueRow(
        key: const ValueKey('point-detail-coordinates'),
        label: '坐标',
        value: coordinates,
        monospaceDigits: true,
        copyable: point.hasCoordinate,
        padding: padding,
      ),
      KeyValueRow(
        key: const ValueKey('point-detail-group'),
        label: '片区',
        value: groupName,
        padding: padding,
        valueWidget: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(groupName, style: context.text.bodyMedium),
                  Text(
                    anchorLabel,
                    style: context.text.caption.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.x2),
            MiriaButton.ghost(
              key: const ValueKey('point-detail-change-group'),
              label: '更改',
              size: MiriaButtonSize.sm,
              onPressed: () => unawaited(_moveToGroup(point)),
            ),
          ],
        ),
      ),
      KeyValueRow(label: '参考', value: point.referenceLabel, padding: padding),
      KeyValueRow(
        label: '来源',
        value: switch (point.source) {
          PointSource.anitabi => 'Anitabi / ${point.referenceLabel}',
          PointSource.manual => '手动录入 / ${point.referenceLabel}',
        },
        padding: padding,
      ),
      if (point.sourceId case final sourceId?)
        KeyValueRow(label: 'ID', value: sourceId, padding: padding),
      if (point.sourceUrl case final url?)
        KeyValueRow(
          label: '链接',
          value: url,
          padding: padding,
          onTap: () => unawaited(_openLink(url)),
          valueWidget: Text(
            url,
            style: context.text.bodyMedium?.copyWith(
              color: c.primaryText,
              decoration: TextDecoration.underline,
              decorationColor: c.primaryText,
            ),
          ),
        ),
      if (note != null && note.isNotEmpty)
        KeyValueRow(label: '备注', value: note, padding: padding),
    ];
  }
}

/// 「点位详情」 bar above inline details: a close button, or a leading back
/// arrow when the details were paged in over a list ([back]).
class PointDetailTopBar extends StatelessWidget {
  const PointDetailTopBar({
    this.onClose,
    this.title = '点位详情',
    this.back = false,
    super.key,
  });

  final VoidCallback? onClose;
  final String title;
  final bool back;

  @override
  Widget build(BuildContext context) {
    final onClose = this.onClose;
    final button = onClose == null
        ? null
        : MiriaIconButton(
            key: const ValueKey('point-detail-close'),
            icon: back ? Symbols.arrow_back_rounded : Symbols.close_rounded,
            tooltip: back ? '返回' : '关闭',
            onPressed: onClose,
          );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        back && button != null ? Space.x1 : Space.x4,
        Space.x1,
        Space.x1,
        0,
      ),
      child: Row(
        children: [
          if (back && button != null) ...[
            button,
            const SizedBox(width: Space.x1),
          ],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleMedium,
              ),
            ),
          ),
          if (!back && button != null) button,
        ],
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({
    required this.point,
    required this.replacing,
    required this.onOpen,
    required this.onReplace,
  });

  final PilgrimagePoint point;
  final bool replacing;
  final VoidCallback onOpen;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    final hasImage = referenceViewerImage(point) != null;
    return ClipRRect(
      borderRadius: Radii.lgAll,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MiriaPressable(
              onTap: hasImage ? onOpen : null,
              semanticLabel: hasImage ? '查看参考图' : '暂无参考图',
              borderRadius: Radii.lgAll,
              child: PointReferenceImage(point: point),
            ),
            Positioned(
              right: Space.x2,
              bottom: Space.x2,
              child: _OverlayButton(
                key: const ValueKey('point-detail-replace'),
                icon: Symbols.swap_horiz_rounded,
                label: '替换',
                busy: replacing,
                onPressed: replacing ? null : onReplace,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: '替换参考图',
      child: Material(
        color: c.surfaceOverlay,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.x3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy)
                    const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(icon, size: 16, color: c.textPrimary),
                  const SizedBox(width: Space.x1),
                  Text(label, style: context.text.labelMedium),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.point,
    required this.status,
    required this.recordCount,
  });

  final PilgrimagePoint point;
  final VisitStatus status;
  final int recordCount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final subtitle = point.subtitle.trim();
    final workSubtitle = point.work.subtitle.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Space.x2,
          runSpacing: Space.x1,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusBadge(
              key: const ValueKey('point-detail-status-badge'),
              status: status,
            ),
            if (recordCount > 0) RecordCountTag(count: recordCount),
          ],
        ),
        const SizedBox(height: Space.x2),
        CopyableText(
          text: point.name,
          copyLabel: '点位名称',
          locale: MiriaFonts.japanese,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: context.text.titleLarge,
        ),
        if (subtitle.isNotEmpty && subtitle != point.name) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            locale: MiriaFonts.japanese,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodyMedium?.copyWith(color: c.textSecondary),
          ),
        ],
        const SizedBox(height: Space.x1),
        Text.rich(
          TextSpan(
            text: point.work.title,
            children: [
              if (workSubtitle.isNotEmpty && workSubtitle != point.work.title)
                TextSpan(
                  text: ' · $workSubtitle',
                  style: const TextStyle(locale: MiriaFonts.japanese),
                ),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodySmall?.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}

/// Navigation | 拍摄 | 完成 | ⋯ — one row when there is room, otherwise
/// navigation on its own row (buttons shrink full → short → icon).
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.point,
    required this.status,
    required this.actions,
    required this.onNavigate,
    required this.onOpenExternal,
    required this.onCamera,
    required this.onToggleCompletion,
    required this.onMore,
  });

  final PilgrimagePoint point;
  final VisitStatus status;
  final PointDetailActions actions;
  final VoidCallback onNavigate;
  final VoidCallback onOpenExternal;
  final VoidCallback onCamera;
  final VoidCallback onToggleCompletion;
  final ValueChanged<BuildContext> onMore;

  @override
  Widget build(BuildContext context) {
    final navigation = SplitNavButton(
      available: point.hasCoordinate,
      onNavigate: onNavigate,
      onOpenExternal: onOpenExternal,
      inAppKey: const ValueKey('point-detail-in-app-navigation-button'),
      externalKey: const ValueKey('point-detail-external-navigation-button'),
    );
    final secondary = <Widget>[
      if (actions.camera)
        MiriaButton.secondary(
          key: const ValueKey('point-detail-camera'),
          label: '拍摄参考',
          shortLabel: '拍摄',
          icon: Symbols.photo_camera_rounded,
          expand: true,
          onPressed: onCamera,
        ),
      if (actions.completion)
        MiriaButton(
          key: const ValueKey('point-detail-complete'),
          variant: MiriaButtonVariant.tonal,
          label: completionLabel(status),
          shortLabel: status == VisitStatus.completed ? '取消' : '完成',
          icon: completionIcon(status),
          expand: true,
          semanticLabel: completionLabel(status),
          onPressed: onToggleCompletion,
        ),
    ];
    final more = Builder(
      builder: (anchor) => MiriaIconButton(
        key: const ValueKey('point-detail-more'),
        icon: Symbols.more_horiz_rounded,
        tooltip: '更多操作',
        variant: MiriaIconButtonVariant.filled,
        onPressed: () => onMore(anchor),
      ),
    );
    return PointActionLayout(
      navigation: navigation,
      buttons: secondary,
      trailing: more,
    );
  }
}

class _RecordsStrip extends StatelessWidget {
  const _RecordsStrip({
    required this.records,
    required this.padding,
    required this.onOpen,
  });

  final List<PilgrimageVisitRecord> records;
  final EdgeInsets padding;
  final ValueChanged<PilgrimageVisitRecord> onOpen;

  static String _label(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.month)}/${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    const tile = 92.0;
    final captionHeight = MediaQuery.textScalerOf(context).scale(16);
    return SizedBox(
      height: tile + Space.x1 + captionHeight + 2,
      child: ListView.separated(
        key: const ValueKey('point-detail-records'),
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: records.length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.x2),
        itemBuilder: (context, index) {
          final record = records[index];
          final label = _label(record.capturedAt);
          return SizedBox(
            width: tile,
            child: MiriaPressable(
              key: ValueKey('point-record-preview-${record.id}'),
              onTap: () => onOpen(record),
              borderRadius: Radii.smAll,
              semanticLabel: '巡礼记录 $label',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: Radii.smAll,
                    child: SizedBox.square(
                      dimension: tile,
                      child: RecordImage(
                        path: RecordDetails.displayPhotoPath(record),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.x1),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: context.text.caption.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
