import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/bangumi_api_client.dart';
import '../data/pilgrimage_repository.dart';
import '../widgets/copyable_text.dart';
import '../widgets/snackbar_helper.dart';
import 'add_points_screen.dart';
import 'pilgrimage_models.dart';

class WorkManagerScreen extends StatefulWidget {
  WorkManagerScreen({
    required this.plan,
    required this.repository,
    BangumiApiClient? bangumiApiClient,
    super.key,
  }) : bangumiApiClient = bangumiApiClient ?? BangumiApiClient();

  final PilgrimagePlan plan;
  final PilgrimageRepository repository;
  final BangumiApiClient bangumiApiClient;

  @override
  State<WorkManagerScreen> createState() => _WorkManagerScreenState();
}

class _WorkManagerScreenState extends State<WorkManagerScreen> {
  late PilgrimagePlan _plan = widget.plan;
  var _didUpdate = false;
  var _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final works = _worksForPlan(_plan);

    return PopScope(
      canPop: !_isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }

        Navigator.of(context).pop(_didUpdate);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '返回',
            onPressed: () => Navigator.of(context).pop(_didUpdate),
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('作品管理'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _AddWorkPanel(
              onBangumi: _openBangumiSearch,
              onManual: _openManualWorkForm,
            ),
            const SizedBox(height: 12),
            if (works.isEmpty)
              const _EmptyWorkPanel()
            else
              for (final work in works) ...[
                _WorkManageCard(
                  work: work,
                  pointCount: _plan.points
                      .where((point) => point.work.id == work.id)
                      .length,
                  disabled: _isSaving,
                  onDelete: () => _confirmDeleteWork(work),
                ),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _openBangumiSearch() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BangumiWorkSearchScreen(
          plan: _plan,
          repository: widget.repository,
          bangumiApiClient: widget.bangumiApiClient,
        ),
      ),
    );
    if (mounted) {
      await _reloadPlan();
    }
  }

  Future<void> _openManualWorkForm() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            ManualWorkFormScreen(plan: _plan, repository: widget.repository),
      ),
    );
    if (mounted) {
      await _reloadPlan();
    }
  }

  Future<void> _confirmDeleteWork(PilgrimageWork work) async {
    final pointCount = _plan.points
        .where((point) => point.work.id == work.id)
        .length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除作品'),
        content: Text(
          pointCount == 0
              ? '确定删除「${work.title}」吗？'
              : '确定删除「${work.title}」吗？这会同时移除 $pointCount 个相关点位和对应记录。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updatedPlan = await widget.repository.deleteWorkFromPlan(
        planId: _plan.id,
        workId: work.id,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _plan = updatedPlan;
        _didUpdate = true;
        _isSaving = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showReplacingSnackBar(const SnackBar(content: Text('作品删除失败')));
    }
  }

  Future<void> _reloadPlan() async {
    final plans = await widget.repository.loadPlans();
    final updatedPlan = plans.firstWhere((plan) => plan.id == _plan.id);
    if (!mounted) {
      return;
    }

    setState(() {
      _plan = updatedPlan;
      _didUpdate = true;
    });
  }

  List<PilgrimageWork> _worksForPlan(PilgrimagePlan plan) {
    final worksById = <String, PilgrimageWork>{};
    for (final work in plan.works) {
      worksById[work.id] = work;
    }
    for (final point in plan.points) {
      worksById[point.work.id] = point.work;
    }

    return worksById.values.toList(growable: false);
  }
}

class _AddWorkPanel extends StatelessWidget {
  const _AddWorkPanel({required this.onBangumi, required this.onManual});

  final VoidCallback onBangumi;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: onBangumi,
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Bangumi'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onManual,
              icon: const Icon(Icons.edit_note, size: 18),
              label: const Text('手动添加'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkManageCard extends StatelessWidget {
  const _WorkManageCard({
    required this.work,
    required this.pointCount,
    required this.disabled,
    required this.onDelete,
  });

  final PilgrimageWork work;
  final int pointCount;
  final bool disabled;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final sourceText = work.bangumiId == null ? '手动添加' : 'Bangumi';
    final typeText = work.displayBangumiSubjectType?.label;
    final infoText = [
      work.subtitle,
      ?typeText,
      sourceText,
      '$pointCount 个点位',
    ].where((value) => value.trim().isNotEmpty).join(' / ');

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.movie_filter_outlined, color: AppColors.accentDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CopyableText(
                  text: work.title,
                  copyLabel: '作品名称',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                CopyableText(
                  text: infoText,
                  copyText: [
                    work.title,
                    work.subtitle,
                    ?typeText,
                    sourceText,
                    '$pointCount 个点位',
                  ].where((value) => value.trim().isNotEmpty).join('\n'),
                  copyLabel: '作品信息',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '删除作品',
            onPressed: disabled ? null : onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _EmptyWorkPanel extends StatelessWidget {
  const _EmptyWorkPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.movie_filter_outlined, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                '还没有作品',
                style: TextStyle(
                  color: AppColors.accentDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _WorkOnboardingTimeline(),
        ],
      ),
    );
  }
}

class _WorkOnboardingTimeline extends StatelessWidget {
  const _WorkOnboardingTimeline();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _WorkOnboardingStep(
          title: '从Bangumi导入',
          body:
              '点击上方按钮可从Bangumi搜索你想导入的作品并导入。之后你可以在“从作品地图导入点位”直接查看对应作品在Anitabi上的点位。',
        ),
        _WorkOnboardingStep(
          title: '手动添加作品',
          body:
              '若Bangumi未收录你想要添加到作品，你可以通过“手动添加”将作品加入到计划内。之后你可以通过“手动添加点位”自主上传想要巡礼的点位。',
          isLast: true,
        ),
      ],
    );
  }
}

class _WorkOnboardingStep extends StatelessWidget {
  const _WorkOnboardingStep({
    required this.title,
    required this.body,
    this.isLast = false,
  });

  final String title;
  final String body;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 18,
            child: Stack(
              children: [
                if (!isLast)
                  Positioned(
                    left: 8,
                    top: 10,
                    bottom: 0,
                    child: Container(width: 2, color: AppColors.border),
                  ),
                Positioned(
                  left: 4,
                  top: 5,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    body,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
