import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/application/records/comparison_export_service.dart';
import 'package:miriago/records/comparison_export_config.dart';
import 'package:miriago/records/comparison_export_result.dart';

class _Store {
  var config = const ComparisonExportConfig(showLabels: true);
  final saved = <ComparisonExportConfig>[];
  bool failLoad = false;
  bool failSave = false;
  Completer<void>? pendingSave;

  Future<ComparisonExportConfig> load() async {
    if (failLoad) throw StateError('load');
    return config;
  }

  Future<void> save(ComparisonExportConfig next) async {
    saved.add(next);
    await pendingSave?.future;
    if (failSave) throw StateError('save');
    config = next;
  }
}

class _Exporter {
  var calls = 0;
  Object? error;
  ComparisonExportImageResult result =
      const ComparisonExportImageResult.success('/tmp/out.jpg');
  Completer<ComparisonExportImageResult>? pending;

  Future<ComparisonExportImageResult> call({
    required String? referenceImagePath,
    required String? referenceImageUrl,
    required String capturedPath,
    required ComparisonExportConfig config,
    required Map<ComparisonMetadataField, String> metadata,
    required String? colorGradingSummary,
  }) async {
    calls++;
    if (error != null) throw error!;
    return pending == null ? result : pending!.future;
  }
}

const _request = ComparisonExportRequest(
  referenceImagePath: null,
  referenceImageUrl: 'https://example.com/ref.jpg',
  capturedPath: 'photo.jpg',
  metadata: {},
  colorGradingSummary: null,
);

void main() {
  late _Store store;
  late _Exporter exporter;
  late ComparisonExportService service;

  setUp(() {
    store = _Store();
    exporter = _Exporter();
    service = ComparisonExportService(
      loadConfig: store.load,
      saveConfig: store.save,
      exporter: exporter.call,
    );
  });

  tearDown(() => service.dispose());

  test('loads the saved config and unlocks the controls', () async {
    expect(service.locked, isTrue);
    expect(await service.load(), isNull);
    expect(service.config.showLabels, isTrue);
    expect(service.locked, isFalse);
    expect(ComparisonExportConfig.lastUsed.showLabels, isTrue);
  });

  test('load failure keeps controls locked with the old message', () async {
    store.failLoad = true;
    expect(await service.load(), '读取导出设置失败，请重试。');
    expect(service.locked, isTrue);
    expect(await service.update(const ComparisonExportConfig()), isNull);
    expect(store.saved, isEmpty);
  });

  test('changes apply immediately and save serially', () async {
    await service.load();
    store.pendingSave = Completer<void>();
    final first = service.update(
      service.config.copyWith(borderWidthPercent: 1.5),
    );
    final second = service.update(service.config.copyWith(showLabels: false));
    expect(service.config.borderWidthPercent, 1.5);
    expect(service.config.showLabels, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(store.saved, hasLength(1));
    store.pendingSave!.complete();
    await Future.wait([first, second]);
    expect(store.saved, hasLength(2));
    expect(store.config.showLabels, isFalse);
  });

  test('save failure reports the retry message', () async {
    await service.load();
    store.failSave = true;
    expect(
      await service.update(service.config.copyWith(showLabels: false)),
      '导出设置保存失败，导出时将重试。',
    );
  });

  test('export saves settings first and maps a local file', () async {
    await service.load();
    final outcome = await service.export(_request);
    expect(store.saved, hasLength(1));
    expect(exporter.calls, 1);
    expect(outcome.kind, ComparisonExportOutcomeKind.localFile);
    expect(outcome.path, '/tmp/out.jpg');
    expect(service.exiting, isTrue);
    expect(service.busy, isTrue);
  });

  test('browser download and cancel', () async {
    await service.load();
    exporter.result = const ComparisonExportImageResult.canceled();
    expect(
      (await service.export(_request)).kind,
      ComparisonExportOutcomeKind.none,
    );
    expect(service.busy, isFalse);
    exporter.result = const ComparisonExportImageResult.downloaded();
    final outcome = await service.export(_request);
    expect(outcome.kind, ComparisonExportOutcomeKind.downloaded);
    expect(outcome.message, '对比图已交给浏览器下载');
  });

  test('busy blocks a second export', () async {
    await service.load();
    exporter.pending = Completer();
    final first = service.export(_request);
    await Future<void>.delayed(Duration.zero);
    expect(service.exporting, isTrue);
    expect(
      (await service.export(_request)).kind,
      ComparisonExportOutcomeKind.none,
    );
    exporter.pending!.complete(const ComparisonExportImageResult.canceled());
    await first;
    expect(exporter.calls, 1);
    expect(service.exporting, isFalse);
  });

  test('failures map to the 7 old messages', () async {
    await service.load();
    final expected = {
      ComparisonExportFailureReason.referenceUnavailable: '参考图不可用，无法导出对比图片。',
      ComparisonExportFailureReason.capturedPhotoUnavailable:
          '巡礼图不可用，无法导出对比图片。',
      ComparisonExportFailureReason.budgetExceeded: '图片超过处理预算，原件未更改。',
      ComparisonExportFailureReason.unsupportedFormat: '当前平台不支持处理此图片格式。',
      ComparisonExportFailureReason.invalidData: '图片数据无法解码。',
      ComparisonExportFailureReason.renderFailed: '导出失败，请稍后重试。',
    };
    for (final entry in expected.entries) {
      exporter.result = ComparisonExportImageResult.failure(entry.key);
      final outcome = await service.export(_request);
      expect(outcome.kind, ComparisonExportOutcomeKind.failed);
      expect(outcome.message, entry.value);
    }
    exporter.result = const ComparisonExportImageResult.failure(
      ComparisonExportFailureReason.budgetExceeded,
      message: '输出尺寸过大',
    );
    expect((await service.export(_request)).message, '输出尺寸过大');

    exporter.error = StateError('boom');
    expect((await service.export(_request)).message, '导出失败，设置或图片未能保存，请重试。');
    exporter.error = null;
    store.failSave = true;
    expect((await service.export(_request)).message, '导出失败，设置或图片未能保存，请重试。');
    expect(service.busy, isFalse);
  });

  test('export after a failed load retries loading', () async {
    store.failLoad = true;
    await service.load();
    final failed = await service.export(_request);
    expect(failed.message, '读取导出设置失败，请重试。');
    expect(exporter.calls, 0);
    store.failLoad = false;
    final outcome = await service.export(_request);
    expect(outcome.kind, ComparisonExportOutcomeKind.localFile);
  });

  test('border width label', () {
    expect(ComparisonExportService.borderWidthLabel(0), '无');
    expect(ComparisonExportService.borderWidthLabel(1.25), '1.3%');
  });
}
