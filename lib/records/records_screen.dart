import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../plan/pilgrimage_plan_controller.dart';

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({required this.controller, super.key});

  final PilgrimagePlanController controller;

  @override
  Widget build(BuildContext context) {
    final completedPoints = controller.completedPoints;

    return Scaffold(
      appBar: AppBar(title: const Text('记录')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.collections_bookmark_outlined,
                  color: AppColors.accent,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '今日完成 ${controller.completedCount}/${controller.totalCount}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '已完成点位',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          if (completedPoints.isEmpty)
            const _EmptyRecords()
          else
            for (final point in completedPoints) ...[
              ListTile(
                tileColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppColors.border),
                ),
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.accent,
                ),
                title: Text(point.name),
                subtitle: Text(point.episodeLabel),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _EmptyRecords extends StatelessWidget {
  const _EmptyRecords();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.textSecondary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '还没有完成的巡礼点。',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
