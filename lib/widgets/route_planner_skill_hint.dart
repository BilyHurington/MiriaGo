import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import 'confirm_action_dialog.dart';
import 'snackbar_helper.dart';

/// The AI agent skill that plans a pilgrimage and exports a .sjhplan.
const routePlannerSkillUrl =
    'https://github.com/BilyHurington/miriago-route-planner-skill';

const routePlannerSkillTitle = '用 AI 一键规划巡礼行程';

const routePlannerSkillDescription =
    '让 ChatGPT、Claude Code、Codex 等 AI 助手使用 MiriaGo 路线规划 Skill，'
    '它会根据作品从 Anitabi、Google My Maps 等收集点位，划分片区、规划路线并写好行程备注，'
    '关键步骤都会先询问你确认，最后生成可直接导入的 .sjhplan 计划包。';

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
class RoutePlannerSkillCard extends StatelessWidget {
  const RoutePlannerSkillCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('route-planner-skill-card'),
      padding: const EdgeInsets.all(14),
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
              Icon(LucideIcons.sparkles, color: AppColors.accentDark, size: 20),
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
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('route-planner-skill-open'),
              onPressed: () => openRoutePlannerSkillGuide(context),
              icon: const Icon(LucideIcons.externalLink, size: 16),
              label: const Text('查看使用说明'),
            ),
          ),
        ],
      ),
    );
  }
}

/// One-line pointer to the skill, for pages where a card would be too much.
class RoutePlannerSkillLink extends StatelessWidget {
  const RoutePlannerSkillLink({required this.lead, super.key});

  /// Text before the link, e.g. "想省去手动整理？".
  final String lead;

  @override
  Widget build(BuildContext context) {
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
                    TextSpan(text: lead),
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
          ],
        ),
      ),
    );
  }
}
