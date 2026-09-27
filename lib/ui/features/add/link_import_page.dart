import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/plan_session.dart';
import '../../../application/settings_store.dart';
import '../../../data/anitabi_link_parser.dart';
import '../../app/router.dart';
import '../../app/toast.dart';
import '../../components/components.dart';
import 'add_widgets.dart';

/// Validates an Anitabi link (old `_validateLink`).
String? validateAnitabiLink(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return '请输入 Anitabi 链接';
  final link = parseAnitabiImportLink(text);
  if (link == null) return '请输入有效的 Anitabi 地图链接';
  if (link.bangumiId == null) {
    return '链接缺少作品 ID，请先在 Anitabi 进入对应作品后复制链接';
  }
  return null;
}

/// 「Anitabi 链接导入」 (old `_AnitabiLinkImportScreen`).
class LinkImportPage extends StatefulWidget {
  const LinkImportPage({super.key});

  @override
  State<LinkImportPage> createState() => _LinkImportPageState();
}

class _LinkImportPageState extends State<LinkImportPage> {
  final _formKey = GlobalKey<FormState>();
  final _link = TextEditingController();

  @override
  void initState() {
    super.initState();
    _link.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _link.removeListener(_changed);
    _link.dispose();
    super.dispose();
  }

  void _clear() {
    _link.clear();
    _formKey.currentState?.reset();
  }

  Future<void> _paste() async {
    ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } catch (_) {
      if (mounted) {
        context.showToast('无法读取剪贴板，请手动粘贴 Anitabi 链接。', kind: ToastKind.warning);
      }
      return;
    }
    if (!mounted) return;
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      context.showToast('剪贴板中没有可用的 Anitabi 链接。', kind: ToastKind.warning);
      return;
    }
    _link.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _formKey.currentState?.validate();
  }

  Future<void> _open() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    final link = parseAnitabiImportLink(_link.text);
    final bangumiId = link?.bangumiId;
    if (link == null || bangumiId == null) return;
    final session = context.read<PlanSession>();
    final before = session.isReady ? session.plan.points.length : null;
    await context.push<void>(
      Routes.anitabiImportFor(bangumiId: bangumiId, pointId: link.pointId),
    );
    if (!mounted || before == null || !session.isReady) return;
    // Old: leave the link page once points were imported.
    if (session.plan.points.length != before && context.canPop()) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PlanSession>();
    final siteBaseUrl = context.select<SettingsStore, String>(
      (s) => s.settings.anitabiSiteBaseUrl,
    );
    final hasText = _link.text.isNotEmpty;
    return MiriaPageScaffold(
      title: 'Anitabi 链接导入',
      subtitle: session.isReady ? '加入到：${session.plan.name}' : null,
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(top: Space.x2, bottom: Space.x8),
          children: [
            ContentColumn(
              maxWidth: 640,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AddFormSection(
                    title: 'Anitabi 链接',
                    children: [
                      MiriaTextField(
                        key: const ValueKey('anitabi-link-field'),
                        controller: _link,
                        hint: '粘贴 Anitabi 作品或点位链接',
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.done,
                        validator: validateAnitabiLink,
                        onSubmitted: (_) => _open(),
                        suffix: MiriaIconButton(
                          key: const ValueKey('anitabi-link-input-action'),
                          icon: hasText
                              ? Symbols.close_rounded
                              : Symbols.content_paste_rounded,
                          tooltip: hasText ? '清除搜索框' : '粘贴',
                          compact: true,
                          onPressed: hasText ? _clear : _paste,
                        ),
                      ),
                      const SizedBox(height: Space.x3),
                      MiriaButton(
                        key: const ValueKey('anitabi-link-open'),
                        label: '打开 Anitabi 点位',
                        icon: Symbols.add_location_alt_rounded,
                        size: MiriaButtonSize.lg,
                        expand: true,
                        onPressed: _open,
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.x4),
                  _LinkExampleCard(siteBaseUrl: siteBaseUrl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkExampleCard extends StatelessWidget {
  const _LinkExampleCard({required this.siteBaseUrl});

  final String siteBaseUrl;
  static const _bangumiId = 'bangumiId=186515';
  static const _middle = '&';
  static const _pointId = 'pid=95ff4037';
  static const _suffix = '&c=139.7226%2C35.7126&z=19.1';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final mono = text.bodySmall!.copyWith(
      color: c.textSecondary,
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Menlo', 'Consolas', 'Roboto Mono'],
    );
    Widget highlight(String value) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: c.primaryContainer,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      child: Text(
        value,
        style: mono.copyWith(
          color: c.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    Widget note(String value) => Padding(
      padding: const EdgeInsets.only(top: Space.x1, bottom: Space.x2),
      child: Row(
        children: [
          Icon(
            Symbols.subdirectory_arrow_right_rounded,
            size: 16,
            color: c.textTertiary,
          ),
          const SizedBox(width: Space.x1),
          Flexible(child: Tag(label: value)),
        ],
      ),
    );
    return AddFormSection(
      title: '有效链接示例',
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: Space.x1,
          children: [
            Text('$siteBaseUrl/map?', style: mono),
            highlight(_bangumiId),
            Text(_middle, style: mono),
          ],
        ),
        note('Bangumi 作品 ID（必须）'),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: Space.x1,
          children: [
            highlight(_pointId),
            Text(_suffix, style: mono),
          ],
        ),
        note('Anitabi 点位 ID（可选）'),
        const SizedBox(height: Space.x1),
        Text(
          '如果链接里包含作品 ID，会只加载对应作品；\n如果还包含点位 ID，会自动选中该点位。\n没有作品 ID 的链接需要先在 Anitabi 中进入对应作品后重新复制。',
          style: text.bodySmall?.copyWith(color: c.textSecondary, height: 1.45),
        ),
      ],
    );
  }
}
