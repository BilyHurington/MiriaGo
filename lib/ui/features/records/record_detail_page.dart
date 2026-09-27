import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/plan_session.dart';
import '../../../application/records/record_details.dart';
import '../../../application/records/record_query.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../../plan/pilgrimage_plan_controller.dart';
import '../../app/router.dart';
import '../../app/toast.dart';
import '../../components/components.dart';
import '../export/comparison_export.dart';
import '../points/point_detail_entry.dart';
import '../viewer/image_viewer.dart';
import 'record_images.dart';
import 'records_page.dart';

/// 记录详情 route (`/records/:recordId`).
class RecordDetailPage extends StatelessWidget {
  const RecordDetailPage({required this.recordId, super.key});
  final String recordId;

  @override
  Widget build(BuildContext context) =>
      RecordDetailView(recordId: recordId, embedded: false);
}

/// Record details (DESIGN §8.16). [embedded] = detail pane of the records
/// list-detail layout (no back button; closing clears the selection).
class RecordDetailView extends StatefulWidget {
  const RecordDetailView({
    required this.recordId,
    this.embedded = false,
    super.key,
  });

  final String recordId;
  final bool embedded;

  @override
  State<RecordDetailView> createState() => _RecordDetailViewState();
}

class _RecordDetailViewState extends State<RecordDetailView> {
  static const _details = RecordDetails();

  bool _deleting = false;

  /// Last record shown, kept while the deletion closes the page.
  PilgrimageVisitRecord? _lastRecord;

