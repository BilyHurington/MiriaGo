import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'comparison_export_config.dart';

class ComparisonExportRenderer {
  const ComparisonExportRenderer();

  static const double outputWidth = 1080.0;
  static const double padding = 24.0;
  static const double cornerRadius = 20.0;
  static const double imageGap = 16.0;
  static const double imageRadius = 12.0;
  static const double labelFontSize = 32.0;
  static const double metaFieldFontSize = 22.0;
  static const double metaValueFontSize = 22.0;
  static const double metaRowHeight = 38.0;
  static const double metaAreaTopPad = 20.0;
  static const double metaAreaBottomPad = 24.0;

  Future<Uint8List?> render({
    required Uint8List? referenceBytes,
    required Uint8List capturedBytes,
    required ComparisonExportConfig config,
    required Map<ComparisonMetadataField, String> metadata,
  }) async {
    final refImg = referenceBytes != null
        ? await _decodeImage(referenceBytes)
        : null;
    final capImg = await _decodeImage(capturedBytes);
    if (capImg == null) return null;

    final borderPx = config.borderWidth.px;
    final contentWidth = outputWidth - 2 * borderPx - 2 * padding;

    double refHeight = 0;
    if (refImg != null) {
      refHeight = refImg.height / refImg.width * contentWidth;
    }

    final capHeight = capImg.height / capImg.width * contentWidth;

    final metaEntries = <MapEntry<String, String>>[];
    for (final field in config.metadataFields) {
      final value = metadata[field];
      if (value != null && value.isNotEmpty) {
        metaEntries.add(MapEntry(field.label, value));
      }
    }

    final hasMeta = metaEntries.isNotEmpty;
    final double metaAreaHeight = hasMeta
        ? metaAreaTopPad + metaEntries.length * metaRowHeight + metaAreaBottomPad
        : 0;

    final imgAreaHeight = (refImg != null ? refHeight + imageGap : 0) + capHeight;
    final metaGap = hasMeta ? 16.0 : 0;
    final totalHeight = borderPx * 2 + padding * 2 + imgAreaHeight + metaGap + metaAreaHeight;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, outputWidth, totalHeight));

    // White card background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, outputWidth, totalHeight),
        const Radius.circular(cornerRadius),
      ),
      Paint()..color = Colors.white,
    );

    double y = borderPx + padding;

    // Reference image
    if (refImg != null) {
      _drawLabeledImage(canvas, refImg, borderPx + padding, y,
          contentWidth, refHeight, '参考');
      y += refHeight + imageGap;
    }

    // Captured image
    _drawLabeledImage(canvas, capImg, borderPx + padding, y,
        contentWidth, capHeight, '巡礼');
    y += capHeight + metaGap;

    // Metadata
    if (hasMeta) {
      _drawMetadata(canvas, borderPx + padding, y, contentWidth,
          metaAreaHeight, metaEntries);
    }

    // Border
    if (borderPx > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            borderPx / 2,
            borderPx / 2,
            outputWidth - borderPx,
            totalHeight - borderPx,
          ),
          const Radius.circular(cornerRadius),
        ),
        Paint()
          ..color = config.borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderPx,
      );
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(outputWidth.toInt(), totalHeight.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    refImg?.dispose();
    capImg.dispose();

    return byteData?.buffer.asUint8List();
  }

  void _drawLabeledImage(
    Canvas canvas,
    ui.Image image,
    double x,
    double y,
    double width,
    double height,
    String label,
  ) {
    final imageRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, width, height),
      const Radius.circular(imageRadius),
    );

    canvas.clipRRect(imageRect);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(x, y, width, height),
      Paint(),
    );
    canvas.restore();

    // Label pill at top-left of image
    if (label.isNotEmpty) {
      final labelPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: labelFontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width - 24);

      const labelHPad = 14.0;
      const labelVPad = 8.0;
      final pillW = labelPainter.width + labelHPad * 2;
      const pillH = labelFontSize * 1.2 + labelVPad * 2;
      final pillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 12, y + 10, pillW, pillH),
        const Radius.circular(8),
      );

      canvas.drawRRect(
        pillRect,
        Paint()..color = const Color(0x99000000),
      );

      labelPainter.paint(
        canvas,
        Offset(x + 12 + labelHPad, y + 10 + labelVPad),
      );
    }
  }

  void _drawMetadata(
    Canvas canvas,
    double x,
    double y,
    double width,
    double areaHeight,
    List<MapEntry<String, String>> entries,
  ) {
    // Meta section background
    final metaBg = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, width, areaHeight),
      const Radius.circular(imageRadius),
    );
    canvas.drawRRect(
      metaBg,
      Paint()..color = const Color(0xFFF5F5F5),
    );

    double rowY = y + metaAreaTopPad;
    for (final entry in entries) {
      // Field name
      final fieldPainter = TextPainter(
        text: TextSpan(
          text: '${entry.key}：',
          style: const TextStyle(
            color: Color(0xFF888888),
            fontSize: metaFieldFontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width - 40);

      fieldPainter.paint(canvas, Offset(x + 16, rowY));

      // Value
      final valuePainter = TextPainter(
        text: TextSpan(
          text: entry.value,
          style: const TextStyle(
            color: Color(0xFF333333),
            fontSize: metaValueFontSize,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width - fieldPainter.width - 40);

      valuePainter.paint(
        canvas,
        Offset(x + 16 + fieldPainter.width + 4, rowY),
      );

      rowY += metaRowHeight;
    }
  }

  Future<ui.Image?> _decodeImage(Uint8List bytes) {
    final completer = Completer<ui.Image?>();
    ui.decodeImageFromList(bytes, (img) => completer.complete(img));
    return completer.future;
  }
}
