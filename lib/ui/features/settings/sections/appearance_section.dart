import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../../application/settings/settings_options.dart';
import '../../../../application/settings_store.dart';
import '../../../../plan/pilgrimage_models.dart';
import '../../../components/components.dart';
import '../settings_widgets.dart';

/// 外观设置: theme mode, theme colour, page zoom, font size, plan options
/// and a live preview. The hidden 「点击空白收回计划操作」 is Δ12.
class AppearanceSettingsSection extends StatelessWidget {
  const AppearanceSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsStore>();
    final settings = store.settings;
    final fontPreset = FontSizePreset.of(settings.fontScale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          title: '主题模式',
          subtitle: '影响应用整体浅色或深色显示',
          children: [
            SettingsBlock(
              child: SegmentedControl<AppThemeMode>(
                semanticLabel: '主题模式',
                options: const [
                  SegmentOption(
                    value: AppThemeMode.light,
                    label: '浅色',
                    icon: Symbols.light_mode_rounded,
                  ),
                  SegmentOption(
                    value: AppThemeMode.dark,
                    label: '深色',
                    icon: Symbols.dark_mode_rounded,
                  ),
                  SegmentOption(
                    value: AppThemeMode.system,
                    label: '跟随系统',
                    icon: Symbols.smartphone_rounded,
                  ),
                ],
                value: settings.themeMode,
                onChanged: (mode) =>
                    store.patch((s) => s.copyWith(themeMode: mode)),
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: '主题色',
          subtitle: '影响应用整体配色',
          children: [_ThemeColorPicker(settings: settings, store: store)],
        ),
        SettingsGroup(
          children: [
            ScaleSliderRow(
              key: const ValueKey('appearance-ui-scale'),
              title: '页面缩放',
              subtitle: '调整界面整体大小（不影响参考图）',
              icon: Symbols.fit_screen_rounded,
              value: settings.uiScale.clamp(0.8, 1.0),
              min: 0.8,
              max: 1.0,
              divisions: 4,
              tickLabels: const ['80%', '85%', '90%', '95%', '100%'],
              commitOnRelease: true,
              onChanged: (value) =>
                  store.patch((s) => s.copyWith(uiScale: value)),
            ),
            SettingsBlock(
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Text('Aa', style: context.text.titleSmall),
                  ),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: SegmentedControl<FontSizePreset>(
                      semanticLabel: '字号',
                      collapseToIcons: false,
                      options: [
                        for (final preset in FontSizePreset.values)
                          SegmentOption(value: preset, label: preset.label),
                      ],
                      value: fontPreset,
                      onChanged: (preset) => store.patch(
                        (s) => s.copyWith(fontScale: preset.scale),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: '个性化功能配置',
          children: [
            SwitchRow(
              key: const ValueKey('plan-group-progress-toggle'),
              leading: const Icon(Symbols.linear_scale_rounded),
              title: '显示片区进度条',
              subtitle: '在片区选择弹窗中显示未完成片区的进度背景；完成后仅显示对勾。',
              value: settings.showPlanGroupProgress,
              onChanged: (value) =>
                  store.patch((s) => s.copyWith(showPlanGroupProgress: value)),
            ),
          ],
        ),
        const SettingsGroup(
          title: '实时预览',
          subtitle: '当前主题下的按钮、卡片和地图标记',
          children: [SettingsBlock(child: _ThemePreview())],
        ),
      ],
    );
  }
}

class _ThemeColorPicker extends StatelessWidget {
  const _ThemeColorPicker({required this.settings, required this.store});

  final AppSettings settings;
  final SettingsStore store;

  Future<void> _addCustomColor(BuildContext context) async {
    final result = await showDialog<CustomThemeColor>(
      context: context,
      builder: (_) => CustomThemeColorDialog(
        initialName: settings.customThemeColorName,
        initialValue: settings.customThemeColorValue,
      ),
    );
    if (result == null) return;
    await store.patch((s) => addCustomThemeColor(s, result));
  }

  @override
  Widget build(BuildContext context) {
    final brightness = context.colors.brightness;
    Color paletteColor(AppThemePalette palette) => resolveMiriaColors(
      brightness: brightness,
      palette: palette,
      customAccentValue: settings.customThemeColorValue,
    ).primary;
    final isCustom = settings.themePalette == AppThemePalette.aurora;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        Space.x3,
        Space.x2,
        Space.x3,
        Space.x2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final palette in visibleThemePalettes)
            _ColorOption(
              key: ValueKey('theme-palette-${palette.name}'),
              color: paletteColor(palette),
              label: palette.label,
              selected: settings.themePalette == palette,
              onTap: () =>
                  store.patch((s) => s.copyWith(themePalette: palette)),
            ),
          for (final color in settings.customThemeColors)
            _ColorOption(
              color: Color(color.value),
              label: color.name,
              selected:
                  isCustom && settings.customThemeColorValue == color.value,
              onTap: () => store.patch((s) => selectCustomThemeColor(s, color)),
            ),
          _ColorOption(
            key: const ValueKey('theme-palette-add'),
            color: Color(settings.customThemeColorValue),
            label: settings.customThemeColorName.trim().isEmpty
                ? '自定义'
                : settings.customThemeColorName.trim(),
            selected: false,
            icon: Symbols.add_rounded,
            semanticLabel: '添加自定义主题色',
            onTap: () => _addCustomColor(context),
          ),
        ],
      ),
    );
  }
}

