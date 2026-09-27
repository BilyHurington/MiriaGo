import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../../app_version.dart';
import '../../../../application/settings/settings_reset.dart';
import '../../../../application/settings_store.dart';
import '../../../app/router.dart';
import '../../../app/toast.dart';
import '../../../components/components.dart';
import '../settings_widgets.dart';

/// 关于 MiriaGo: app info, privacy policy, data & copyright notes and, at
/// the bottom, 「恢复初始设置」 (DESIGN §8.19).
class AboutSettingsSection extends StatefulWidget {
  const AboutSettingsSection({super.key});

  @override
  State<AboutSettingsSection> createState() => _AboutSettingsSectionState();
}

class _AboutSettingsSectionState extends State<AboutSettingsSection> {
  String? _version;

  @override
  void initState() {
    super.initState();
    unawaited(_loadVersion());
  }

  Future<void> _loadVersion() async {
    final label = await loadAppVersionLabel();
    if (!mounted) return;
    setState(() => _version = label);
  }

  Future<void> _confirmReset() async {
    final confirmed = await showConfirmDialog(
      context,
      title: ResetSettingsCopy.title,
      message: ResetSettingsCopy.message,
      confirmLabel: ResetSettingsCopy.confirmLabel,
      notice: ResetSettingsCopy.notice,
      emphasizedValues: ResetSettingsCopy.emphasizedValues,
    );
    if (!confirmed || !mounted) return;
    final store = context.read<SettingsStore>();
    final toasts = context.read<ToastController>();
    try {
      await resetAppSettingsToDefaults(
        store,
        onSaved: () => toasts.show(
          ToastData(kind: ToastKind.success, title: ResetSettingsCopy.done),
        ),
      );
    } catch (error) {
      // Old behaviour: no success toast when saving failed.
      debugPrint('Failed to reset settings: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          title: '应用信息',
          children: [
            SettingsBlock(
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: c.surfaceMuted,
                      borderRadius: Radii.mdAll,
                      border: Border.all(color: c.hairline),
                      boxShadow: Elevations.level1(c),
                    ),
                    child: Image.asset(
                      'icon.jpg',
                      fit: BoxFit.cover,
                      cacheWidth: 174,
                      excludeFromSemantics: true,
                    ),
                  ),
                  const SizedBox(width: Space.x3 + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CopyableText(
                          text: 'MiriaGo',
                          copyLabel: 'MiriaGo',
                          style: text.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '动漫圣地巡礼计划与拍摄参考工具',
                          style: text.bodySmall?.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            InfoLine(
              icon: Symbols.verified_rounded,
              label: '当前版本',
              value: _version ?? '读取中',
            ),
            const InfoLine(
              icon: Symbols.person_rounded,
              label: '作者',
              value: 'BilyHurington',
            ),
            const InfoLine(
              icon: Symbols.mail_rounded,
              label: '联系邮箱',
              value: 'bilyhurington@gmail.com',
            ),
            const InfoLine(
              icon: Symbols.code_rounded,
              label: '开源仓库',
              value: 'github.com/BilyHurington/MiriaGo',
            ),
            const InfoLine(
              icon: Symbols.balance_rounded,
              label: '开源许可',
              value: 'MIT License',
            ),
            ListRow(
              key: const ValueKey('about-privacy-policy'),
              leading: Icon(
                Symbols.verified_user_rounded,
                color: c.textSecondary,
              ),
              title: '隐私政策',
              showChevron: true,
              onTap: () => context.push(Routes.privacy),
            ),
          ],
        ),
        const SettingsGroup(
          title: '数据与版权',
          children: [
            InfoLine(
              icon: Symbols.map_rounded,
              label: '地图',
              value: '可使用 OpenFreeMap、OpenStreetMap 或自定义地图服务。',
              paragraph: true,
            ),
            InfoLine(
              icon: Symbols.search_rounded,
              label: '作品',
              value: '作品搜索数据来自 Bangumi。',
              paragraph: true,
            ),
            InfoLine(
              icon: Symbols.location_on_rounded,
              label: '巡礼内容',
              value: '巡礼点位与参考图来自 Anitabi。',
              paragraph: true,
            ),
            InfoLine(
              icon: Symbols.image_rounded,
              label: '图片源',
              value: '图片源设置只影响访问域名，远端链接统一保留 Anitabi 默认格式。',
              paragraph: true,
            ),
            InfoLine(
              icon: Symbols.copyright_rounded,
              label: '版权归属',
              value: '第三方数据、截图和图片版权归原平台、贡献者或权利方所有。',
              paragraph: true,
            ),
          ],
        ),
        SettingsGroup(
          title: ResetSettingsCopy.title,
          subtitle: '外观、拍摄、地图和数据源设置恢复为默认值',
          children: [
            SettingsBlock(
              child: MiriaButton.secondary(
                key: const ValueKey('settings-reset-button'),
                label: ResetSettingsCopy.title,
                icon: Symbols.restart_alt_rounded,
                expand: true,
                onPressed: _confirmReset,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