  void _close() {
    if (widget.embedded) {
      context.go(recordsLocation());
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.records);
    }
  }

  void _openNeighbour(String recordId) {
    if (widget.embedded) {
      context.go(recordsLocation(recordId));
    } else {
      context.pushReplacement(Routes.record(recordId));
    }
  }

  void _openViewer(RecordImages images, {required bool reference}) {
    final list = <ViewerImage>[
      if (images.hasReference)
        ViewerImage(
          path: images.referencePath,
          url: images.referencePath == null ? images.referenceUrl : null,
          label: '参考图',
        ),
      if (images.photoPath != null)
        ViewerImage(path: images.photoPath, label: '巡礼图'),
    ];
    if (list.isEmpty) return;
    final index = reference || !images.hasReference ? 0 : list.length - 1;
    openImageViewer(context, images: list, initialIndex: index);
  }

  Future<void> _confirmDelete(
    PilgrimagePlanController controller,
    PilgrimageVisitRecord record,
  ) async {
    if (_deleting) return;
    final result = await showConfirmDialogWithCheckbox(
      context,
      title: '删除记录',
      message: '将删除这条巡礼记录，不会改变点位完成状态。',
      confirmLabel: '删除',
      destructive: true,
      emphasizedValues: const ['这条巡礼记录'],
      checkboxLabel: '同时删除照片文件',
    );
    if (!result.confirmed || !mounted) return;

    // The embedded detail pane unmounts as soon as the record disappears
    // from the list, so everything needed afterwards is captured here.
    final toasts = context.read<ToastController>();
    final router = GoRouter.of(context);
    final embedded = widget.embedded;
    setState(() => _deleting = true);
    final outcome = await deleteVisitRecordWithPhotos(
      record: record,
      deleteRecord: () => controller.deleteVisitRecord(record),
      repository: controller.repository,
      deleteFiles: result.checked,
    );
    switch (outcome) {
      case RecordDeleteOutcome.failed:
        if (mounted) setState(() => _deleting = false);
        toasts.show(
          ToastData(
            kind: ToastKind.error,
            title: RecordDetails.deleteFailedMessage,
          ),
        );
        return;
      case RecordDeleteOutcome.deletedWithLeftovers:
        toasts.show(
          ToastData(
            kind: ToastKind.warning,
            title: RecordDetails.deleteLeftoversMessage,
          ),
        );
      case RecordDeleteOutcome.deleted:
        break;
    }
    if (embedded) {
      // Clear `?record=` unless the user already moved on.
      final uri = router.state.uri;
      if (uri.path == Routes.records &&
          uri.queryParameters['record'] == record.id) {
        router.go(recordsLocation());
      }
    } else if (mounted) {
      _close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PlanSession>();
    if (!session.isReady) {
      final error = session.loadError;
      return _frame(
        body: error != null
            ? ErrorState(
                title: '计划加载失败',
                detail: kDebugMode ? '请稍后重试。\n$error' : '请稍后重试。',
                onRetry: () => unawaited(session.load()),
              )
            : const Center(child: ProgressRing(semanticLabel: '加载中')),
      );
    }
    final controller = session.controller;
    final current = controller.visitRecords
        .where((record) => record.id == widget.recordId)
        .firstOrNull;
    final record = current ?? (_deleting ? _lastRecord : null);
    if (record == null) {
      return _frame(
        body: EmptyState(
          icon: Symbols.hide_image_rounded,
          title: '找不到这条记录',
          message: '记录可能已被删除。',
          actionLabel: '返回记录',
          onAction: () => context.go(Routes.records),
        ),
      );
    }
    _lastRecord = record;

    final point = controller.pointById(record.pointId);
    final images = _details.imagesFor(record, point);
    final neighbours = RecordBrowseOrder.neighbours(
      record.id,
      order: RecordBrowseOrder.instance.value,
      fallback: [
        for (final r in [
          ...controller.visitRecords,
        ]..sort((a, b) => b.capturedAt.compareTo(a.capturedAt)))
          r.id,
      ],
    );

    final compare = _RecordCompare(
      images: images,
      onTap: (reference) => _openViewer(images, reference: reference),
    );
    final info = _RecordInfo(
      record: record,
      point: point,
      plan: controller.plan,
    );
    final actions = _RecordActions(
      deleting: _deleting,
      onGrading: () => context.push(Routes.recordGrading(record.id)),
      onExport: () => showComparisonExport(context, record: record),
      onShare: images.photoPath == null
          ? null
          : () => openImageViewer(
              context,
              images: [ViewerImage(path: images.photoPath, label: '巡礼图')],
            ),
      onDelete: () => _confirmDelete(controller, record),
    );
    final orphan = point == null
        ? const InfoBanner(
            key: ValueKey('record-orphan-notice'),
            kind: InfoBannerKind.warning,
            icon: Symbols.link_off_rounded,
            message: RecordDetails.orphanNotice,
          )
        : null;

    final body = LayoutBuilder(
      builder: (context, constraints) {
        final gutter = context.layout.gutter;
        if (constraints.maxWidth >= 760) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(gutter),
                  child: compare,
                ),
              ),
              VerticalDivider(width: 1, color: context.colors.hairline),
              SizedBox(
                width: constraints.maxWidth >= 1100 ? 400 : 340,
                child: ListView(
                  key: const ValueKey('record-detail-side'),
                  padding: EdgeInsets.all(gutter),
                  children: [
                    if (orphan != null) ...[
                      orphan,
                      const SizedBox(height: Space.x3),
                    ],
                    info,
                    const SizedBox(height: Space.x3),
                    actions,
                  ],
                ),
              ),
            ],
          );
        }
        return ListView(
          key: const ValueKey('record-detail-scroll-view'),
          padding: EdgeInsets.fromLTRB(gutter, Space.x2, gutter, Space.x6),
          children: [
            ContentColumn(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  compare,
                  const SizedBox(height: Space.x4),
                  if (orphan != null) ...[
                    orphan,
                    const SizedBox(height: Space.x3),
                  ],
                  info,
                  const SizedBox(height: Space.x3),
                  actions,
                ],
              ),
            ),
          ],
        );
      },
    );

    return CallbackShortcuts(
      bindings: {
        if (!_deleting && neighbours.previous != null)
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              _openNeighbour(neighbours.previous!),
        if (!_deleting && neighbours.next != null)
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              _openNeighbour(neighbours.next!),
      },
      child: Focus(
        autofocus: true,
        child: _frame(
          actions: [
            if (neighbours.previous != null || neighbours.next != null) ...[
              MiriaIconButton(
                key: const ValueKey('record-detail-previous'),
                icon: Symbols.chevron_left_rounded,
                tooltip: '上一条',
                onPressed: _deleting || neighbours.previous == null
                    ? null
                    : () => _openNeighbour(neighbours.previous!),
              ),
              MiriaIconButton(
                key: const ValueKey('record-detail-next'),
                icon: Symbols.chevron_right_rounded,
                tooltip: '下一条',
                onPressed: _deleting || neighbours.next == null
                    ? null
                    : () => _openNeighbour(neighbours.next!),
              ),
            ],
            MiriaIconButton(
              key: const ValueKey('record-detail-delete'),
              icon: Symbols.delete_rounded,
              tooltip: '删除记录',
              onPressed: _deleting
                  ? null
                  : () => _confirmDelete(controller, record),
            ),
          ],
          body: body,
        ),
      ),
    );
  }

  Widget _frame({required Widget body, List<Widget> actions = const []}) {
    if (widget.embedded) {
      final c = context.colors;
      return Scaffold(
        backgroundColor: c.canvas,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: c.canvas,
          titleSpacing: context.layout.gutter,
          title: const Text('记录详情'),
          actions: [
            ...actions,
            const SizedBox(width: Space.x2),
          ],
        ),
        body: body,
      );
    }
    return MiriaPageScaffold(title: '记录详情', actions: actions, body: body);
  }
}

class _RecordCompare extends StatelessWidget {
  const _RecordCompare({required this.images, required this.onTap});

  final RecordImages images;
  final ValueChanged<bool> onTap;

  @override
  Widget build(BuildContext context) {
    final reference = recordImageProvider(
      context,
      path: images.referencePath,
      url: images.referenceUrl,
    );
    final photo = recordImageProvider(context, path: images.photoPath);
    void tapReference() => onTap(true);
    void tapPhoto() => onTap(false);
    if (reference != null && photo != null) {
      return PhotoCompare.images(
        key: const ValueKey('record-photo-compare'),
        reference: reference,
        photo: photo,
        onTapReference: tapReference,
        onTapPhoto: tapPhoto,
      );
    }
    return PhotoCompare(
      key: const ValueKey('record-photo-compare'),
      reference: reference == null
          ? const RecordImagePlaceholder(
              icon: Symbols.image_not_supported_rounded,
              label: '没有参考图',
            )
          : Image(image: reference, fit: BoxFit.cover),
      photo: photo == null
          ? const RecordImagePlaceholder(
              icon: Symbols.broken_image_rounded,
              label: '巡礼图不可用',
            )
          : Image(image: photo, fit: BoxFit.cover),
      onTapReference: reference == null ? null : tapReference,
      onTapPhoto: photo == null ? null : tapPhoto,
    );
  }
}

