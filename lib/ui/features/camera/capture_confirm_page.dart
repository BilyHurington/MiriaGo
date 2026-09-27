import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/capture/capture_session.dart';
import '../../../application/capture/visit_record_commit.dart';
import '../../../application/platform_capabilities.dart';
import '../../../camera_reference/photo_location_save_stub.dart'
    if (dart.library.io) '../../../camera_reference/photo_location_save_io.dart'
    as photo_location_save;
import '../../../data/anitabi_image_source_scope.dart';
import '../../../plan/pilgrimage_plan_controller.dart';
import '../../../records/gallery_saver_stub.dart'
    if (dart.library.io) '../../../records/gallery_saver_io.dart';
import '../../../widgets/bounded_image.dart';
import '../../../widgets/reference_image_source_stub.dart'
    if (dart.library.io) '../../../widgets/reference_image_source_io.dart';
import '../../app/toast.dart';
import '../../components/components.dart';
import '../viewer/image_viewer.dart';

/// Pushes the confirmation page for [request]; resolves with
/// [VisitRecordConfirmationResult.completed] / `.saved`, or null when
/// cancelled.
Future<VisitRecordConfirmationResult?> openCaptureConfirmation(
  BuildContext context, {
  required CaptureConfirmationRequest request,
  required PilgrimagePlanController? controller,
}) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push<VisitRecordConfirmationResult>(
    MaterialPageRoute<VisitRecordConfirmationResult>(
      settings: const RouteSettings(name: 'capture-confirm'),
      builder: (_) => CaptureConfirmPage(
        commit: VisitRecordCommit(
          point: request.point,
          controller: controller,
          photoPath: request.photoPath,
          referenceMode: request.referenceMode,
          referenceBytes: request.referenceBytes,
          referenceImagePath: request.referenceImagePath,
          referenceImageUrl: request.referenceImageUrl,
          capturedAtOverride: request.capturedAtOverride,
          settings: request.settings,
          saveVisitPhotoToGallery: request.saveVisitPhotoToGallery,
          autoSaveComparisonToGallery: request.autoSaveComparisonToGallery,
          photoLocationStrategy: request.photoLocationStrategy,
          writePhotoLocation: request.writePhotoLocation,
          discardSourcePhoto: request.discardSourcePhoto,
        ),
      ),
    ),
  );
}

/// 确认记录 (DESIGN §8.6): comparison, info, photo location status, staged
/// progress and the save buttons. Owns and disposes [commit].
class CaptureConfirmPage extends StatefulWidget {
  const CaptureConfirmPage({
    required this.commit,
    this.retainPhotoPreview = photo_location_save.retainPhotoPreviewUntilRead,
    super.key,
  });

  final VisitRecordCommit commit;

  /// Keeps the source photo until the preview's bounded read finished.
  final Future<void> Function(String path, BuildContext context)
  retainPhotoPreview;

  @override
  State<CaptureConfirmPage> createState() => _CaptureConfirmPageState();
}

class _CaptureConfirmPageState extends State<CaptureConfirmPage> {
  VisitRecordCommit get _commit => widget.commit;
  bool _previewRetained = false;
  bool? _savingComplete;
  PhotoCompareMode _compareMode = PhotoCompareMode.stacked;

