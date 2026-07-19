import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/bangumi_api_client.dart';
import '../data/pilgrimage_repository.dart';
import '../widgets/copyable_text.dart';
import '../widgets/snackbar_helper.dart';
import '../widgets/app_scaled_route.dart';
import 'add_points_screen.dart';
import 'pilgrimage_models.dart';

class WorkManagerScreen extends StatefulWidget {
  WorkManagerScreen({
    required this.plan,
    required this.repository,
    required this.settings,
    BangumiApiClient? bangumiApiClient,
    super.key,
  }) : bangumiApiClient = bangumiApiClient ?? BangumiApiClient();

  final PilgrimagePlan plan;
  final PilgrimageRepository repository;
  final AppSettings settings;
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
      appScaledMaterialPageRoute<bool>(
        settings: widget.settings,
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
      appScaledMaterialPageRoute<bool>(
        settings: widget.settings,
        builder: (_) => ManualWorkFormScreen(
          plan: _plan,
          repository: widget.repository,
          settings: widget.settings,
        ),
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: SizedBox(
        height: 56,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _AddWorkAction(
                icon: Icons.search_rounded,
                title: '从Bangumi添加',
                subtitle: '自动获取信息',
                onTap: onBangumi,
              ),
            ),
            const VerticalDivider(
              width: 9,
              indent: 8,
              endIndent: 8,
              color: AppColors.border,
            ),
            Expanded(
              child: _AddWorkAction(
                icon: Icons.edit_rounded,
                title: '手动添加作品',
                subtitle: '未收录时使用',
                onTap: onManual,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddWorkAction extends StatelessWidget {
  const _AddWorkAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.textPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkManageCard extends StatefulWidget {
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
  State<_WorkManageCard> createState() => _WorkManageCardState();
}

class _WorkManageCardState extends State<_WorkManageCard> {
  var _titleExpanded = false;

  @override
  Widget build(BuildContext context) {
    final work = widget.work;
    final pointCount = widget.pointCount;
    final subtitle = work.subtitle.trim();
    final showSubtitle =
        subtitle.isNotEmpty &&
        subtitle != work.title.trim() &&
        !subtitle.startsWith('Bangumi #') &&
        subtitle != 'Manual Work' &&
        subtitle != '暂无作品原名';
    final isBangumiWork = work.bangumiId != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Semantics(
            label: '作品封面预留',
            child: Container(
              width: 58,
              height: 78,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CopyableText(
                  text: work.title,
                  copyLabel: '作品名称',
                  maxLines: _titleExpanded ? null : 1,
                  overflow: _titleExpanded
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  onTap: () {
                    setState(() {
                      _titleExpanded = !_titleExpanded;
                    });
                  },
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                CopyableText(
                  text: showSubtitle ? subtitle : '暂无作品原名',
                  copyText: [
                    work.title,
                    if (showSubtitle) subtitle,
                  ].where((value) => value.trim().isNotEmpty).join('\n'),
                  copyLabel: '作品信息',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: showSubtitle
                        ? AppColors.textSecondary
                        : AppColors.textSecondary.withValues(alpha: 0.55),
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (work.displayBangumiSubjectType != null)
                      _WorkManageBadge(
                        label: work.displayBangumiSubjectType!.label,
                      ),
                    _WorkManageBadge(
                      label: isBangumiWork ? 'Bangumi' : '手动添加',
                      emphasized: isBangumiWork,
                    ),
                    _WorkManageBadge(label: '$pointCount 个点位'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: widget.disabled ? null : widget.onDelete,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(88, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              foregroundColor: Colors.redAccent,
              side: BorderSide(
                color: widget.disabled
                    ? AppColors.border
                    : Colors.redAccent.withValues(alpha: 0.65),
              ),
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _WorkManageBadge extends StatelessWidget {
  const _WorkManageBadge({required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: emphasized
            ? AppColors.accent.withValues(alpha: 0.08)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: emphasized
              ? AppColors.accent.withValues(alpha: 0.42)
              : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: emphasized ? AppColors.accentDark : AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
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
