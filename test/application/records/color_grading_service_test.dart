import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/application/records/color_grading_service.dart';
import 'package:miriago/color_grading/color_adjustment.dart';
import 'package:miriago/color_grading/color_grading_params.dart';
import 'package:miriago/data/bounded_image_decoder.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

import 'records_fixture.dart';

class _Writer {
  final updates = <Map<String, Object?>>[];
  var clears = 0;
  Object? updateError;

  GradingRecordWriter get writer => GradingRecordWriter(
    repository: null,
    update:
        ({
          required record,
          required originalPhotoPath,
          required gradedPhotoPath,
          required colorGradingMode,
          required colorGradingParamsJson,
          required colorGradingIntensity,
        }) async {
          if (updateError != null) throw updateError!;
          updates.add({
            'original': originalPhotoPath,
            'graded': gradedPhotoPath,
            'mode': colorGradingMode,
            'params': colorGradingParamsJson,
            'intensity': colorGradingIntensity,
          });
          return record.copyWith(
            gradedPhotoPath: gradedPhotoPath,
            colorGradingParamsJson: colorGradingParamsJson,
          );
        },
    clear: ({required record}) async {
      clears++;
      return record.copyWith(
        gradedPhotoPath: null,
        colorGradingParamsJson: null,
      );
    },
  );
}

final _photo = Uint8List.fromList([1, 2, 3]);
final _reference = Uint8List.fromList([4, 5, 6]);

ColorGradingService _service(
  PilgrimageVisitRecord record,
  _Writer writer, {
  Map<String, Object> reads = const {},
  ColorMatchResult? match,
  String? savedPath = 'graded/new.jpg',
  String? fallbackUrl,
}) {
  return ColorGradingService(
    record: record,
    writer: writer.writer,
    fallbackReferenceImageUrl: fallbackUrl,
    sourcePhotoPath: (record) => record.originalPhotoPath ?? record.photoPath,
    readImage: (path) async {
      final value = reads[path];
      if (value is Uint8List) return value;
      if (value != null) throw value;
      throw StateError('missing $path');
    },
    probe: (_) async {},
    autoMatch:
        ({
          required capturedBytes,
          required referenceBytes,
          required mode,
        }) async => match,
    renderJpeg: ({required imageBytes, required params}) async =>
        Uint8List.fromList([9]),
    saveGradedPhoto: ({required bytes, required recordId}) async => savedPath,
  );
}

