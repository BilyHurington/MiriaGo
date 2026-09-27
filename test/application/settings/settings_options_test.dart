import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/application/settings/settings_options.dart';
import 'package:miriago/camera_reference/camera_zoom_capabilities.dart';
import 'package:miriago/data/anitabi_service_config.dart';
import 'package:miriago/desktop/tauri_bridge.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

void main() {
  group('custom theme colours', () {
    test('adding de-duplicates by name or value and selects the colour', () {
      const settings = AppSettings(
        customThemeColors: [
          CustomThemeColor(name: '海', value: 0xFF0000FF),
          CustomThemeColor(name: '森', value: 0xFF00FF00),
          CustomThemeColor(name: '夕', value: 0xFFFF8800),
        ],
      );
      final next = addCustomThemeColor(
        settings,
        const CustomThemeColor(name: '海', value: 0xFF00FF00),
      );
      expect(next.themePalette, AppThemePalette.aurora);
      expect(next.customThemeColorName, '海');
      expect(next.customThemeColorValue, 0xFF00FF00);
      expect(next.customThemeColors.map((c) => c.name), ['夕', '海']);
    });

    test('hex parsing and formatting', () {
      expect(colorFromHex('#0f8b8d'), const Color(0xFF0F8B8D));
      expect(colorFromHex('0F8B8D'), const Color(0xFF0F8B8D));
      expect(colorFromHex('#0F8B8'), isNull);
      expect(colorFromHex('zzzzzz'), isNull);
      expect(hexFromColor(const Color(0xFF0F8B8D)), '#0F8B8D');
    });

    test('dialog validation requires a name and falls back to the picker', () {
      final empty = validateCustomThemeColor(
        name: '  ',
        hex: '#112233',
        fallback: const Color(0xFF000000),
      );
      expect(empty.error, '请输入颜色名称');
      final invalidHex = validateCustomThemeColor(
        name: ' 夜 ',
        hex: 'nope',
        fallback: const Color(0x80123456),
      );
      expect(invalidHex.error, isNull);
      expect(invalidHex.color!.name, '夜');
      expect(invalidHex.color!.value, 0xFF123456);
    });
  });

  test('font size presets use the old thresholds', () {
    expect(FontSizePreset.of(0.8), FontSizePreset.small);
    expect(FontSizePreset.of(0.9), FontSizePreset.small);
    expect(FontSizePreset.of(1.0), FontSizePreset.standard);
    expect(FontSizePreset.of(1.1), FontSizePreset.large);
    expect(FontSizePreset.of(1.2), FontSizePreset.extraLarge);
    expect(FontSizePreset.of(1.5), FontSizePreset.extraLarge);
  });

  group('aspect ratios', () {
    test('custom ratio parsing rejects non-positive values', () {
      expect(parseCustomAspectRatio('16', '9'), (width: 16.0, height: 9.0));
      expect(parseCustomAspectRatio(' 2.35 ', '1'), (width: 2.35, height: 1.0));
      expect(parseCustomAspectRatio('0', '1'), isNull);
      expect(parseCustomAspectRatio('a', '1'), isNull);
      expect(parseCustomAspectRatio('1', '-2'), isNull);
    });

    test('both settings share the custom size; only one switches', () {
      const settings = AppSettings();
      final capture = applyCustomAspectRatio(
        settings,
        width: 5,
        height: 4,
        fallbackRatio: false,
      );
      expect(capture.cameraCaptureAspectRatio, CameraPhotoAspectRatio.custom);
      expect(capture.cameraFallbackAspectRatio, CameraPhotoAspectRatio.native);
      expect(capture.customCameraAspectRatioWidth, 5);
      final fallback = applyCustomAspectRatio(
        capture,
        width: 3,
        height: 1,
        fallbackRatio: true,
      );
      expect(fallback.cameraCaptureAspectRatio, CameraPhotoAspectRatio.custom);
      expect(fallback.cameraFallbackAspectRatio, CameraPhotoAspectRatio.custom);
      expect(fallback.customCameraAspectRatioHeight, 1);
    });

    test('ratio numbers are printed compactly', () {
      expect(formatRatioNumber(16), '16');
      expect(formatRatioNumber(2.35), '2.35');
      expect(formatRatioNumber(1.5), '1.5');
    });
  });

  group('camera zoom range', () {
    const caps = CameraZoomCapabilities(minZoom: 0.6, maxZoom: 20);

    test('defaults map onto the log slider and back', () {
      const settings = AppSettings();
      final values = cameraZoomSliderValues(settings, caps);
      expect(values.start, 0);
      final next = applyCameraZoomSlider(
        settings,
        caps,
        start: values.start,
        end: values.end,
      );
      expect(next.cameraMinZoom, 0.6);
      expect(next.cameraMaxZoom, 5);
    });

    test('values snap to 0.1x and stay ordered', () {
      final next = applyCameraZoomSlider(
        const AppSettings(),
        caps,
        start: 0.5,
        end: 0.5,
      );
      expect(next.cameraMinZoom, 1.0);
      expect(next.cameraMaxZoom, 1.0);
    });

    test('configured range is clamped to the device range', () {
      final range = cameraZoomRange(
        const AppSettings(cameraMinZoom: 0.5, cameraMaxZoom: 30),
        const CameraZoomCapabilities(minZoom: 1, maxZoom: 8),
      );
      expect(range.minZoom, 1);
      expect(range.maxZoom, 8);
    });
  });

  test('lowering the max zoom lowers the cluster stop level', () {
    final lowered = applyMapMaxZoom(
      const AppSettings(mapMarkerClusterMaxZoom: 21),
      18,
    );
    expect(lowered.mapMaxZoom, 18);
    expect(lowered.mapMarkerClusterMaxZoom, 18);
    final raised = applyMapMaxZoom(
      const AppSettings(mapMarkerClusterMaxZoom: 15),
      24,
    );
    expect(raised.mapMarkerClusterMaxZoom, 15);
    expect(clusterMaxZoomLimit(const AppSettings(mapMaxZoom: 24)), 22);
    expect(clusterMaxZoomLimit(const AppSettings(mapMaxZoom: 16)), 16);
  });

  test('Anitabi service helpers', () {
    const custom = AppSettings(anitabiApiBaseUrl: 'https://api.example.org');
    expect(usesDefaultAnitabiService(const AppSettings()), isTrue);
    expect(usesDefaultAnitabiService(custom), isFalse);
    expect(
      usesDefaultAnitabiService(restoreDefaultAnitabiService(custom)),
      isTrue,
    );
    final edited = AnitabiService.mirrorImage.apply(
      const AppSettings(),
      'https://img.example.org',
    );
    expect(
      AnitabiService.mirrorImage.valueIn(edited),
      'https://img.example.org',
    );
    expect(AnitabiService.site.valueIn(edited), defaultAnitabiSiteBaseUrl);
    expect(
      anitabiImageSourceDescription(edited),
      '优先使用 $defaultAnitabiOfficialImageBaseUrl；失败后尝试 https://img.example.org。',
    );
  });

  test('photo location copy', () {
    expect(
      photoLocationStrategyMenuLabel(PhotoLocationStrategy.waitOnConfirmation),
      '确认记录时获取定位',
    );
    expect(
      photoLocationStrategyMenuLabel(PhotoLocationStrategy.askOnFirstCapture),
      '首次拍摄时询问',
    );
    expect(PhotoLocationStrategy.values.map(photoLocationStrategyBadge), [
      '询问',
      '关闭',
      '最近',
      '推荐',
    ]);
  });

  test('byte sizes', () {
    expect(formatByteSize(512), '512 B');
    expect(formatByteSize(1536), '1.5 KB');
    expect(formatByteSize(5 * 1024 * 1024), '5.0 MB');
    expect(formatByteSize(3 * 1024 * 1024 * 1024), '3.00 GB');
  });

  test('desktop launcher status text', () {
    const info = DesktopLauncherInfo(
      appVersion: '1',
      platform: 'windows',
      portable: true,
      fallbackUsed: false,
      dataDir: 'D:/MiriaGo/data',
      assetsDir: 'D:/MiriaGo/assets',
      exportsDir: '',
      logsDir: '',
      tempDir: '',
    );
    expect(
      desktopLauncherStatusText(
        loaded: false,
        info: null,
        launcherAvailable: true,
      ),
      '桌面启动器 检查中',
    );
    expect(
      desktopLauncherStatusText(
        loaded: true,
        info: info,
        launcherAvailable: false,
      ),
      '桌面启动器 不可用',
    );
    expect(
      desktopLauncherStatusText(
        loaded: true,
        info: info,
        launcherAvailable: true,
      ),
      '桌面启动器 可用 / windows / 便携目录',
    );
  });
}
