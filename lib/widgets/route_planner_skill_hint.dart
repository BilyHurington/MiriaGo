import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../data/pilgrimage_repository.dart';
import 'confirm_action_dialog.dart';
import 'snackbar_helper.dart';

/// The AI agent skill that plans a pilgrimage and exports a .sjhplan.
const routePlannerSkillUrl =
    'https://github.com/BilyHurington/miriago-route-planner-skill';

const routePlannerSkillTitle = '用 AI 一键规划巡礼行程';

const routePlannerSkillDescription =
    '让 ChatGPT、Claude Code、Codex 等 AI 助手调用 MiriaGo 路线规划 Skill。\n'
    '它会从 Anitabi、Google My Maps 等来源收集作品点位，自动划分区域、规划路线并生成行程备注；'
    '关键步骤会先向你确认，最终导出可直接使用的 .sjhplan 计划包。';

Future<void> _saveRoutePlannerSkillDismissal(
  PilgrimageRepository repository,
) async {
  final settings = await repository.loadAppSettings();
  if (!settings.routePlannerSkillPromotionDismissed) {
    await repository.saveAppSettings(
      settings.copyWith(routePlannerSkillPromotionDismissed: true),
    );
  }
}

Future<void> openRoutePlannerSkillGuide(BuildContext context) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(routePlannerSkillUrl),
      mode: LaunchMode.externalApplication,
    );
  } on Object {
    opened = false;
  }
  if (!opened) {
    messenger?.showStatusSnack(
      kind: AppStatusBannerKind.error,
      title: '无法打开链接',
      subtitle: routePlannerSkillUrl,
    );
  }
}

/// Introduces the skill once, the first time the user adds content.
Future<void> showRoutePlannerSkillIntroDialog(BuildContext context) async {
  final open = await showConfirmActionDialog(
    context,
    title: routePlannerSkillTitle,
    message: routePlannerSkillDescription,
    confirmLabel: '查看使用说明',
    cancelLabel: '知道了',
  );
  if (open && context.mounted) {
    await openRoutePlannerSkillGuide(context);
  }
}

/// Card on the import/export page.
class RoutePlannerSkillCard extends StatefulWidget {
  const RoutePlannerSkillCard({required this.repository, super.key});

  final PilgrimageRepository repository;

  @override
  State<RoutePlannerSkillCard> createState() => _RoutePlannerSkillCardState();
}

class _RoutePlannerSkillCardState extends State<RoutePlannerSkillCard> {
  bool? _dismissed;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadDismissal();
  }

  Future<void> _loadDismissal() async {
    try {
      final settings = await widget.repository.loadAppSettings();
      if (mounted) {
        setState(
          () => _dismissed = settings.routePlannerSkillPromotionDismissed,
        );
      }
    } on Object {
      if (mounted) setState(() => _dismissed = false);
    }
  }

  Future<void> _dismiss() async {
    setState(() => _saving = true);
    try {
      await _saveRoutePlannerSkillDismissal(widget.repository);
      if (mounted) setState(() => _dismissed = true);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showStatusSnack(
          kind: AppStatusBannerKind.error,
          title: '关闭提示失败，请重试。',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed != false) return const SizedBox.shrink();

    return InkWell(
      key: const ValueKey('route-planner-skill-card'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => openRoutePlannerSkillGuide(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.sparkles,
                  color: AppColors.accentDark,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    routePlannerSkillTitle,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('route-planner-skill-dismiss'),
                  tooltip: '关闭',
                  visualDensity: VisualDensity.compact,
                  onPressed: _saving ? null : _dismiss,
                  icon: const Icon(LucideIcons.x, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              routePlannerSkillDescription,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.45,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                '点击查看使用说明',
                key: const ValueKey('route-planner-skill-open'),
                style: TextStyle(
                  color: AppColors.accentDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One-line pointer to the skill, for pages where a card would be too much.
class RoutePlannerSkillLink extends StatefulWidget {
  const RoutePlannerSkillLink({
    required this.lead,
    required this.repository,
    super.key,
  });

  /// Text before the link, e.g. "想省去手动整理？".
  final String lead;
  final PilgrimageRepository repository;

  @override
  State<RoutePlannerSkillLink> createState() => _RoutePlannerSkillLinkState();
}

class _RoutePlannerSkillLinkState extends State<RoutePlannerSkillLink> {
  bool? _dismissed;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadDismissal();
  }

  Future<void> _loadDismissal() async {
    try {
      final settings = await widget.repository.loadAppSettings();
      if (mounted) {
        setState(
          () => _dismissed = settings.routePlannerSkillPromotionDismissed,
        );
      }
    } on Object {
      if (mounted) setState(() => _dismissed = false);
    }
  }

  Future<void> _dismiss() async {
    setState(() => _saving = true);
    try {
      await _saveRoutePlannerSkillDismissal(widget.repository);
      if (mounted) setState(() => _dismissed = true);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showStatusSnack(
          kind: AppStatusBannerKind.error,
          title: '关闭提示失败，请重试。',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed != false) return const SizedBox.shrink();

    final style = TextStyle(
      color: AppColors.textSecondary,
      fontSize: 12,
      height: 1.4,
      letterSpacing: 0,
    );
    return InkWell(
      key: const ValueKey('route-planner-skill-link'),
      borderRadius: BorderRadius.circular(6),
      onTap: () => openRoutePlannerSkillGuide(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                LucideIcons.sparkles,
                size: 14,
                color: AppColors.accentDark,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: style,
                  children: [
                    TextSpan(text: widget.lead),
                    TextSpan(
                      text: '用 AI 一键规划行程并生成计划包',
                      style: TextStyle(
                        color: AppColors.accentDark,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.accentDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('route-planner-skill-link-dismiss'),
              tooltip: '关闭',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              onPressed: _saving ? null : _dismiss,
              icon: const Icon(LucideIcons.x, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}
