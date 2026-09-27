import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:provider/provider.dart';

import '../app/toast.dart';
import '../components/components.dart';

/// Component gallery (`/_lab/components`): every Miria component in its
/// key states, switchable between light / dark, text scale 1.0 – 2.0 and
/// a few preview widths. Debug builds and the web preview only.
class ComponentGalleryPage extends StatefulWidget {
  const ComponentGalleryPage({super.key});

  @override
  State<ComponentGalleryPage> createState() => _ComponentGalleryPageState();
}

class _ComponentGalleryPageState extends State<ComponentGalleryPage> {
  bool? _dark;
  double _textScale = 1;
  double? _width;

  @override
  Widget build(BuildContext context) {
    final dark = _dark ?? Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    return Theme(
      data: buildMiriaTheme(dark ? MiriaColors.dark : MiriaColors.light),
      child: Builder(
        builder: (context) {
          final c = context.colors;
          return MiriaPageScaffold(
            title: '组件画廊',
            actions: [
              MiriaIconButton(
                icon: dark
                    ? Symbols.light_mode_rounded
                    : Symbols.dark_mode_rounded,
                tooltip: dark ? '浅色' : '深色',
                onPressed: () => setState(() => _dark = !dark),
              ),
            ],
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: c.surface,
                  padding: EdgeInsets.symmetric(
                    horizontal: context.layout.gutter,
                    vertical: Space.x2,
                  ),
                  child: Wrap(
                    spacing: Space.x4,
                    runSpacing: Space.x2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Labeled(
                        label: '字号',
                        child: SegmentedControl<double>(
                          expand: false,
                          options: const [
                            SegmentOption(value: 1, label: '1.0'),
                            SegmentOption(value: 1.3, label: '1.3'),
                            SegmentOption(value: 2, label: '2.0'),
                          ],
                          value: _textScale,
                          onChanged: (v) => setState(() => _textScale = v),
                        ),
                      ),
                      _Labeled(
                        label: '宽度',
                        child: SegmentedControl<double?>(
                          expand: false,
                          options: const [
                            SegmentOption(value: 320, label: '320'),
                            SegmentOption(value: 390, label: '390'),
                            SegmentOption(value: 720, label: '720'),
                            SegmentOption(value: null, label: '全宽'),
                          ],
                          value: _width,
                          onChanged: (v) => setState(() => _width = v),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: c.hairline),
                Expanded(
                  child: MediaQuery(
                    data: media.copyWith(
                      textScaler: TextScaler.linear(_textScale),
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: _width ?? double.infinity,
                        ),
                        child: const _GalleryBody(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: context.text.labelMedium),
        const SizedBox(width: Space.x2),
        Flexible(child: child),
      ],
    );
  }
}

class _GalleryBody extends StatefulWidget {
  const _GalleryBody();

  @override
  State<_GalleryBody> createState() => _GalleryBodyState();
}

class _GalleryBodyState extends State<_GalleryBody> {
  bool _loading = false;
  bool _switch = true;
  double _slider = 0.4;
  double _logSlider = 8;
  double _vertical = 0.3;
  double _stepper = 3;
  String _segment = 'all';
  String? _single = 'uji';
  Set<String> _multi = {'pending'};
  String? _select = 'google';
  int _selectedRow = 1;
  bool _busy = false;

  static const _reference = AssetImage(
    'docs/sample_images/sample_visit_records/sample-record-byodoin-01.jpg',
  );
  static const _photo = AssetImage(
    'docs/sample_images/sample_visit_records/sample-record-byodoin-02.jpg',
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final gutter = context.layout.gutter;
    return BlockingProgress(
      busy: _busy,
      message: '正在保存…',
      child: ListView(
        padding: EdgeInsets.fromLTRB(gutter, Space.x4, gutter, Space.x16),
        children: [
          _Section(
            title: 'MiriaButton',
            children: [
              Wrap(
                spacing: Space.x2,
                runSpacing: Space.x2,
                children: [
                  for (final v in MiriaButtonVariant.values)
                    MiriaButton(
                      label: v.name,
                      variant: v,
                      icon: Symbols.bolt_rounded,
                      onPressed: () {},
                    ),
                ],
              ),
              Wrap(
                spacing: Space.x2,
                runSpacing: Space.x2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final s in MiriaButtonSize.values)
                    MiriaButton.secondary(
                      label: 'size ${s.name}',
                      size: s,
                      onPressed: () {},
                    ),
                  const MiriaButton(label: '禁用', onPressed: null),
                  MiriaButton(
                    label: _loading ? '保存中' : '点我加载',
                    loading: _loading,
                    onPressed: () async {
                      setState(() => _loading = true);
                      await Future<void>.delayed(const Duration(seconds: 2));
                      if (mounted) setState(() => _loading = false);
                    },
                  ),
                ],
              ),
              const _Caption('响应式收缩：完整 → 短文字 → 仅图标'),
              for (final width in [320.0, 150.0, 60.0])
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.x2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: width,
                      child: MiriaButton(
                        label: '开始今天的巡礼',
                        shortLabel: '开始',
                        icon: Symbols.explore_rounded,
                        expand: true,
                        onPressed: () {},
                      ),
                    ),
                  ),
                ),
              MiriaButton(
                label: '展开宽度 expand',
                variant: MiriaButtonVariant.tonal,
                expand: true,
                onPressed: () {},
              ),
            ],
          ),
          _Section(
            title: 'MiriaIconButton · SplitNavButton',
            children: [
              Wrap(
                spacing: Space.x2,
                runSpacing: Space.x2,
                children: [
                  MiriaIconButton(
                    icon: Symbols.layers_rounded,
                    tooltip: '叠影',
                    onPressed: () {},
                  ),
                  MiriaIconButton(
                    icon: Symbols.layers_rounded,
                    tooltip: '叠影（已选）',
                    selected: true,
                    onPressed: () {},
                  ),
                  MiriaIconButton(
                    icon: Symbols.filter_list_rounded,
                    tooltip: '筛选',
                    variant: MiriaIconButtonVariant.filled,
                    badgeCount: 3,
                    onPressed: () {},
                  ),
                  MiriaIconButton(
                    icon: Symbols.my_location_rounded,
                    tooltip: '定位',
                    variant: MiriaIconButtonVariant.overlay,
                    badgeDot: true,
                    onPressed: () {},
                  ),
                  MiriaIconButton(
                    icon: Symbols.photo_camera_rounded,
                    tooltip: '拍摄',
                    variant: MiriaIconButtonVariant.primary,
                    onPressed: () {},
                  ),
                  const MiriaIconButton(
                    icon: Symbols.delete_rounded,
                    tooltip: '删除（禁用）',
                    onPressed: null,
                  ),
                ],
              ),
              SplitNavButton(onNavigate: () {}, onOpenExternal: () {}),
              const SplitNavButton(
                available: false,
                onNavigate: null,
                onOpenExternal: null,
              ),
            ],
          ),
          _Section(
            title: 'Inputs',
            children: [
              const SearchField(hint: '搜索点位'),
              const MiriaTextField(
                label: '点位名称',
                hint: '例如：宇治橋',
                required: true,
                helper: '显示在地图和列表中',
              ),
              const MiriaTextField(label: '备注', error: '备注不能超过 200 字'),
              SelectField<String>(
                label: '外部地图',
                value: _select,
                options: const [
                  SelectOption(value: 'apple', label: 'Apple 地图'),
                  SelectOption(value: 'google', label: 'Google 地图'),
                  SelectOption(value: 'amap', label: '高德地图', subtitle: '仅中国大陆'),
                ],
                onChanged: (v) => setState(() => _select = v),
              ),
              SegmentedControl<String>(
                options: const [
                  SegmentOption(value: 'all', label: '全部'),
                  SegmentOption(value: 'pending', label: '待访问'),
                  SegmentOption(value: 'done', label: '已完成'),
                ],
                value: _segment,
                onChanged: (v) => setState(() => _segment = v),
              ),
              SegmentedControl<String>(
                forceStacked: true,
                options: const [
                  SegmentOption(value: 'all', label: '全部点位'),
                  SegmentOption(value: 'pending', label: '只看待访问'),
                  SegmentOption(value: 'done', label: '只看已完成'),
                ],
                value: _segment,
                onChanged: (v) => setState(() => _segment = v),
              ),
              ChipGroup<String>.single(
                scrollable: true,
                options: [
                  ChipOption(
                    value: 'uji',
                    label: '宇治',
                    color: c.groupColor(0),
                    count: 12,
                  ),
                  ChipOption(
                    value: 'kyoto',
                    label: '京都市区',
                    color: c.groupColor(1),
                    count: 8,
                  ),
                  ChipOption(
                    value: 'osaka',
                    label: '大阪',
                    color: c.groupColor(2),
                    count: 5,
                  ),
                  ChipOption(
                    value: 'nara',
                    label: '奈良',
                    color: c.groupColor(3),
                    count: 2,
                  ),
                ],
                value: _single,
                onSelected: (v) => setState(() => _single = v),
              ),
              ChipGroup<String>(
                options: const [
                  ChipOption(value: 'pending', label: '待访问'),
                  ChipOption(value: 'current', label: '当前目标'),
                  ChipOption(value: 'done', label: '已完成'),
                  ChipOption(
                    value: 'nophoto',
                    label: '无参考图',
                    icon: Symbols.hide_image_rounded,
                  ),
                ],
                selected: _multi,
                onChanged: (v) => setState(() => _multi = v),
              ),
            ],
          ),
          _Section(
            title: 'Rows · Controls',
            flush: true,
            children: [
              SwitchRow(
                title: '显示参考图缩略图',
                subtitle: '在地图上用参考图代替圆点',
                leading: const Icon(Symbols.image_rounded),
                value: _switch,
                onChanged: (v) => setState(() => _switch = v),
              ),
              const SwitchRow(title: '禁用的开关', value: false, onChanged: null),
              SliderRow(
                title: '叠影透明度',
                value: _slider,
                divisions: 20,
                format: (v) => '${(v * 100).round()}%',
                onChanged: (v) => setState(() => _slider = v),
              ),
              SliderRow(
                title: '缓存上限（对数刻度）',
                value: _logSlider,
                min: 1,
                max: 1000,
                logScale: true,
                format: (v) => '${v.round()} MB',
                onChanged: (v) => setState(() => _logSlider = v),
              ),
              Padding(
                padding: const EdgeInsets.all(Space.x4),
                child: Wrap(
                  spacing: Space.x3,
                  runSpacing: Space.x3,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    MiriaStepper(
                      value: _stepper,
                      min: 1,
                      max: 6,
                      semanticLabel: '每行图片数',
                      onChanged: (v) => setState(() => _stepper = v),
                    ),

                    Container(
                      padding: const EdgeInsets.all(Space.x2),
                      decoration: BoxDecoration(
                        color: c.darkroom,
                        borderRadius: Radii.lgAll,
                      ),
                      child: MiriaVerticalSlider(
                        value: _vertical,
                        height: 160,
                        semanticLabel: '变焦',
                        onChanged: (v) => setState(() => _vertical = v),
                      ),
                    ),

                    MiriaVerticalSlider(
                      value: _vertical,
                      height: 160,
                      onDark: false,
                      semanticLabel: '曝光',
                      onChanged: (v) => setState(() => _vertical = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _Section(
            title: 'ListRow · RouteLine · SectionHeader',
            flush: true,
            children: [
              SectionHeader(
                title: '宇治',
                count: 4,
                actionLabel: '全部',
                onAction: () {},
              ),
              for (final (i, (name, status)) in const [
                ('宇治橋', VisitStatus.completed),
                ('京阪宇治駅前', VisitStatus.completed),
                ('大吉山展望台', VisitStatus.current),
                ('あがた通り', VisitStatus.pending),
              ].indexed)
                ListRow(
                  title: name,
                  titleLocale: MiriaFonts.japanese,
                  subtitle: '第 ${i + 1} 站 · 约 ${350 * (i + 1)} m',
                  selected: _selectedRow == i,
                  routeLine: RouteLine(
                    status: status,
                    isFirst: i == 0,
                    isLast: i == 3,
                    previousCompleted: i > 0,
                  ),
                  trailing: StatusBadge(status: status),
                  onTap: () => setState(() => _selectedRow = i),
                  contextActions: [
                    MenuAction(
                      label: '设为当前目标',
                      icon: Symbols.flag_rounded,
                      onSelected: () {},
                    ),
                    MenuAction(
                      label: '删除点位',
                      icon: Symbols.delete_rounded,
                      destructive: true,
                      onSelected: () {},
                    ),
                  ],
                ),
              ListRow(
                title: '一个很长很长的标题，用来检查在窄屏和两倍字号下是否会正确换行而不是溢出',
                subtitle: '副标题同样可以换行，最多两行后省略。',
                leading: const Icon(Symbols.folder_rounded),
                showChevron: true,
                onTap: () {},
              ),
              const ListRow(title: '禁用的行', subtitle: '不可点击', enabled: false),
            ],
          ),
          _Section(
            title: 'KeyValueRow · CopyableText',
            flush: true,
            children: [
              const KeyValueRow(
                label: '坐标',
                value: '34.889412, 135.807736',
                monospaceDigits: true,
              ),
              const KeyValueRow(label: '来源', value: 'Anitabi'),
              const KeyValueRow(label: '拍摄时间', value: '2026-09-27 14:32'),
              Padding(
                padding: const EdgeInsets.all(Space.x4),
                child: CopyableText(
                  text: '宇治橋',
                  copyLabel: '点位名称',
                  locale: MiriaFonts.japanese,
                  style: context.text.titleMedium,
                ),
              ),
            ],
          ),
          _Section(
            title: 'Status · Tag · Count · RouteDots · ProgressRing',
            children: [
              const Wrap(
                spacing: Space.x2,
                runSpacing: Space.x2,
                children: [
                  StatusBadge(status: VisitStatus.pending),
                  StatusBadge(status: VisitStatus.current),
                  StatusBadge(status: VisitStatus.completed),
                ],
              ),
              Wrap(
                spacing: Space.x2,
                runSpacing: Space.x2,
                children: [
                  Tag(label: '宇治', color: c.groupColor(0)),
                  Tag(label: '京都', color: c.groupColor(4)),
                  for (final tone in MiriaTone.values)
                    Tag(label: tone.name, tone: tone),
                  const CountBubble(count: 7),
                  const CountBubble(count: 27, tone: MiriaTone.primary),
                  const CountBubble(count: 1200, tone: MiriaTone.spot),
                ],
              ),
              RouteDots.counts(completed: 3, total: 8, hasCurrent: true),
              RouteDots.counts(completed: 12, total: 30),
              const Wrap(
                spacing: Space.x4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ProgressRing(value: 0.35),
                  ProgressRing(value: 0.8, size: 48, child: Text('12')),
                  ProgressRing(),
                  Sparkle(size: 20),
                  RouteMotif(),
                ],
              ),
            ],
          ),
          _Section(
            title: 'InfoBanner',
            children: [
              const InfoBanner(
                message: '参考图已全部缓存，可以离线使用。',
                kind: InfoBannerKind.success,
              ),
              InfoBanner(
                kind: InfoBannerKind.warning,
                title: '有 3 张参考图未缓存',
                message: '离线时这些点位不会显示参考图。',
                actionLabel: '立即缓存',
                onAction: () {},
                onDismiss: () {},
              ),
              const InfoBanner(
                message: '无法连接 Anitabi，请检查网络。',
                kind: InfoBannerKind.error,
              ),
              const InfoBanner(message: '长按点位可以打开更多操作。'),
            ],
          ),
          _Section(
            title: 'EmptyState · ErrorState · Skeleton',
            children: [
              EmptyState(
                icon: Symbols.photo_library_rounded,
                title: '还没有巡礼记录',
                message: '在巡礼页拍摄后，记录会出现在这里。',
                actionLabel: '去巡礼',
                onAction: () {},
                secondaryActionLabel: '导入记录',
                onSecondaryAction: () {},
              ),
              ErrorState(detail: '请检查网络后重试；已缓存的参考图仍可离线查看。', onRetry: () {}),
              const Row(
                children: [
                  Skeleton.circle(size: 44),
                  SizedBox(width: Space.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton.line(height: 14),
                        Skeleton.line(widthFactor: 0.6),
                      ],
                    ),
                  ),
                ],
              ),
              const Skeleton.box(height: 140),
            ],
          ),
          _Section(
            title: 'PhotoCompare',
            children: [
              PhotoCompare.images(
                reference: _reference,
                photo: _photo,
                onTapReference: () => context.showToastSafe('点了参考图'),
                onTapPhoto: () => context.showToastSafe('点了巡礼图'),
              ),
            ],
          ),
          _Section(
            title: 'MiriaCard · GlassPanel · SheetHandle',
            children: [
              MiriaCard(
                onTap: () {},
                child: const _TileText(title: '可点击的卡片', subtitle: '悬停时描边加深并浮起'),
              ),
              const MiriaCard(
                selected: true,
                child: _TileText(title: '选中的卡片', subtitle: '主色描边 + 浅底'),
              ),
              ClipRRect(
                borderRadius: Radii.lgAll,
                child: SizedBox(
                  height: 160,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const Image(image: _reference, fit: BoxFit.cover),
                      Center(
                        child: Wrap(
                          spacing: Space.x3,
                          runSpacing: Space.x3,
                          alignment: WrapAlignment.center,
                          children: [
                            const GlassPanel(child: Text('GlassPanel')),
                            GlassPanel(
                              translucent: false,
                              child: Text(
                                '不透明回退',
                                style: context.text.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SheetHandle(),
            ],
          ),
          _Section(
            title: 'Adaptive modals',
            children: [
              Wrap(
                spacing: Space.x2,
                runSpacing: Space.x2,
                children: [
                  MiriaButton.secondary(
                    label: 'Sheet',
                    onPressed: () => showAdaptiveSheet<void>(
                      context,
                      title: '选择片区',
                      builder: (context) => Column(
                        children: [
                          for (var i = 0; i < 6; i++)
                            ListRow(
                              title: '片区 ${i + 1}',
                              leading: Icon(
                                Symbols.folder_rounded,
                                color: c.groupColor(i),
                              ),
                              onTap: () => Navigator.pop(context),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Builder(
                    builder: (anchor) => MiriaButton.secondary(
                      label: 'Menu',
                      trailingIcon: Symbols.expand_more_rounded,
                      onPressed: () => showActionMenu(
                        anchor,
                        anchor: anchor,
                        actions: [
                          MenuAction(
                            label: '重命名',
                            icon: Symbols.edit_rounded,
                            onSelected: () {},
                          ),
                          MenuAction(
                            label: '复制计划',
                            icon: Symbols.content_copy_rounded,
                            subtitle: '包括所有片区和点位',
                            onSelected: () {},
                          ),
                          MenuAction(
                            label: '删除',
                            icon: Symbols.delete_rounded,
                            destructive: true,
                            onSelected: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                  MiriaButton.secondary(
                    label: 'Confirm',
                    onPressed: () => showConfirmDialog(
                      context,
                      title: '设为当前目标',
                      message: '将「大吉山展望台」设为当前目标？',
                      confirmLabel: '设为目标',
                      emphasizedValues: const ['大吉山展望台'],
                      notice: '当前目标会显示在巡礼页顶部。',
                    ),
                  ),
                  MiriaButton.danger(
                    label: 'Destructive',
                    onPressed: () => showConfirmDialogWithCheckbox(
                      context,
                      title: '删除记录',
                      message: '确定删除这条巡礼记录吗？',
                      confirmLabel: '删除',
                      destructive: true,
                      emphasizedValues: const ['这条巡礼记录'],
                      checkboxLabel: '同时删除照片文件',
                    ),
                  ),
                  MiriaButton.secondary(
                    label: 'Input',
                    onPressed: () => showInputDialog(
                      context,
                      title: '重命名片区',
                      label: '片区名称',
                      initialValue: '宇治',
                      confirmLabel: '保存',
                      showPasteButton: true,
                      validator: (v) => v.isEmpty ? '请输入片区名称' : null,
                    ),
                  ),
                  MiriaButton.secondary(
                    label: 'Panel',
                    onPressed: () => showAdaptivePanel<void>(
                      context,
                      title: '导出对比图',
                      actions: [
                        MiriaButton(
                          label: '导出',
                          size: MiriaButtonSize.sm,
                          onPressed: () {},
                        ),
                      ],
                      builder: (context) => EditorLayout(
                        preview: const Padding(
                          padding: EdgeInsets.all(Space.x4),
                          child: Center(child: Image(image: _reference)),
                        ),
                        controls: ListView(
                          children: [
                            SwitchRow(
                              title: '显示点位名称',
                              value: true,
                              onChanged: (_) {},
                            ),
                            SliderRow(
                              title: '间距',
                              value: 0.3,
                              onChanged: (_) {},
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  MiriaButton.secondary(
                    label: 'Blocking',
                    onPressed: () => showBlockingProgress<void>(
                      context,
                      message: '正在保存记录…',
                      task: () =>
                          Future<void>.delayed(const Duration(seconds: 2)),
                    ),
                  ),
                  MiriaButton.secondary(
                    label: 'Inline busy',
                    onPressed: () async {
                      setState(() => _busy = true);
                      await Future<void>.delayed(const Duration(seconds: 2));
                      if (mounted) setState(() => _busy = false);
                    },
                  ),
                ],
              ),
              ContextMenuRegion(
                actions: [
                  MenuAction(
                    label: '复制',
                    icon: Symbols.content_copy_rounded,
                    onSelected: () {},
                  ),
                ],
                child: Container(
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.surfaceMuted,
                    borderRadius: Radii.mdAll,
                  ),
                  child: Text(
                    'ContextMenuRegion：长按或右键',
                    style: context.text.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
          _Section(
            title: 'AdaptiveGrid · ListDetailLayout · EditorLayout',
            children: [
              AdaptiveGrid(
                children: [
                  for (var i = 0; i < 5; i++)
                    MiriaCard(
                      onTap: () {},
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image(image: _photo, fit: BoxFit.cover),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(Space.x3),
                            child: Text(
                              '记录 ${i + 1}',
                              style: context.text.titleSmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              SizedBox(
                height: 240,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: c.hairline),
                  ),
                  child: ListDetailLayout(
                    forceSinglePane: false,
                    initialListWidth: 180,
                    minListWidth: 140,
                    list: ListView(
                      children: [
                        for (var i = 0; i < 4; i++)
                          ListRow(
                            title: '设置项 ${i + 1}',
                            selected: i == 0,
                            onTap: () {},
                          ),
                      ],
                    ),
                    detailPlaceholder: const EmptyState(
                      compact: true,
                      icon: Symbols.touch_app_rounded,
                      title: '选择一项',
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 260,
                child: EditorLayout(
                  controlsWidth: 200,
                  preview: const Center(child: Text('预览')),
                  controls: ListView(
                    children: [
                      SliderRow(title: '亮度', value: 0.5, onChanged: (_) {}),
                      SliderRow(title: '对比度', value: 0.5, onChanged: (_) {}),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.flush = false,
  });

  final String title;
  final List<Widget> children;

  /// Rows edge to edge inside the card (no inner padding / gaps).
  final bool flush;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: Space.x1, bottom: Space.x2),
            child: Text(
              title,
              style: context.text.titleSmall?.copyWith(color: c.textSecondary),
            ),
          ),
          MiriaCard(
            padding: flush ? EdgeInsets.zero : const EdgeInsets.all(Space.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0 && !flush) const SizedBox(height: Space.x3),
                  if (i > 0 && flush)
                    Divider(height: 1, color: c.hairline, indent: Space.x4),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: context.text.caption);
}

class _TileText extends StatelessWidget {
  const _TileText({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.text.titleSmall),
        const SizedBox(height: 2),
        Text(subtitle, style: context.text.bodySmall),
      ],
    );
  }
}

extension on BuildContext {
  void showToastSafe(String message) {
    Provider.of<ToastController?>(
      this,
      listen: false,
    )?.show(ToastData(kind: ToastKind.info, title: message));
  }
}
