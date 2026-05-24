import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../plan/pilgrimage_models.dart';
import '../plan/pilgrimage_plan_controller.dart';
import '../records/visit_record_photo_stub.dart'
    if (dart.library.io) '../records/visit_record_photo_io.dart';
import 'camera_storage_stub.dart'
    if (dart.library.io) 'camera_storage_io.dart'
    as camera_storage;

class VisitRecordConfirmationScreen extends StatefulWidget {
  const VisitRecordConfirmationScreen({
    required this.point,
    required this.controller,
    required this.photoPath,
    required this.referenceMode,
    this.referenceBytes,
    this.referenceImageUrl,
    super.key,
  });

  final PilgrimagePoint point;
  final PilgrimagePlanController? controller;
  final String photoPath;
  final String referenceMode;
  final Uint8List? referenceBytes;
  final String? referenceImageUrl;

  @override
  State<VisitRecordConfirmationScreen> createState() =>
      _VisitRecordConfirmationScreenState();
}

class _VisitRecordConfirmationScreenState
    extends State<VisitRecordConfirmationScreen> {
  bool _saving = false;

  Future<void> _save({required bool completePoint}) async {
    final controller = widget.controller;
    if (controller == null || _saving) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _saving = true);

    String? referenceImagePath;
    final referenceBytes = widget.referenceBytes;
    if (referenceBytes != null) {
      referenceImagePath = await camera_storage.saveRecordImageBytes(
        bytes: referenceBytes,
        prefix: 'reference',
      );
    }

    await controller.createVisitRecord(
      point: widget.point,
      photoPath: widget.photoPath,
      referenceImagePath: referenceImagePath,
      referenceImageUrl: referenceImagePath == null
          ? widget.referenceImageUrl
          : null,
      referenceMode: widget.referenceMode,
    );

    if (completePoint) {
      controller.completePoint(widget.point);
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(completePoint ? '已保存并标记完成' : '已保存巡礼记录')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('确认记录')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            widget.point.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.point.work.title} / ${widget.point.episodeLabel}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 16),
          _ComparisonPanel(
            photoPath: widget.photoPath,
            referenceBytes: widget.referenceBytes,
            referenceImageUrl: widget.referenceImageUrl,
          ),
          const SizedBox(height: 16),
          _InfoPanel(referenceMode: widget.referenceMode),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : () => _save(completePoint: false),
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(_saving ? '保存中' : '保存记录'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _saving ? null : () => _save(completePoint: true),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('保存并标记完成'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }
}

class _ComparisonPanel extends StatelessWidget {
  const _ComparisonPanel({
    required this.photoPath,
    required this.referenceBytes,
    required this.referenceImageUrl,
  });

  final String photoPath;
  final Uint8List? referenceBytes;
  final String? referenceImageUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ImageCompareTile(
            label: '参考图',
            child: _ReferencePreview(
              bytes: referenceBytes,
              imageUrl: referenceImageUrl,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ImageCompareTile(
            label: '巡礼图',
            child: VisitRecordPhoto(path: photoPath),
          ),
        ),
      ],
    );
  }
}

class _ImageCompareTile extends StatelessWidget {
  const _ImageCompareTile({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: child,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _ReferencePreview extends StatelessWidget {
  const _ReferencePreview({required this.bytes, required this.imageUrl});

  final Uint8List? bytes;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final localBytes = bytes;
    if (localBytes != null) {
      return Image.memory(localBytes, fit: BoxFit.cover);
    }

    final url = imageUrl;
    if (url != null) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const _ReferencePlaceholder();
        },
      );
    }

    return const _ReferencePlaceholder();
  }
}

class _ReferencePlaceholder extends StatelessWidget {
  const _ReferencePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surfaceMuted,
      child: Center(
        child: Icon(Icons.image_outlined, color: AppColors.accentDark),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.referenceMode});

  final String referenceMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.layers_outlined, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          const Text(
            '参考模式',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const Spacer(),
          Text(
            referenceMode,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
