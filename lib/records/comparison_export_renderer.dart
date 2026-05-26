import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'comparison_export_config.dart';

class ComparisonExportRenderer {
  const ComparisonExportRenderer();

  static const double inset = 18.0;
  static const double imageGap = 14.0;
  static const double labelFontSize = 50.0;

  Future<Uint8List?> render({
    required Uint8List? referenceBytes,
    required Uint8List capturedBytes,
    required ComparisonExportConfig config,
    required Map<ComparisonMetadataField, String> metadata,
    required String? colorGradingSummary,
  }) async {
    final refImg = referenceBytes != null
        ? await _decodeImage(referenceBytes)
        : null;
    final capImg = await _decodeImage(capturedBytes);
    if (capImg == null) return null;

    final fixedWidth = config.outputWidth.px;
    final borderPct = config.borderWidthPercent;
    final hasBorder = borderPct > 0;
    final effectiveInset = hasBorder ? inset : 0.0;
    final effectiveImageGap = hasBorder ? imageGap : 0.0;

    final double outputWidth;
    if (fixedWidth != null) {
      outputWidth = fixedWidth.toDouble();
    } else {
      var maxImgW = capImg.width.toDouble();
      if (refImg != null && refImg.width > maxImgW) {
        maxImgW = refImg.width.toDouble();
      }
      outputWidth = ((maxImgW + 2 * effectiveInset) / (1 - 2 * borderPct / 100))
          .roundToDouble();
    }

    final borderPx = (outputWidth * borderPct / 100).roundToDouble();
    final contentWidth = outputWidth - 2 * borderPx - 2 * effectiveInset;

    var refHeight = 0.0;
    if (refImg != null) {
      refHeight = refImg.height / refImg.width * contentWidth;
    }
    final capHeight = capImg.height / capImg.width * contentWidth;

    final metaLayout = _ComparisonMetaLayout.from(
      width: contentWidth,
      config: config,
      metadata: metadata,
      colorGradingSummary: colorGradingSummary,
    );

    final imgAreaHeight =
        (refImg != null ? refHeight + effectiveImageGap : 0) + capHeight;
    final metaGap = metaLayout.hasContent ? effectiveInset : 0.0;
    final totalHeight =
        borderPx * 2 +
        effectiveInset * 2 +
        imgAreaHeight +
        metaGap +
        metaLayout.height;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, outputWidth, totalHeight),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, outputWidth, totalHeight),
        Radius.circular(hasBorder ? 16.0 : 0),
      ),
      Paint()..color = Colors.white,
    );

    var y = borderPx + effectiveInset;
    if (refImg != null) {
      _drawLabeledImage(
        canvas,
        refImg,
        borderPx + effectiveInset,
        y,
        contentWidth,
        refHeight,
        config.showLabels ? '参考' : '',
      );
      y += refHeight + effectiveImageGap;
    }

    _drawLabeledImage(
      canvas,
      capImg,
      borderPx + effectiveInset,
      y,
      contentWidth,
      capHeight,
      config.showLabels ? '巡礼' : '',
    );
    y += capHeight + metaGap;

    if (metaLayout.hasContent) {
      _drawMetadata(
        canvas,
        borderPx + effectiveInset,
        y,
        contentWidth,
        metaLayout,
      );
    }

    if (hasBorder) {
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
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(x, y, width, height),
      Paint(),
    );

    if (label.isNotEmpty) {
      final labelPainter = TextPainter(
        text: const TextSpan(
          style: TextStyle(
            color: Colors.white,
            fontSize: labelFontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      labelPainter.text = TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: labelFontSize,
          fontWeight: FontWeight.w700,
        ),
      );
      labelPainter.layout(maxWidth: width - 24);

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

      labelPainter.paint(canvas, Offset(x + 10 + hPad, y + 8 + vPad));
    }
  }

  void _drawMetadata(
    Canvas canvas,
    double x,
    double y,
    double width,
    _ComparisonMetaLayout layout,
  ) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, width, layout.height),
        Radius.circular(layout.radius),
      ),
      Paint()..color = const Color(0xFFF4F5F7),
    );

    var currentY = y + layout.paddingV;
    if (layout.title.isNotEmpty) {
      final titlePainter = TextPainter(
        text: TextSpan(
          text: layout.title,
          style: TextStyle(
            color: const Color(0xFF1D1F23),
            fontSize: layout.titleFontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
            height: 1.12,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '...',
      )..layout(maxWidth: layout.mainWidth);
      titlePainter.paint(canvas, Offset(x + layout.paddingH, currentY));
      currentY += titlePainter.height + layout.titleSubtitleGap;
    }

    if (layout.subtitle.isNotEmpty) {
      final subtitlePainter = TextPainter(
        text: TextSpan(
          text: layout.subtitle,
          style: TextStyle(
            color: const Color(0xFF5F646D),
            fontSize: layout.subtitleFontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            height: 1.22,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '...',
      )..layout(maxWidth: layout.mainWidth);
      subtitlePainter.paint(canvas, Offset(x + layout.paddingH, currentY));
      currentY += subtitlePainter.height;
    }

    if (layout.tags.isNotEmpty) {
      currentY += layout.subtitleTagGap;
      var tagX = x + layout.paddingH;
      var tagY = currentY;
      final maxX = x + layout.paddingH + layout.mainWidth;
      for (final tag in layout.tags) {
        final tagPainter = TextPainter(
          text: TextSpan(
            text: tag,
            style: TextStyle(
              color: const Color(0xFF6E747D),
              fontSize: layout.tagFontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '...',
        )..layout(maxWidth: width - layout.paddingH * 2);
        final tagWidth = tagPainter.width + layout.tagPadH * 2;
        final tagHeight = layout.tagFontSize * 1.25 + layout.tagPadV * 2;
        if (tagX > x + layout.paddingH && tagX + tagWidth > maxX) {
          tagX = x + layout.paddingH;
          tagY += tagHeight + layout.tagGap;
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(tagX, tagY, tagWidth, tagHeight),
            Radius.circular(layout.tagRadius),
          ),
          Paint()..color = Colors.white,
        );
        tagPainter.paint(
          canvas,
          Offset(
            tagX + layout.tagPadH,
            tagY + (tagHeight - tagPainter.height) / 2,
          ),
        );
        tagX += tagWidth + layout.tagGap;
      }
    }

    if (layout.pilgrimName.isNotEmpty) {
      final labelPainter = TextPainter(
        text: TextSpan(
          text: '巡礼者',
          style: TextStyle(
            color: const Color(0xFF8A9099),
            fontSize: layout.pilgrimLabelFontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
        maxLines: 1,
      )..layout(maxWidth: layout.signatureWidth);
      final namePainter = TextPainter(
        text: TextSpan(
          text: layout.pilgrimName,
          style: TextStyle(
            color: const Color(0xFF1D1F23),
            fontSize: layout.pilgrimNameFontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
            height: 1.1,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
        maxLines: 2,
        ellipsis: '...',
      )..layout(maxWidth: layout.signatureWidth);
      final signatureHeight =
          labelPainter.height + layout.pilgrimGap + namePainter.height;
      final signatureX = x + width - layout.paddingH - layout.signatureWidth;
      final signatureY = y + (layout.height - signatureHeight) / 2;
      labelPainter.paint(
        canvas,
        Offset(
          signatureX + layout.signatureWidth - labelPainter.width,
          signatureY,
        ),
      );
      namePainter.paint(
        canvas,
        Offset(
          signatureX + layout.signatureWidth - namePainter.width,
          signatureY + labelPainter.height + layout.pilgrimGap,
        ),
      );
    }

    if (layout.colorGradingSummary.isNotEmpty) {
      final summaryPainter = TextPainter(
        text: TextSpan(
          text: layout.colorGradingSummary,
          style: TextStyle(
            color: const Color(0xFF8A9099),
            fontSize: layout.gradingFontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            height: 1.25,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '...',
      )..layout(maxWidth: width - layout.paddingH * 2);
      summaryPainter.paint(
        canvas,
        Offset(
          x + layout.paddingH,
          y + layout.height - layout.paddingV - summaryPainter.height,
        ),
      );
    }
  }

  Future<ui.Image?> _decodeImage(Uint8List bytes) {
    final completer = Completer<ui.Image?>();
    ui.decodeImageFromList(bytes, (img) => completer.complete(img));
    return completer.future;
  }
}

class _ComparisonMetaLayout {
  const _ComparisonMetaLayout({
    required this.title,
    required this.subtitle,
    required this.tags,
    required this.pilgrimName,
    required this.colorGradingSummary,
    required this.height,
    required this.mainWidth,
    required this.signatureWidth,
    required this.paddingH,
    required this.paddingV,
    required this.radius,
    required this.titleFontSize,
    required this.subtitleFontSize,
    required this.tagFontSize,
    required this.titleSubtitleGap,
    required this.subtitleTagGap,
    required this.tagGap,
    required this.tagPadH,
    required this.tagPadV,
    required this.tagRadius,
    required this.pilgrimLabelFontSize,
    required this.pilgrimNameFontSize,
    required this.pilgrimGap,
    required this.gradingFontSize,
  });

  final String title;
  final String subtitle;
  final List<String> tags;
  final String pilgrimName;
  final String colorGradingSummary;
  final double height;
  final double mainWidth;
  final double signatureWidth;
  final double paddingH;
  final double paddingV;
  final double radius;
  final double titleFontSize;
  final double subtitleFontSize;
  final double tagFontSize;
  final double titleSubtitleGap;
  final double subtitleTagGap;
  final double tagGap;
  final double tagPadH;
  final double tagPadV;
  final double tagRadius;
  final double pilgrimLabelFontSize;
  final double pilgrimNameFontSize;
  final double pilgrimGap;
  final double gradingFontSize;

  bool get hasContent =>
      title.isNotEmpty ||
      subtitle.isNotEmpty ||
      tags.isNotEmpty ||
      pilgrimName.isNotEmpty ||
      colorGradingSummary.isNotEmpty;

  factory _ComparisonMetaLayout.from({
    required double width,
    required ComparisonExportConfig config,
    required Map<ComparisonMetadataField, String> metadata,
    required String? colorGradingSummary,
  }) {
    final scale = (width / 1080).clamp(0.78, 2.4).toDouble();
    final paddingH = 40.0 * scale;
    final paddingV = 34.0 * scale;
    final titleFontSize = 44.0 * scale;
    final subtitleFontSize = 27.0 * scale;
    final tagFontSize = 22.0 * scale;
    final titleSubtitleGap = 12.0 * scale;
    final subtitleTagGap = 24.0 * scale;
    final tagGap = 12.0 * scale;
    final tagPadH = 18.0 * scale;
    final tagPadV = 8.0 * scale;
    final radius = 12.0 * scale;
    final tagRadius = 6.0 * scale;
    final pilgrimName = config.showPilgrimName ? config.pilgrimName.trim() : '';
    final signatureWidth = pilgrimName.isEmpty
        ? 0.0
        : min(width * 0.28, 300.0 * scale);
    final signatureGap = pilgrimName.isEmpty ? 0.0 : 34.0 * scale;
    final mainWidth = max(
      width - paddingH * 2 - signatureWidth - signatureGap,
      width * 0.52,
    );
    final pilgrimLabelFontSize = 18.0 * scale;
    final pilgrimNameFontSize = 30.0 * scale;
    final pilgrimGap = 8.0 * scale;
    final gradingFontSize = 17.0 * scale;
    final gradingSummary = config.showColorGradingParams
        ? (colorGradingSummary?.trim() ?? '')
        : '';

    String value(ComparisonMetadataField field) {
      if (!config.metadataFields.contains(field)) return '';
      return metadata[field]?.trim() ?? '';
    }

    final point = value(ComparisonMetadataField.pointName);
    final work = value(ComparisonMetadataField.workTitle);
    final capturedAt = value(ComparisonMetadataField.capturedAt);
    final episode = value(ComparisonMetadataField.episodeLabel);
    final coordinates = value(ComparisonMetadataField.coordinates);
    final anitabiId = value(ComparisonMetadataField.anitabiId);

    final title = point.isNotEmpty
        ? point
        : work.isNotEmpty
        ? work
        : capturedAt;
    final subtitleParts = <String>[
      if (point.isNotEmpty && work.isNotEmpty) work,
      if (capturedAt.isNotEmpty) capturedAt,
    ];
    final tags = <String>[
      if (episode.isNotEmpty) episode,
      if (coordinates.isNotEmpty) coordinates,
      if (anitabiId.isNotEmpty) 'Anitabi $anitabiId',
    ];
    final subtitle = subtitleParts.join(' · ');

    double textHeight(
      String text,
      double fontSize,
      FontWeight weight,
      double lineHeight, {
      int maxLines = 2,
    }) {
      if (text.isEmpty) return 0;
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: weight,
            height: lineHeight,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: maxLines,
        ellipsis: '...',
      )..layout(maxWidth: mainWidth);
      return painter.height;
    }

    final titleHeight = textHeight(title, titleFontSize, FontWeight.w800, 1.12);
    final subtitleHeight = textHeight(
      subtitle,
      subtitleFontSize,
      FontWeight.w600,
      1.22,
    );
    var tagRows = 0;
    if (tags.isNotEmpty) {
      var rowWidth = 0.0;
      tagRows = 1;
      final maxTagAreaWidth = mainWidth;
      for (final tag in tags) {
        final painter = TextPainter(
          text: TextSpan(
            text: tag,
            style: TextStyle(
              fontSize: tagFontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '...',
        )..layout(maxWidth: maxTagAreaWidth);
        final itemWidth = painter.width + tagPadH * 2;
        final needed = rowWidth == 0
            ? itemWidth
            : rowWidth + tagGap + itemWidth;
        if (needed > maxTagAreaWidth && rowWidth > 0) {
          tagRows += 1;
          rowWidth = itemWidth;
        } else {
          rowWidth = needed;
        }
      }
    }
    final tagHeight = tagRows == 0
        ? 0.0
        : tagRows * (tagFontSize * 1.25 + tagPadV * 2) + (tagRows - 1) * tagGap;
    final gradingHeight = gradingSummary.isEmpty
        ? 0.0
        : gradingFontSize * 2.5 + 16.0 * scale;
    final mainHeight =
        title.isEmpty &&
            subtitle.isEmpty &&
            tags.isEmpty &&
            gradingSummary.isEmpty
        ? 0.0
        : paddingV * 2 +
              titleHeight +
              (title.isNotEmpty && subtitle.isNotEmpty ? titleSubtitleGap : 0) +
              subtitleHeight +
              ((title.isNotEmpty || subtitle.isNotEmpty) && tags.isNotEmpty
                  ? subtitleTagGap
                  : 0) +
              tagHeight +
              gradingHeight;
    final signatureHeight = pilgrimName.isEmpty
        ? 0.0
        : paddingV * 2 +
              pilgrimLabelFontSize * 1.2 +
              pilgrimGap +
              pilgrimNameFontSize * 2.2;
    final height = max(mainHeight, signatureHeight);

    return _ComparisonMetaLayout(
      title: title,
      subtitle: subtitle,
      tags: tags,
      pilgrimName: pilgrimName,
      colorGradingSummary: gradingSummary,
      height: height,
      mainWidth: mainWidth,
      signatureWidth: signatureWidth,
      paddingH: paddingH,
      paddingV: paddingV,
      radius: radius,
      titleFontSize: titleFontSize,
      subtitleFontSize: subtitleFontSize,
      tagFontSize: tagFontSize,
      titleSubtitleGap: titleSubtitleGap,
      subtitleTagGap: subtitleTagGap,
      tagGap: tagGap,
      tagPadH: tagPadH,
      tagPadV: tagPadV,
      tagRadius: tagRadius,
      pilgrimLabelFontSize: pilgrimLabelFontSize,
      pilgrimNameFontSize: pilgrimNameFontSize,
      pilgrimGap: pilgrimGap,
      gradingFontSize: gradingFontSize,
    );
  }
}