class _ColorOption extends StatelessWidget {
  const _ColorOption({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.semanticLabel,
    super.key,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final foreground = color.computeLuminance() > 0.5
        ? const Color(0xFF1B2326)
        : const Color(0xFFFFFFFF);
    final glyph = selected ? Symbols.check_rounded : icon;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: MiriaPressable(
        onTap: onTap,
        borderRadius: Radii.mdAll,
        child: SizedBox(
          width: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.x1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: Motion.of(context, Motion.fast),
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? c.primaryText : c.hairlineStrong,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: glyph == null
                        ? null
                        : Icon(glyph, size: 18, color: foreground),
                  ),
                ),
                const SizedBox(height: Space.x1 + 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.text.labelMedium?.copyWith(
                    color: selected ? c.primaryText : c.textPrimary,
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

/// 自定义主题色 dialog: preview, name, hex and an HSV palette.
class CustomThemeColorDialog extends StatefulWidget {
  const CustomThemeColorDialog({
    required this.initialName,
    required this.initialValue,
    super.key,
  });

  final String initialName;
  final int initialValue;

  @override
  State<CustomThemeColorDialog> createState() => _CustomThemeColorDialogState();
}

class _CustomThemeColorDialogState extends State<CustomThemeColorDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  late Color _color = Color(widget.initialValue);
  late final TextEditingController _hex = TextEditingController(
    text: hexFromColor(_color),
  );
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _hex.dispose();
    super.dispose();
  }

  void _setColor(Color color, {bool syncHex = true}) {
    setState(() {
      _color = color.withAlpha(255);
      if (syncHex) _hex.text = hexFromColor(_color);
    });
  }

  void _submit() {
    final result = validateCustomThemeColor(
      name: _name.text,
      hex: _hex.text,
      fallback: _color,
    );
    if (result.error != null) {
      setState(() => _error = result.error);
      return;
    }
    Navigator.of(context).pop(result.color);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final previewText = _color.computeLuminance() > 0.5
        ? const Color(0xFF1B2326)
        : const Color(0xFFFFFFFF);
    return MiriaDialog(
      title: '自定义主题色',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 54),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _color,
              borderRadius: Radii.smAll,
              border: Border.all(color: c.hairline),
            ),
            child: Text(
              hexFromColor(_color),
              style: context.text.titleSmall?.copyWith(color: previewText),
            ),
          ),
          const SizedBox(height: Space.x3),
          MiriaTextField(
            label: '名称',
            controller: _name,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: Space.x3),
          MiriaTextField(
            key: const ValueKey('custom-theme-color-hex-field'),
            label: '色号',
            hint: '#0F8B8D',
            controller: _hex,
            onChanged: (value) {
              final color = colorFromHex(value);
              if (color != null) _setColor(color, syncHex: false);
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: Space.x3),
          HsvColorPalette(color: _color, onChanged: _setColor),
          if (_error != null) ...[
            const SizedBox(height: Space.x2),
            Text(
              _error!,
              style: context.text.bodySmall?.copyWith(color: c.danger),
            ),
          ],
        ],
      ),
      actions: DialogActionRow(
        confirmLabel: '添加',
        onConfirm: _submit,
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }
}

/// Hue/saturation square plus a value bar (old `_HsvColorPalette`).
class HsvColorPalette extends StatelessWidget {
  const HsvColorPalette({
    required this.color,
    required this.onChanged,
    super.key,
  });

  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final hsv = HSVColor.fromColor(color);
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final paletteSize = math.max(
          80.0,
          math.min(constraints.maxWidth - 44, 230.0),
        );

