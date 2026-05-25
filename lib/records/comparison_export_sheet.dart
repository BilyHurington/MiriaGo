import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../widgets/image_viewer_screen.dart';
import 'comparison_export_config.dart';
import 'comparison_exporter_stub.dart'
    if (dart.library.io) 'comparison_exporter_io.dart';

class ComparisonExportSheet extends StatefulWidget {
  const ComparisonExportSheet({
    required this.referenceImagePath,
    required this.referenceImageUrl,
    required this.capturedPath,
    required this.metadata,
    super.key,
  });

  final String? referenceImagePath;
  final String? referenceImageUrl;
  final String capturedPath;
  final Map<ComparisonMetadataField, String> metadata;

  static Future<void> show(
    BuildContext context, {
    required String? referenceImagePath,
    required String? referenceImageUrl,
    required String capturedPath,
    required Map<ComparisonMetadataField, String> metadata,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => ComparisonExportSheet(
        referenceImagePath: referenceImagePath,
        referenceImageUrl: referenceImageUrl,
        capturedPath: capturedPath,
        metadata: metadata,
      ),
    );
  }

  @override
  State<ComparisonExportSheet> createState() => _ComparisonExportSheetState();
}

class _ComparisonExportSheetState extends State<ComparisonExportSheet> {
  var _config = ComparisonExportConfig.lastUsed;
  var _exporting = false;

  static const _borderColorOptions = <Color>[
    Colors.white,
    Colors.black,
    AppColors.accent,
  ];

  static const _borderColorLabels = <String>['白色', '黑色', '主题绿'];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '导出对比图',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _SectionLabel('外观'),
            const SizedBox(height: 8),
            const Text(
              '边框宽度',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ComparisonBorderWidth.values.map((bw) {
                return ChoiceChip(
                  label: Text(
                    bw.label,
                    style: TextStyle(
                      color: _config.borderWidth == bw
                          ? Colors.white
                          : AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  selected: _config.borderWidth == bw,
                  selectedColor: AppColors.accent,
                  backgroundColor: AppColors.surfaceMuted,
                  side: BorderSide(
                    color: _config.borderWidth == bw
                        ? AppColors.accent
                        : AppColors.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onSelected: (_) {
                    setState(() => _config = _config.copyWith(borderWidth: bw));
                  },
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 12),
            const Text(
              '边框颜色',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 0; i < _borderColorOptions.length; i += 1) ...[
                  if (i > 0) const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _config = _config.copyWith(
                          borderColor: _borderColorOptions[i],
                        );
                      });
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _borderColorOptions[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _config.borderColor == _borderColorOptions[i]
                              ? AppColors.accent
                              : _borderColorOptions[i] == Colors.white
                                  ? AppColors.border
                                  : Colors.transparent,
                          width: _config.borderColor == _borderColorOptions[i]
                              ? 3
                              : 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _borderColorLabels[i],
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  '显示标签',
                  style: TextStyle(fontSize: 14, letterSpacing: 0),
                ),
                const Spacer(),
                Switch(
                  value: _config.showLabels,
                  onChanged: (v) {
                    setState(() => _config = _config.copyWith(showLabels: v));
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _SectionLabel('元数据'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: ComparisonMetadataField.values.map((field) {
                final selected = _config.metadataFields.contains(field);
                return SizedBox(
                  width: (MediaQuery.of(context).size.width - 48) / 2,
                  child: Row(
                    children: [
                      Checkbox(
                        value: selected,
                        onChanged: (_) {
                          setState(() {
                            final updated =
                                Set<ComparisonMetadataField>.from(
                                    _config.metadataFields);
                            if (selected) {
                              updated.remove(field);
                            } else {
                              updated.add(field);
                            }
                            _config =
                                _config.copyWith(metadataFields: updated);
                          });
                        },
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      Expanded(
                        child: Text(
                          field.label,
                          style: const TextStyle(
                            fontSize: 14,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _exporting ? null : _doExport,
                icon: _exporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download, size: 18),
                label: Text(_exporting ? '导出中...' : '导出'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doExport() async {
    setState(() => _exporting = true);
    ComparisonExportConfig.lastUsed = _config;

    final path = await exportComparisonImage(
      referenceImagePath: widget.referenceImagePath,
      referenceImageUrl: widget.referenceImageUrl,
      capturedPath: widget.capturedPath,
      config: _config,
      metadata: widget.metadata,
    );

    if (!mounted) return;

    if (path != null) {
      Navigator.of(context).pop();
      ImageViewerScreen.show(context, filePath: path);
    } else {
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('导出失败，请稍后重试。')),
      );
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}
