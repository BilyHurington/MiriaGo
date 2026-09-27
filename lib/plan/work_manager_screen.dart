import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_theme.dart';
import '../data/bangumi_api_client.dart';
import '../data/pilgrimage_repository.dart';
import '../widgets/copyable_text.dart';
import '../widgets/confirm_action_dialog.dart';
import '../widgets/snackbar_helper.dart';
import '../widgets/app_scaled_route.dart';
import '../widgets/app_back_button.dart';
import 'add_points_screen.dart';
import 'pilgrimage_models.dart';
import 'pilgrimage_work_cover.dart';

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
          leading: AppBackButton(
            onPressed: () => Navigator.of(context).pop(_didUpdate),
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

  Future<bool> _confirmDeleteWork(PilgrimageWork work) async {
    final pointCount = _plan.points
        .where((point) => point.work.id == work.id)
        .length;
    final confirmed = await showConfirmActionDialog(
      context,
      title: '删除作品',
      message: pointCount == 0
          ? '将删除「${work.title}」。'
          : '将删除「${work.title}」，并同时移除 $pointCount 个相关点位和对应记录。',
      confirmLabel: '删除',
      destructive: true,
      emphasizedValues: [work.title],
    );
    if (!confirmed || !mounted) {
      return false;
    }

    setState(() => _isSaving = true);
    try {
      final updatedPlan = await widget.repository.deleteWorkFromPlan(
        planId: _plan.id,
        workId: work.id,
      );
      if (!mounted) {
        return false;
      }

      setState(() {
        _plan = updatedPlan;
        _didUpdate = true;
        _isSaving = false;
      });
      return true;
    } catch (_) {
      if (!mounted) {
        return false;
      }

      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showStatusSnack(kind: AppStatusBannerKind.error, title: '作品删除失败');
      return false;
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
                key: const ValueKey('work-manager-bangumi-work'),
                icon: LucideIcons.search,
                title: '从Bangumi添加',
                subtitle: '自动获取信息',
                onTap: onBangumi,
              ),
            ),
            VerticalDivider(
              width: 9,
              indent: 8,
              endIndent: 8,
              color: AppColors.border,
            ),
            Expanded(
              child: _AddWorkAction(
                key: const ValueKey('work-manager-manual-work'),
                icon: LucideIcons.edit,
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
    super.key,
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
                        style: TextStyle(
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          PilgrimageWorkCover(work: work),
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
                _WorkBadges(
                  key: ValueKey('work-manage-badges-${work.id}'),
                  work: work,
                  pointCount: pointCount,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
            key: ValueKey('work-manage-more-${work.id}'),
            tooltip: '更多操作',
            enabled: !widget.disabled,
            icon: const Icon(LucideIcons.ellipsis),
            iconSize: 20,
            padding: EdgeInsets.zero,
            position: PopupMenuPosition.under,
            offset: const Offset(0, 6),
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.16),
            color: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: AppColors.border),
            ),
            constraints: const BoxConstraints(minWidth: 148, maxWidth: 180),
            style: IconButton.styleFrom(
              minimumSize: const Size.square(34),
              maximumSize: const Size.square(34),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onSelected: (_) => widget.onDelete(),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                key: const ValueKey('work-action-delete'),
                value: 'delete',
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(LucideIcons.trash2, size: 18, color: AppColors.error),
                    const SizedBox(width: 9),
                    Text(
                      '删除作品',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkBadges extends StatelessWidget {
  const _WorkBadges({required this.work, required this.pointCount, super.key});

  final PilgrimageWork work;
  final int pointCount;

  @override
  Widget build(BuildContext context) {
    final isBangumiWork = work.bangumiId != null;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (work.displayBangumiSubjectType != null) ...[
            _WorkManageBadge(label: work.displayBangumiSubjectType!.label),
            const SizedBox(width: 6),
          ],
          _WorkManageBadge(
            label: isBangumiWork ? 'Bangumi' : '手动添加',
            emphasized: isBangumiWork,
          ),
          const SizedBox(width: 6),
          _WorkManageBadge(label: '$pointCount 个点位'),
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
        maxLines: 1,
        softWrap: false,
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
              Icon(LucideIcons.clapperboard, color: AppColors.accent),
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
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    body,
                    style: TextStyle(
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