        void updateHueSaturation(Offset position) {
          final hue = (position.dx.clamp(0, paletteSize) / paletteSize * 360)
              .clamp(0.0, 359.999);
          final saturation =
              1 - position.dy.clamp(0, paletteSize) / paletteSize;
          onChanged(
            hsv
                .withHue(hue)
                .withSaturation(saturation)
                .toColor()
                .withAlpha(255),
          );
        }

        void updateValue(double y) {
          final value = 1 - y.clamp(0, paletteSize) / paletteSize;
          onChanged(hsv.withValue(value).toColor().withAlpha(255));
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              slider: true,
              label: '色相和饱和度',
              value:
                  '色相 ${hsv.hue.round()} 度，饱和度 ${(hsv.saturation * 100).round()}%',
              increasedValue:
                  '色相 ${((hsv.hue + 5) % 360).round()} 度，饱和度 ${(hsv.saturation * 100).round()}%',
              decreasedValue:
                  '色相 ${((hsv.hue - 5) % 360).round()} 度，饱和度 ${(hsv.saturation * 100).round()}%',
              onIncrease: () => onChanged(
                hsv.withHue((hsv.hue + 5) % 360).toColor().withAlpha(255),
              ),
              onDecrease: () => onChanged(
                hsv.withHue((hsv.hue - 5) % 360).toColor().withAlpha(255),
              ),
              child: GestureDetector(
                key: const ValueKey('custom-theme-color-palette'),
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => updateHueSaturation(d.localPosition),
                onPanDown: (d) => updateHueSaturation(d.localPosition),
                onPanUpdate: (d) => updateHueSaturation(d.localPosition),
                child: CustomPaint(
                  size: Size.square(paletteSize),
                  painter: _HueSaturationPainter(
                    hsv,
                    border: c.hairlineStrong,
                    ink: c.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: Space.x3),
            Semantics(
              slider: true,
              label: '明度',
              value: '${(hsv.value * 100).round()}%',
              increasedValue:
                  '${((hsv.value + 0.05).clamp(0.0, 1.0) * 100).round()}%',
              decreasedValue:
                  '${((hsv.value - 0.05).clamp(0.0, 1.0) * 100).round()}%',
              onIncrease: () => onChanged(
                hsv
                    .withValue((hsv.value + 0.05).clamp(0.0, 1.0))
                    .toColor()
                    .withAlpha(255),
              ),
              onDecrease: () => onChanged(
                hsv
                    .withValue((hsv.value - 0.05).clamp(0.0, 1.0))
                    .toColor()
                    .withAlpha(255),
              ),
              child: GestureDetector(
                key: const ValueKey('custom-theme-color-value'),
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => updateValue(d.localPosition.dy),
                onPanDown: (d) => updateValue(d.localPosition.dy),
                onPanUpdate: (d) => updateValue(d.localPosition.dy),
                child: CustomPaint(
                  size: Size(28, paletteSize),
                  painter: _ValuePainter(
                    hsv,
                    border: c.hairlineStrong,
                    ink: c.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// The hue spectrum below is colour-picker data, not UI chrome.
const _hueSpectrum = [
  Color(0xFFFF0000),
  Color(0xFFFFFF00),
  Color(0xFF00FF00),
  Color(0xFF00FFFF),
  Color(0xFF0000FF),
  Color(0xFFFF00FF),
  Color(0xFFFF0000),
];
const _white = Color(0xFFFFFFFF);
const _black = Color(0xFF000000);

class _HueSaturationPainter extends CustomPainter {
  const _HueSaturationPainter(
    this.hsv, {
    required this.border,
    required this.ink,
  });

  final HSVColor hsv;
  final Color border;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(shape);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: _hueSpectrum,
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_white.withValues(alpha: 0), _white],
        ).createShader(rect),
    );
    canvas.restore();
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = border,
    );
    final selector = Offset(
      hsv.hue / 360 * size.width,
      (1 - hsv.saturation) * size.height,
    );
    canvas.drawCircle(
      selector,
      8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = _white,
    );
    canvas.drawCircle(
      selector,
      8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ink,
    );
  }

  @override
  bool shouldRepaint(_HueSaturationPainter oldDelegate) =>
      oldDelegate.hsv.hue != hsv.hue ||
      oldDelegate.hsv.saturation != hsv.saturation ||
      oldDelegate.border != border;
}

class _ValuePainter extends CustomPainter {
  const _ValuePainter(this.hsv, {required this.border, required this.ink});

  final HSVColor hsv;
  final Color border;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 12.0;
    final rect = Rect.fromLTWH(
      (size.width - barWidth) / 2,
      0,
      barWidth,
      size.height,
    );
    final shape = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.drawRRect(
      shape,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [hsv.withValue(1).toColor(), _black],
        ).createShader(rect),
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = border,
    );
    final selector = Offset(size.width / 2, (1 - hsv.value) * size.height);
    canvas.drawCircle(selector, 8, Paint()..color = _white);
    canvas.drawCircle(
      selector,
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ink,
    );
  }

  @override
  bool shouldRepaint(_ValuePainter oldDelegate) =>
      oldDelegate.hsv != hsv || oldDelegate.border != border;
}

/// Buttons, a card and the three map marker states in the current theme.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(Space.x3),
          decoration: BoxDecoration(
            color: c.canvas,
            borderRadius: Radii.mdAll,
            border: Border.all(color: c.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: Space.x2,
                runSpacing: Space.x2,
                children: [
                  MiriaButton(
                    label: '拍摄',
                    icon: Symbols.photo_camera_rounded,
                    size: MiriaButtonSize.sm,
                    onPressed: () {},
                  ),
                  MiriaButton.secondary(
                    label: '导航',
                    icon: Symbols.directions_walk_rounded,
                    size: MiriaButtonSize.sm,
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: Space.x3),
              MiriaCard(
                padding: const EdgeInsets.all(Space.x3),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '宇治橋',
                            locale: MiriaFonts.japanese,
                            style: text.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '当前目标',
                            style: text.bodySmall?.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const StatusBadge(status: VisitStatus.current),
                  ],
                ),
              ),
              const SizedBox(height: Space.x3),
              Container(
                height: 72,
                decoration: BoxDecoration(
                  color: c.surfaceMuted,
                  borderRadius: Radii.smAll,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _MarkerDot(
                      fill: c.surface,
                      border: c.primary,
                      icon: Symbols.location_on_rounded,
                      iconColor: c.primary,
                    ),
                    _MarkerDot(
                      fill: c.spot,
                      border: c.surface,
                      icon: Symbols.star_rounded,
                      iconColor: c.onSpot,
                      size: 34,
                    ),
                    Opacity(
                      opacity: 0.75,
                      child: _MarkerDot(
                        fill: c.primary,
                        border: c.surface,
                        icon: Symbols.check_rounded,
                        iconColor: c.onPrimary,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarkerDot extends StatelessWidget {
  const _MarkerDot({
    required this.fill,
    required this.border,
    required this.icon,
    required this.iconColor,
    this.size = 28,
  });

  final Color fill;
  final Color border;
  final IconData icon;
  final Color iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 2),
        boxShadow: Elevations.level1(context.colors),
      ),
      child: Icon(icon, size: size * 0.55, color: iconColor, fill: 1),
    );
  }
}
