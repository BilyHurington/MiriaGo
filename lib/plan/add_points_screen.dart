import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'pilgrimage_models.dart';

class AddPointsScreen extends StatelessWidget {
  const AddPointsScreen({required this.plan, super.key});

  final PilgrimagePlan? plan;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加点位')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (plan != null) ...[
            Text(
              '加入到：${plan!.name}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 12),
          ],
          _AddSourceCard(
            icon: Icons.travel_explore,
            title: '从 Anitabi 添加',
            body: '输入 Bangumi / Anitabi ID，拉取作品点位后选择加入计划。',
            enabled: false,
          ),
          const SizedBox(height: 8),
          _AddSourceCard(
            icon: Icons.add_location_alt_outlined,
            title: '手动添加点位',
            body: '输入名称和坐标，创建自定义巡礼点。',
            enabled: false,
          ),
        ],
      ),
    );
  }
}

class _AddSourceCard extends StatelessWidget {
  const _AddSourceCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.enabled,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: enabled ? AppColors.accent : AppColors.textSecondary,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            '待实现',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
