import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/plan_session.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../../application/records/record_details.dart';
import '../../components/components.dart';
import '../records/record_images.dart';
import '../records/records_page.dart' show openRecord;

/// 「点位拍摄记录」: every visit record of one point, newest first (old
/// `PointVisitRecordsScreen`). Follows the plan controller live.
class PointRecordsPage extends StatelessWidget {
  const PointRecordsPage({required this.pointId, super.key});
  final String pointId;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PlanSession>();
    if (!session.isReady) {
      return const MiriaPageScaffold(
        title: '点位拍摄记录',
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final controller = session.controller;
    final records = controller.recordsForPoint(pointId);
    final point = controller.pointById(pointId);
    final snapshot = records.firstOrNull;
    final name = point?.name ?? snapshot?.displayPointNameSnapshot ?? pointId;
    final meta = point != null
        ? '${point.work.title} / ${point.displayEpisodeLabel}'
        : (snapshot?.displayWorkTitleSnapshot ?? '');

    return MiriaPageScaffold(
      title: '点位拍摄记录',
      largeTitle: false,
      slivers: [
        SliverContentColumn(
          top: Space.x2,
          sliver: SliverList.list(
            children: [
              _Header(name: name, meta: meta, count: records.length),
              const SizedBox(height: Space.x4),
              if (records.isEmpty)
                const EmptyState(
                  key: ValueKey('point-records-empty'),
                  icon: Symbols.photo_library_rounded,
                  title: '这个点位还没有拍摄记录',
                  compact: true,
                )
              else ...[
                const SectionHeader(
                  title: '拍摄记录',
                  padding: EdgeInsets.only(bottom: Space.x1),
                ),
                for (final record in records) ...[
                  _RecordCard(
                    record: record,
                    onTap: () => openRecord(context, record.id),
                  ),
                  const SizedBox(height: Space.x3),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.meta, required this.count});

  final String name;
  final String meta;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MiriaCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.primaryContainer,
              borderRadius: Radii.smAll,
            ),
            child: Icon(
              Symbols.photo_library_rounded,
              color: c.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  locale: MiriaFonts.japanese,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleMedium,
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Space.x3),
          Text.rich(
            key: const ValueKey('point-records-count'),
            TextSpan(
              children: [
                TextSpan(
                  text: '$count',
                  style: context.text.headlineSmall?.copyWith(
                    color: c.primaryText,
                    fontWeight: FontWeight.w700,
                    fontFeatures: MiriaFonts.tabular,
                  ),
                ),
                TextSpan(
                  text: ' 条',
                  style: context.text.labelMedium?.copyWith(
                    color: c.primaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.onTap});

  final PilgrimageVisitRecord record;
  final VoidCallback onTap;

  static String _two(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final at = record.capturedAt;
    final time = '${_two(at.hour)}:${_two(at.minute)}';
    final date = '${at.year}-${_two(at.month)}-${_two(at.day)}';
    return MiriaCard(
      key: ValueKey('point-record-${record.id}'),
      padding: EdgeInsets.zero,
      onTap: onTap,
      semanticLabel: '$date $time 的巡礼记录',
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 96),
              child: SizedBox(
                width: 112,
                child: RecordImage(
                  path: RecordDetails.displayPhotoPath(record),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(Space.x3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      time,
                      style: context.text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: MiriaFonts.tabular,
                      ),
                    ),
                    Text(
                      date,
                      style: context.text.caption.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: Space.x2),
                    Wrap(
                      spacing: Space.x1 + 2,
                      runSpacing: Space.x1 + 2,
                      children: [
                        Tag(
                          label: record.referenceMode,
                          icon: Symbols.layers_rounded,
                        ),
                        if (record.hasColorGrading)
                          const Tag(
                            label: '已调色',
                            icon: Symbols.auto_fix_high_rounded,
                            tone: MiriaTone.primary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: Space.x2),
              child: Icon(Symbols.chevron_right_rounded, color: c.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