void main() {
  final plain = makeRecord('r1', pointId: 'p-bridge');
  const matchResult = ColorMatchResult(
    targetParams: ColorGradingParams(exposure: 0.3),
    mode: ColorMatchMode.strong,
    beforeScore: 40,
    afterScore: 80,
  );

  test('restores the saved mode, intensity and parameters', () {
    final record = makeRecord(
      'r',
      pointId: 'p',
      colorGradingMode: 'natural',
      colorGradingIntensity: 0.4,
      colorGradingParamsJson: jsonEncode(
        const ColorGradingParams(exposure: 0.2).toJson(),
      ),
    );
    final service = _service(record, _Writer());
    expect(service.selectedMode, ColorMatchMode.natural);
    expect(service.intensity, 0.4);
    expect(service.hasParams, isTrue);
    expect(service.activeParams.exposure, closeTo(0.08, 1e-9));
    expect(service.currentToneScore, isNull);
  });

  test('photo read failure is a load error', () async {
    final service = _service(plain, _Writer());
    await service.load();
    expect(service.loading, isFalse);
    expect(service.loadError, isNotNull);
  });

  test('no reference: matching warns, saving asks to match first', () async {
    final writer = _Writer();
    final service = _service(plain, writer, reads: {'photos/r1.jpg': _photo});
    await service.load();
    expect(service.referenceError, isNull);
    expect(
      await service.runAutoMatch(),
      const GradingNotice(GradingNoticeKind.warning, '没有可用于自动调色的参考图'),
    );
    final result = await service.save();
    expect(
      result.notice,
      const GradingNotice(GradingNoticeKind.warning, '请先自动匹配色调'),
    );
    expect(result.pop, isFalse);
  });

  test('unavailable reference keeps saved grading editable', () async {
    final record = makeRecord(
      'r1',
      pointId: 'p',
      referenceImageUrl: 'https://example.com/ref.jpg',
      colorGradingParamsJson: jsonEncode(const ColorGradingParams().toJson()),
    );
    final service = _service(
      record,
      _Writer(),
      reads: {
        'photos/r1.jpg': _photo,
        'https://example.com/ref.jpg': StateError('404'),
      },
    );
    await service.load();
    expect(service.loadError, isNull);
    expect(service.referenceError, isNotNull);
    expect(service.hasParams, isTrue);
    expect((await service.runAutoMatch())!.title, '参考图暂不可用，无法自动匹配色调');
    service.setIntensity(0.4);
    expect(service.intensity, 0.4);
  });

  test('budget errors surface their own message', () async {
    final service = _service(
      plain,
      _Writer(),
      reads: {
        'photos/r1.jpg': _photo,
        'https://example.com/ref.jpg': const ImageBudgetException(
          ImageBudgetFailure.sourcePixels,
          '图片像素过多',
        ),
      },
      fallbackUrl: 'https://example.com/ref.jpg',
    );
    await service.load();
    expect((await service.runAutoMatch())!.title, '图片像素过多');
  });

  test('auto match, save and pop with the updated record', () async {
    final writer = _Writer();
    final service = _service(
      plain,
      writer,
      reads: {
        'photos/r1.jpg': _photo,
        'https://example.com/ref.jpg': _reference,
      },
      fallbackUrl: 'https://example.com/ref.jpg',
      match: matchResult,
    );
    await service.load();
    service.setIntensity(0.2);
    expect(
      await service.runAutoMatch(),
      const GradingNotice(GradingNoticeKind.success, '已生成自动调色参数'),
    );
    expect(service.selectedMode, ColorMatchMode.strong);
    expect(service.intensity, 1.0);
    service.setIntensity(0.5);
    expect(service.currentToneScore, 60);

    final result = await service.save();
    expect(result.notice?.title, '已保存调色结果');
    expect(result.pop, isTrue);
    expect(result.popWith?.gradedPhotoPath, 'graded/new.jpg');
    expect(writer.updates.single['mode'], 'strong');
    expect(writer.updates.single['intensity'], 0.5);
    expect(writer.updates.single['original'], 'photos/r1.jpg');
    expect(service.saving, isFalse);
  });

  test('failed match and failed saves use the old messages', () async {
    final writer = _Writer();
    final service = _service(
      plain,
      writer,
      reads: {'photos/r1.jpg': _photo, 'ref': _reference},
      fallbackUrl: 'ref',
    );
    await service.load();
    expect((await service.runAutoMatch())!.title, '自动调色失败');
    expect(service.matching, isFalse);

    final noPath = _service(
      plain,
      writer,
      reads: {'photos/r1.jpg': _photo, 'ref': _reference},
      fallbackUrl: 'ref',
      match: matchResult,
      savedPath: null,
    );
    await noPath.load();
    await noPath.runAutoMatch();
    expect((await noPath.save()).notice?.title, '保存失败');

    writer.updateError = StateError('db');
    final failing = _service(
      plain,
      writer,
      reads: {'photos/r1.jpg': _photo, 'ref': _reference},
      fallbackUrl: 'ref',
      match: matchResult,
    );
    await failing.load();
    await failing.runAutoMatch();
    final result = await failing.save();
    expect(result.notice?.title, '保存失败，原件未更改');
    expect(result.pop, isFalse);
    expect(failing.saving, isFalse);
  });

  test('changing the mode clears parameters', () async {
    final service = _service(
      plain,
      _Writer(),
      reads: {'photos/r1.jpg': _photo, 'ref': _reference},
      fallbackUrl: 'ref',
      match: matchResult,
    );
    await service.load();
    await service.runAutoMatch();
    service.selectMode(ColorMatchMode.natural);
    expect(service.hasParams, isFalse);
    expect(service.beforeScore, isNull);
    expect(service.previewShowsOriginal, isTrue);
    service.setShowOriginal(true);
    expect(service.showOriginal, isFalse);
  });

  test('reset of a graded record restores the original on save', () async {
    final writer = _Writer();
    final graded = makeRecord(
      'r1',
      pointId: 'p',
      gradedPhotoPath: 'graded/old.jpg',
      colorGradingParamsJson: jsonEncode(const ColorGradingParams().toJson()),
    );
    final service = _service(graded, writer, reads: {'photos/r1.jpg': _photo});
    await service.load();
    service.reset();
    expect(service.resetPending, isTrue);
    expect(service.hasParams, isFalse);
    final result = await service.save();
    expect(result.notice?.title, '已还原为原图');
    expect(result.pop, isTrue);
    expect(writer.clears, 1);
    expect(result.popWith?.hasColorGrading, isFalse);
  });

  test('gradingParameterItems lists 17 parameters with ranges', () {
    final items = gradingParameterItems(ColorGradingParams.defaults);
    expect(items, hasLength(17));
    expect(items.first.label, '亮度');
    expect(items[2].min, 0.7);
    expect(items[2].fraction, closeTo((1 - 0.7) / 0.7, 1e-9));
  });
}