  @override
  void initState() {
    super.initState();
    _commit.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _commit.start();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_previewRetained) {
      _previewRetained = true;
      _commit.attachPreviewRead(
        () => widget.retainPhotoPreview(_commit.photoPath, context),
      );
    }
  }

  @override
  void dispose() {
    _commit.removeListener(_changed);
    _commit.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _save({required bool completePoint}) async {
    if (!_commit.canSave) return;
    setState(() => _savingComplete = completePoint);
    final outcome = await _commit.save(completePoint: completePoint);
    if (!mounted || outcome == null) return;
    context.showToast(
      outcome.message,
      kind: outcome.isError ? ToastKind.error : ToastKind.success,
    );
    final result = outcome.result;
    if (result != null) Navigator.of(context).pop(result);
  }

  void _cancel() {
    if (!_commit.canCancel) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final twoColumns =
        layout.width >= 720 || (layout.isShort && layout.width > layout.height);
    final saving = _commit.saving;
    return PopScope(
      canPop: !_commit.blocksPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _commit.saving) {
          context.showToast('正在保存记录，请稍候。', kind: ToastKind.running);
        }
      },
      child: MiriaPageScaffold(
        title: '确认记录',
        body: twoColumns ? _buildWide(context) : _buildNarrow(context),
        bottomBar: twoColumns
            ? null
            : _ConfirmButtons(
                commit: _commit,
                savingComplete: saving ? _savingComplete : null,
                onSave: _save,
                onCancel: _cancel,
              ),
      ),
    );
  }

  Widget _buildNarrow(BuildContext context) {
    final gutter = context.layout.gutter;
    return ListView(
      padding: EdgeInsets.fromLTRB(gutter, Space.x2, gutter, Space.x6),
      children: [
        ContentColumn(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _compare(context),
              const SizedBox(height: Space.x4),
              ..._details(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWide(BuildContext context) {
    final gutter = context.layout.gutter;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: ListView(
            padding: EdgeInsets.fromLTRB(gutter, Space.x2, Space.x3, Space.x6),
            children: [_compare(context)],
          ),
        ),
        SizedBox(
          width: context.layout.width >= 1000 ? 380 : 320,
          child: ListView(
            padding: EdgeInsets.fromLTRB(Space.x3, Space.x2, gutter, Space.x6),
            children: [
              ..._details(context),
              const SizedBox(height: Space.x4),
              _ConfirmButtons(
                commit: _commit,
                savingComplete: _commit.saving ? _savingComplete : null,
                onSave: _save,
                onCancel: _cancel,
                stacked: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _details(BuildContext context) {
    final c = context.colors;
    final point = _commit.point;
    final status = _commit.locationStatus;
    final stage = _commit.savingStage;
    return [
      Text(
        point.name,
        locale: MiriaFonts.japanese,
        style: context.text.titleLarge,
      ),
      const SizedBox(height: Space.x1),
      Text(
        '${point.work.title} / ${point.displayEpisodeLabel}',
        style: context.text.bodyMedium?.copyWith(color: c.textSecondary),
      ),
      const SizedBox(height: Space.x3),
      _Panel(
        child: Row(
          children: [
            Icon(Symbols.layers_rounded, color: c.textSecondary, size: 20),
            const SizedBox(width: Space.x2),
            Expanded(
              child: Text(
                '参考模式',
                style: context.text.labelLarge?.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ),
            Text(_commit.referenceMode, style: context.text.labelLarge),
          ],
        ),
      ),
      if (status != null) ...[
        const SizedBox(height: Space.x2),
        PhotoLocationStatusRow(
          label: status,
          loading: _commit.locating,
          onSkip: _commit.canSkipLocation ? _commit.skipLocation : null,
        ),
      ],
      AnimatedSize(
        duration: Motion.of(context, Motion.standard),
        alignment: Alignment.topCenter,
        child: stage == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: Space.x2),
                child: _Panel(
                  key: const ValueKey('capture-confirm-stage'),
                  muted: true,
                  child: Row(
                    children: [
                      const ProgressRing(size: 18, strokeWidth: 2),
                      const SizedBox(width: Space.x3),
                      Expanded(
                        child: Text(
                          stage,
                          style: context.text.labelLarge?.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    ];
  }

  ImageProvider? _referenceProvider(BuildContext context) {
    final bytes = _commit.referenceBytes;
    if (bytes != null) return BoundedImageProvider(bytes: bytes);
    final path = _commit.referenceImagePath;
    if (referenceImageLocalPathCanDisplay(path)) {
      return BoundedImageProvider(path: path);
    }
    final url = _commit.referenceImageUrl;
    if (url != null) {
      return BoundedImageProvider(
        path: url,
        source: AnitabiImageSourceScope.of(context),
      );
    }
    return null;
  }

  Widget _compare(BuildContext context) {
    // Same key as the preview read lease (retainPhotoPreviewUntilRead).
    final photo = BoundedImageProvider(path: _commit.photoPath);
    final reference = _referenceProvider(context);
    final canSaveToGallery =
        context.read<PlatformCapabilities?>()?.canSaveToGallery ?? false;
    final photoWidget = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: canSaveToGallery ? () => _showGallerySave(context) : null,
      child: Image(
        image: photo,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, _, _) =>
            const _ImagePlaceholder(icon: Symbols.broken_image_rounded),
      ),
    );
    final referenceWidget = reference == null
        ? const _ImagePlaceholder(icon: Symbols.image_not_supported_rounded)
        : Image(
            image: reference,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, _, _) =>
                const _ImagePlaceholder(icon: Symbols.broken_image_rounded),
          );
    return AbsorbPointer(
      absorbing: _commit.saving,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedControl<PhotoCompareMode>(
            semanticLabel: '对比方式',
            options: [
              for (final mode in const [
                PhotoCompareMode.stacked,
                PhotoCompareMode.slider,
              ])
                SegmentOption(value: mode, label: mode.label, icon: mode.icon),
            ],
            value: _compareMode,
            onChanged: (mode) => setState(() => _compareMode = mode),
          ),
          const SizedBox(height: Space.x3),
          _AspectAwareCompare(
            reference: reference,
            photo: photo,
            referenceWidget: referenceWidget,
            photoWidget: photoWidget,
            mode: _compareMode,
            onTapReference: reference == null ? null : _openReference,
            onTapPhoto: _openPhoto,
          ),
        ],
      ),
    );
  }

  void _openReference() {
    unawaited(
      openImageViewer(
        context,
        images: [
          ViewerImage(
            bytes: _commit.referenceBytes,
            path: _commit.referenceBytes == null
                ? (referenceImageLocalPathCanDisplay(_commit.referenceImagePath)
                      ? _commit.referenceImagePath
                      : null)
                : null,
            url:
                _commit.referenceBytes == null &&
                    !referenceImageLocalPathCanDisplay(
                      _commit.referenceImagePath,
                    )
                ? _commit.referenceImageUrl
                : null,
            label: '参考图',
          ),
          ViewerImage(path: _commit.photoPath, label: '巡礼图'),
        ],
      ),
    );
  }

  void _openPhoto() {
    unawaited(
      openImageViewer(
        context,
        images: [ViewerImage(path: _commit.photoPath, label: '巡礼图')],
      ),
    );
  }

  Future<void> _showGallerySave(BuildContext context) async {
    await showActionMenu(
      context,
      actions: [
        MenuAction(
          label: '保存到相册',
          icon: Symbols.download_rounded,
          onSelected: () async {
            final success = await saveImageToGallery(_commit.photoPath);
            if (!mounted) return;
            this.context.showToast(
              success ? '已保存到相册' : '保存失败，请稍后重试。',
              kind: success ? ToastKind.success : ToastKind.error,
            );
          },
        ),
      ],
    );
  }
}

/// Resolves both image ratios before handing them to [PhotoCompare], so the
/// frames match the photos (widgets keep their long-press handler).
class _AspectAwareCompare extends StatefulWidget {
  const _AspectAwareCompare({
    required this.reference,
    required this.photo,
    required this.referenceWidget,
    required this.photoWidget,
    required this.mode,
    required this.onTapReference,
    required this.onTapPhoto,
  });

  final ImageProvider? reference;
  final ImageProvider photo;
  final Widget referenceWidget;
  final Widget photoWidget;
  final PhotoCompareMode mode;
  final VoidCallback? onTapReference;
  final VoidCallback onTapPhoto;

  @override
  State<_AspectAwareCompare> createState() => _AspectAwareCompareState();
}

class _AspectAwareCompareState extends State<_AspectAwareCompare> {
  double? _referenceRatio;
  double? _photoRatio;
  final List<(ImageStream, ImageStreamListener)> _streams = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _AspectAwareCompare oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reference != widget.reference ||
        oldWidget.photo != widget.photo) {
      _resolve();
    }
  }

  void _resolve() {
    _stop();
    final config = createLocalImageConfiguration(context);
    void listen(ImageProvider? provider, void Function(double) set) {
      if (provider == null) return;
      final stream = provider.resolve(config);
      final listener = ImageStreamListener((info, _) {
        final ratio = info.image.width / info.image.height;
        if (mounted && ratio.isFinite && ratio > 0) setState(() => set(ratio));
      }, onError: (_, _) {});
      stream.addListener(listener);
      _streams.add((stream, listener));
    }

    listen(widget.reference, (r) => _referenceRatio = r);
    listen(widget.photo, (r) => _photoRatio = r);
  }

  void _stop() {
    for (final (stream, listener) in _streams) {
      stream.removeListener(listener);
    }
    _streams.clear();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final referenceRatio = _referenceRatio ?? _photoRatio ?? 16 / 9;
    return PhotoCompare(
      reference: widget.referenceWidget,
      photo: widget.photoWidget,
      referenceAspectRatio: referenceRatio,
      photoAspectRatio: _photoRatio ?? referenceRatio,
      mode: widget.mode,
      showModeSelector: false,
      onTapReference: widget.onTapReference,
      onTapPhoto: widget.onTapPhoto,
    );
  }
}

/// Location status row: spinner or pin, status text and 跳过 (old
/// `PhotoLocationStatusPanel`).
class PhotoLocationStatusRow extends StatelessWidget {
  const PhotoLocationStatusRow({
    required this.label,
    required this.loading,
    this.onSkip,
    super.key,
  });

  final String label;
  final bool loading;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _Panel(
      muted: true,
      padding: const EdgeInsets.fromLTRB(
        Space.x3,
        Space.x2,
        Space.x2,
        Space.x2,
      ),
      child: Row(
        children: [
          if (loading)
            const ProgressRing(size: 18, strokeWidth: 2)
          else
            Icon(Symbols.location_on_rounded, size: 18, color: c.textSecondary),
          const SizedBox(width: Space.x3),
          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.of(context, Motion.fast),
              child: Text(
                label,
                key: ValueKey((label, loading)),
                style: context.text.labelLarge?.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ),
          ),
          if (onSkip != null) ...[
            const SizedBox(width: Space.x2),
            MiriaButton.secondary(
              key: const ValueKey('capture-confirm-skip-location'),
              label: '跳过',
              size: MiriaButtonSize.sm,
              onPressed: onSkip,
            ),
          ],
        ],
      ),
    );
  }
}

class _ConfirmButtons extends StatelessWidget {
  const _ConfirmButtons({
    required this.commit,
    required this.savingComplete,
    required this.onSave,
    required this.onCancel,
    this.stacked = false,
  });

  final VisitRecordCommit commit;

  /// Which save is running (true = 保存并标记完成); null when idle.
  final bool? savingComplete;
  final Future<void> Function({required bool completePoint}) onSave;
  final VoidCallback onCancel;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final canSave = commit.canSave;
    final complete = MiriaButton(
      key: const ValueKey('capture-confirm-complete'),
      label: '保存并标记完成',
      shortLabel: '完成',
      icon: Symbols.task_alt_rounded,
      size: MiriaButtonSize.lg,
      expand: true,
      loading: savingComplete == true,
      onPressed: canSave ? () => onSave(completePoint: true) : null,
    );
    final save = MiriaButton.secondary(
      key: const ValueKey('capture-confirm-save'),
      label: savingComplete == false ? '保存中' : '保存记录',
      shortLabel: '保存',
      icon: Symbols.save_rounded,
      expand: true,
      loading: savingComplete == false,
      onPressed: canSave ? () => onSave(completePoint: false) : null,
    );
    final cancel = MiriaButton.ghost(
      key: const ValueKey('capture-confirm-cancel'),
      label: '取消',
      expand: true,
      onPressed: commit.canCancel ? onCancel : null,
    );
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          complete,
          const SizedBox(height: Space.x2),
          save,
          const SizedBox(height: Space.x2),
          cancel,
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        complete,
        const SizedBox(height: Space.x2),
        Row(
          children: [
            Expanded(child: cancel),
            const SizedBox(width: Space.x2),
            Expanded(child: save),
          ],
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.muted = false,
    this.padding = const EdgeInsets.all(Space.x3),
    super.key,
  });

  final Widget child;
  final bool muted;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: muted ? c.surfaceMuted : c.surface,
        borderRadius: Radii.smAll,
        border: Border.all(color: c.hairline),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ColoredBox(
      color: c.surfaceMuted,
      child: Center(child: Icon(icon, color: c.textTertiary, size: 32)),
    );
  }
}