class _RecordInfo extends StatelessWidget {
  const _RecordInfo({
    required this.record,
    required this.point,
    required this.plan,
  });

  final PilgrimageVisitRecord record;
  final PilgrimagePoint? point;
  final PilgrimagePlan plan;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final point = this.point;
    final title = RecordDetails.title(record, point);
    final subtitle = RecordDetails.subtitle(record, point);
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.x4,
        Space.x3 + 2,
        Space.x3,
        Space.x3,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  key: const ValueKey('record-detail-title'),
                  locale: MiriaFonts.japanese,
                  style: text.titleLarge,
                ),
                const SizedBox(height: Space.x1),
                Text(
                  subtitle,
                  locale: MiriaFonts.japanese,
                  style: text.bodyMedium?.copyWith(color: c.textSecondary),
                ),
                if (record.hasColorGrading) ...[
                  const SizedBox(height: Space.x2),
                  const Tag(
                    label: '已调色',
                    tone: MiriaTone.primary,
                    icon: Symbols.auto_fix_high_rounded,
                  ),
                ],
              ],
            ),
          ),
          if (point != null) ...[
            const SizedBox(width: Space.x2),
            Icon(Symbols.chevron_right_rounded, color: c.textTertiary),
          ],
        ],
      ),
    );

    return MiriaCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (point != null)
            MiriaPressable(
              key: const ValueKey('record-detail-point'),
              semanticLabel: '查看点位详情：$title',
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(Radii.md),
              ),
              onTap: () => showPointDetail(
                context,
                pointId: point.id,
                scope: PointDetailScope.records,
              ),
              child: header,
            )
          else
            header,
          Divider(height: 1, color: c.hairline),
          const SizedBox(height: Space.x1),
          KeyValueRow(
            label: '拍摄时间',
            value: RecordDetails.formatDateTime(record.capturedAt),
            monospaceDigits: true,
          ),
          if (point != null) ...[
            KeyValueRow(
              label: '片区',
              value: RecordDetails.groupName(plan, point),
              valueLocale: MiriaFonts.japanese,
            ),
            KeyValueRow(
              label: '场景',
              value: point.displayEpisodeLabel,
              valueLocale: MiriaFonts.japanese,
            ),
          ],
          if (record.referenceMode.trim().isNotEmpty)
            KeyValueRow(label: '参考模式', value: record.referenceMode),
          const SizedBox(height: Space.x1),
        ],
      ),
    );
  }
}

class _RecordActions extends StatelessWidget {
  const _RecordActions({
    required this.deleting,
    required this.onGrading,
    required this.onExport,
    required this.onShare,
    required this.onDelete,
  });

  final bool deleting;
  final VoidCallback onGrading;
  final VoidCallback onExport;
  final VoidCallback? onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final narrow = constraints.maxWidth < 340 * scale.clamp(1.0, 1.6);
        final tiles = [
          _ActionTile(
            key: const ValueKey('record-action-grading'),
            icon: Symbols.auto_fix_high_rounded,
            title: '自动调色',
            subtitle: '优化巡礼照片',
            onTap: onGrading,
          ),
          _ActionTile(
            key: const ValueKey('record-action-export'),
            icon: Symbols.ios_share_rounded,
            title: '导出对比图',
            subtitle: '生成分享图片',
            onTap: onExport,
          ),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (narrow) ...[
              tiles[0],
              const SizedBox(height: Space.x2),
              tiles[1],
            ] else
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: tiles[0]),
                    const SizedBox(width: Space.x2),
                    Expanded(child: tiles[1]),
                  ],
                ),
              ),
            const SizedBox(height: Space.x3),
            Wrap(
              spacing: Space.x2,
              runSpacing: Space.x2,
              children: [
                MiriaButton.secondary(
                  key: const ValueKey('record-action-share'),
                  label: '分享或保存照片',
                  shortLabel: '分享',
                  icon: Symbols.share_rounded,
                  onPressed: onShare,
                ),
                MiriaButton.ghost(
                  key: const ValueKey('record-action-delete'),
                  label: '删除记录',
                  icon: Symbols.delete_rounded,
                  loading: deleting,
                  onPressed: deleting ? null : onDelete,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return MiriaCard(
      onTap: onTap,
      semanticLabel: '$title，$subtitle',
      padding: const EdgeInsets.all(Space.x3),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.primaryContainer,
              borderRadius: Radii.smAll,
            ),
            child: Padding(
              padding: const EdgeInsets.all(Space.x2),
              child: Icon(icon, size: 22, color: c.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: text.titleSmall),
                Text(subtitle, style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
