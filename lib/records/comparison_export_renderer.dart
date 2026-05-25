import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'comparison_export_config.dart';

class ComparisonExportRenderer {
  const ComparisonExportRenderer();

  static const double outputWidth = 1920.0;
  static const double inset = 18.0;
  static const double imageGap = 14.0;
  static const double imageRadius = 14.0;
  static const double labelFontSize = 50.0;
  static const double metaFieldFontSize = 38.0;
  static const double metaValueFontSize = 38.0;
  static const double metaRowHeight = 72.0;
  static const double metaAreaPadH = 36.0;
  static const double metaAreaPadV = 32.0;

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
    final contentWidth = outputWidth - 2 * borderPx - 2 * inset;

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
        ? metaAreaPadV * 2 + metaEntries.length * metaRowHeight
        : 0;

    final imgAreaHeight = (refImg != null ? refHeight + imageGap : 0) + capHeight;
    final metaGap = hasMeta ? inset : 0;
    final totalHeight =
        borderPx * 2 + inset * 2 + imgAreaHeight + metaGap + metaAreaHeight;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder,
        Rect.fromLTWH(0, 0, outputWidth, totalHeight));

    // White card background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, outputWidth, totalHeight),
        Radius.circular(borderPx > 0 ? 16.0 : 0),
      ),
      Paint()..color = Colors.white,
    );

    double y = borderPx + inset;

    // Reference image
    if (refImg != null) {
      _drawLabeledImage(
        canvas, refImg, borderPx + inset, y, contentWidth, refHeight,
        config.showLabels ? '参考' : '',
      );
      y += refHeight + imageGap;
    }

    // Captured image
    _drawLabeledImage(
      canvas, capImg, borderPx + inset, y, contentWidth, capHeight,
      config.showLabels ? '巡礼' : '',
    );
    y += capHeight + metaGap;

    // Metadata
    if (hasMeta) {
      _drawMetadata(
        canvas, borderPx + inset, y, contentWidth, metaAreaHeight, metaEntries,
      );
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
          const Radius.circular(16),
        ),
        Paint()
          ..color = config.borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderPx,
      );
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(
        outputWidth.toInt(), totalHeight.toInt());
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
    final imageRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, width, height),
      const Radius.circular(imageRadius),
    );

    canvas.save();
    canvas.clipRRect(imageRRect);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(
          0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(x, y, width, height),
      Paint(),
    );
    canvas.restore();

    if (label.isNotEmpty) {
      final labelPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: labelFontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width - 24);

      const hPad = 22.0;
      const vPad = 11.0;
      final pillW = labelPainter.width + hPad * 2;
      final pillH = labelFontSize * 1.2 + vPad * 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 10, y + 8, pillW, pillH),
          const Radius.circular(6),
        ),
        Paint()..color = const Color(0xAA000000),
      );

      labelPainter.paint(
        canvas,
        Offset(x + 10 + hPad, y + 8 + vPad),
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
    // Muted background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, width, areaHeight),
        const Radius.circular(imageRadius),
      ),
      Paint()..color = const Color(0xFFF2F3F5),
    );

    // Determine max field label width for alignment
    double maxFieldW = 0;
    final fieldPainters = <TextPainter>[];
    final valuePainters = <TextPainter>[];
    for (final entry in entries) {
      final fp = TextPainter(
        text: TextSpan(
          text: entry.key,
          style: const TextStyle(
            color: Color(0xFF999999),
            fontSize: metaFieldFontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      fieldPainters.add(fp);
      if (fp.width > maxFieldW) maxFieldW = fp.width;

      final vp = TextPainter(
        text: TextSpan(
          text: entry.value,
          style: const TextStyle(
            color: Color(0xFF333333),
            fontSize: metaValueFontSize,
            fontWeight: FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width - maxFieldW - metaAreaPadH * 2 - 16);
      valuePainters.add(vp);
    }

    // Re-layout value painters now that we know maxFieldW
    for (var i = 0; i < entries.length; i += 1) {
      valuePainters[i] = TextPainter(
        text: TextSpan(
          text: entries[i].value,
          style: const TextStyle(
            color: Color(0xFF333333),
            fontSize: metaValueFontSize,
            fontWeight: FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width - maxFieldW - metaAreaPadH * 2 - 16);
    }

    double rowY = y + metaAreaPadV;
    for (var i = 0; i < entries.length; i += 1) {
      fieldPainters[i].paint(canvas, Offset(x + metaAreaPadH, rowY));
      valuePainters[i].paint(
        canvas,
        Offset(x + metaAreaPadH + maxFieldW + 12, rowY),
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
