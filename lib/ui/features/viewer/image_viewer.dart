import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/platform_capabilities.dart';
import '../../../data/anitabi_image_source_scope.dart';
import '../../../data/bounded_image_decoder.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../../plan_transfer/plan_export_delivery.dart';
import '../../../plan_transfer/plan_export_delivery_result.dart';
import '../../../records/gallery_saver_stub.dart'
    if (dart.library.io) '../../../records/gallery_saver_io.dart';
import '../../../widgets/bounded_image.dart';
import '../../app/toast.dart';
import '../../components/components.dart';
import 'viewer_source.dart';

/// One image in the full-screen viewer. Exactly one source should be set.
@immutable
class ViewerImage {
  const ViewerImage({this.bytes, this.path, this.url, this.label});

  final Uint8List? bytes;

  /// Local file path, desktop asset path, or bundled `docs/sample_images/…`.
  final String? path;

  /// Remote URL (loaded through the Anitabi image source).
  final String? url;

  /// e.g. 「参考图」「巡礼图」.
  final String? label;
}

/// Loads a remote image for the viewer. Replaceable in tests.
typedef ViewerRemoteImageResolver =
    Future<Uint8List?> Function(String url, AnitabiImageSource source);

/// Test hook: overrides how remote images are read.
@visibleForTesting
ViewerRemoteImageResolver? debugViewerRemoteImageResolver;

Future<Uint8List?> _defaultRemoteResolver(
  String url,
  AnitabiImageSource source,
) => readBoundedImageSource(url, source: source);

/// Opens the full-screen image viewer (zoom, save/share original).
/// OWNER: feature agent F (settings/transfer/viewer).
Future<void> openImageViewer(
  BuildContext context, {
  required List<ViewerImage> images,
  int initialIndex = 0,
  Object? heroTag,
}) async {
  if (images.isEmpty) return;
  final source = AnitabiImageSourceScope.of(context);
  final capabilities = Provider.of<PlatformCapabilities?>(
    context,
    listen: false,
  );
  await Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: null,
      transitionDuration: Motion.of(context, Motion.emphasis),
      reverseTransitionDuration: Motion.of(context, Motion.standard),
      pageBuilder: (_, _, _) => ImageViewerPage(
        images: images,
        initialIndex: initialIndex.clamp(0, images.length - 1),
        heroTag: heroTag,
        imageSource: source,
        canSaveToGallery: capabilities?.canSaveToGallery ?? false,
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// The viewer page. Use [openImageViewer] instead of pushing it directly.
class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({
    required this.images,
    this.initialIndex = 0,
    this.heroTag,
    this.imageSource = AnitabiImageSource.auto,
    this.canSaveToGallery = false,
    this.webSave,
    super.key,
  });

  final List<ViewerImage> images;
  final int initialIndex;
  final Object? heroTag;
  final AnitabiImageSource imageSource;
  final bool canSaveToGallery;

  /// Web and Tauri only offer 「保存图片」 (default: `kIsWeb`).
  final bool? webSave;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage>
    with TickerProviderStateMixin {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  final Map<int, TransformationController> _transforms = {};
  late final AnimationController _zoomAnimation = AnimationController(
    vsync: this,
    duration: Motion.standard,
  );
  late final AnimationController _dragReset = AnimationController(
    vsync: this,
    duration: Motion.standard,
  );
  Animation<Matrix4>? _zoomTween;
  Animation<double>? _dragTween;
  final FocusNode _focus = FocusNode(debugLabel: 'image-viewer');
  bool _zoomed = false;
  double _dragOffset = 0;
  Offset? _doubleTapPosition;
  bool _closing = false;

  bool get _isWebSave => widget.webSave ?? kIsWeb;

  TransformationController _transformFor(int index) {
    return _transforms.putIfAbsent(index, () {
      final controller = TransformationController();
      controller.addListener(() {
        if (index != _index) return;
        final zoomed = controller.value.getMaxScaleOnAxis() > 1.01;
        if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
      });
      return controller;
    });
  }

  @override
  void initState() {
    super.initState();
    _zoomAnimation.addListener(() {
      final tween = _zoomTween;
      if (tween != null) _transformFor(_index).value = tween.value;
    });
    _dragReset.addListener(() {
      final tween = _dragTween;
      if (tween != null) setState(() => _dragOffset = tween.value);
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    for (final controller in _transforms.values) {
      controller.dispose();
    }
    _zoomAnimation.dispose();
    _dragReset.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  void _onPageChanged(int index) {
    _transforms[_index]?.value = Matrix4.identity();
    setState(() {
      _index = index;
      _zoomed = false;
    });
  }

  void _goTo(int delta) {
    final target = _index + delta;
    if (target < 0 || target >= widget.images.length) return;
    _pages.animateToPage(
      target,
      duration: Motion.of(context, Motion.standard),
      curve: Motion.standardCurve,
    );
  }

  void _toggleZoom() {
    final controller = _transformFor(_index);
    final current = controller.value;
    final Matrix4 target;
    if (current.getMaxScaleOnAxis() > 1.01) {
      target = Matrix4.identity();
    } else {
      const scale = 2.5;
      final position =
          _doubleTapPosition ??
          Offset(
            MediaQuery.sizeOf(context).width / 2,
            MediaQuery.sizeOf(context).height / 2,
          );
      target = Matrix4.identity()
        ..translateByDouble(
          -position.dx * (scale - 1),
          -position.dy * (scale - 1),
          0,
          1,
        )
        ..scaleByDouble(scale, scale, 1, 1);
    }
    _zoomTween = Matrix4Tween(begin: current, end: target).animate(
      CurvedAnimation(parent: _zoomAnimation, curve: Motion.emphasized),
    );
    _zoomAnimation
      ..duration = Motion.of(context, Motion.standard)
      ..forward(from: 0);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragReset.stop();
    setState(() => _dragOffset += details.delta.dy);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    if (_dragOffset.abs() > 120 || velocity.abs() > 900) {
      _close();
      return;
    }
    _dragTween = Tween<double>(
      begin: _dragOffset,
      end: 0,
    ).animate(CurvedAnimation(parent: _dragReset, curve: Motion.emphasized));
    _dragReset.forward(from: 0);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _goTo(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _goTo(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // -------------------------------------------------------------------------
  // Save / share
  // -------------------------------------------------------------------------

  void _toast(String title, ToastKind kind) {
    if (!mounted) return;
    final toasts = Provider.of<ToastController?>(context, listen: false);
    toasts?.show(ToastData(kind: kind, title: title));
  }

  Future<void> _showSaveMenu({BuildContext? anchor}) async {
    final image = widget.images[_index];
    await showActionMenu(
      context,
      title: '保存或分享原件',
      anchor: anchor,
      actions: _isWebSave
          ? [
              MenuAction(
                label: '保存图片',
                icon: Symbols.download_rounded,
                onSelected: () => _saveImageFile(image),
              ),
            ]
          : [
              MenuAction(
                label: '分享',
                icon: Symbols.ios_share_rounded,
                onSelected: () => _share(image),
              ),
              if (widget.canSaveToGallery)
                MenuAction(
                  label: '保存到相册',
                  icon: Symbols.download_rounded,
                  onSelected: () => _saveToGallery(image),
                ),
            ],
    );
  }

  Future<void> _saveImageFile(ViewerImage image) async {
    try {
      final bytes = await resolveViewerImageBytes(
        bytes: image.bytes,
        path: image.path,
        url: image.url,
        source: widget.imageSource,
      );
      if (bytes == null || bytes.isEmpty) {
        _toast('图片读取失败', ToastKind.error);
        return;
      }
      final extension = preferredImageExtension(
        bytes,
        fallbackPath: image.path ?? Uri.tryParse(image.url ?? '')?.path,
      );
      final result = await deliverPlanExport(
        bytes: bytes,
        fileName:
            'miriago_image_${DateTime.now().microsecondsSinceEpoch}.$extension',
        mimeType: mimeTypeForImageExtension(extension),
        shareSubject: 'MiriaGo 图片',
        shareText: 'MiriaGo 图片',
        extension: extension,
      );
      if (result.action == PlanExportDeliveryAction.canceled) {
        _toast('已取消保存', ToastKind.running);
        return;
      }
      _toast('图片已保存', ToastKind.success);
    } catch (_) {
      _toast('保存失败', ToastKind.error);
    }
  }

  Future<String?> _localPath(ViewerImage image) async {
    try {
      return await resolveViewerLocalPath(
        bytes: image.bytes,
        path: image.path,
        url: image.url,
        source: widget.imageSource,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _share(ViewerImage image) async {
    final path = await _localPath(image);
    if (path == null) {
      _toast('图片读取失败', ToastKind.error);
      return;
    }
    try {
      await shareViewerFile(path);
    } catch (_) {
      _toast('图片读取失败', ToastKind.error);
    }
  }

  Future<void> _saveToGallery(ViewerImage image) async {
    final path = await _localPath(image);
    if (path == null) {
      _toast('图片读取失败', ToastKind.error);
      return;
    }
    final success = await saveImageToGallery(path);
    _toast(
      success ? '已保存到相册' : '保存失败',
      success ? ToastKind.success : ToastKind.error,
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final images = widget.images;
    final image = images[_index];
    final dismissProgress = (_dragOffset.abs() / 400).clamp(0.0, 1.0);
    final multiple = images.length > 1;
    final title = [
      ?image.label,
      if (multiple) '${_index + 1} / ${images.length}',
    ].join(' · ');
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Material(
        type: MaterialType.transparency,
        child: ColoredBox(
          color: c.darkroom.withValues(alpha: 1 - dismissProgress * 0.85),
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  supportedDevices: const {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.stylus,
                  },
                  onVerticalDragUpdate: _zoomed ? null : _onDragUpdate,
                  onVerticalDragEnd: _zoomed ? null : _onDragEnd,
                  child: Transform.translate(
                    offset: Offset(0, _dragOffset),
                    child: PageView.builder(
                      controller: _pages,
                      physics: _zoomed
                          ? const NeverScrollableScrollPhysics()
                          : const PageScrollPhysics(),
                      itemCount: images.length,
                      onPageChanged: _onPageChanged,
                      itemBuilder: (context, index) => _ViewerPageItem(
                        key: ValueKey('viewer-page-$index'),
                        image: images[index],
                        imageSource: widget.imageSource,
                        heroTag: index == widget.initialIndex
                            ? widget.heroTag
                            : null,
                        transform: _transformFor(index),
                        panEnabled: index == _index && _zoomed,
                        onDoubleTapDown: (details) =>
                            _doubleTapPosition = details.localPosition,
                        onDoubleTap: _toggleZoom,
                        onLongPress: () => _showSaveMenu(),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Opacity(
                  opacity: 1 - dismissProgress,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.all(Space.x2),
                      child: Row(
                        children: [
                          MiriaIconButton(
                            key: const ValueKey('image-viewer-close'),
                            icon: Symbols.close_rounded,
                            tooltip: '关闭',
                            variant: MiriaIconButtonVariant.overlay,
                            onPressed: _close,
                          ),
                          Expanded(
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleSmall?.copyWith(
                                color: c.onDarkroom,
                                fontFeatures: MiriaFonts.tabular,
                              ),
                            ),
                          ),
                          Builder(
                            builder: (anchor) => MiriaIconButton(
                              key: const ValueKey('image-viewer-save'),
                              icon: Symbols.download_rounded,
                              tooltip: '保存或分享原件',
                              variant: MiriaIconButtonVariant.overlay,
                              onPressed: () => _showSaveMenu(anchor: anchor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (multiple)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Opacity(
                    opacity: 1 - dismissProgress,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(Space.x3),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            MiriaIconButton(
                              icon: Symbols.chevron_left_rounded,
                              tooltip: '上一张',
                              variant: MiriaIconButtonVariant.overlay,
                              onPressed: _index > 0 ? () => _goTo(-1) : null,
                            ),
                            const SizedBox(width: Space.x3),
                            for (var i = 0; i < images.length; i++)
                              AnimatedContainer(
                                duration: Motion.of(context, Motion.fast),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: i == _index ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: c.onDarkroom.withValues(
                                    alpha: i == _index ? 0.95 : 0.4,
                                  ),
                                  borderRadius: Radii.pillAll,
                                ),
                              ),
                            const SizedBox(width: Space.x3),
                            MiriaIconButton(
                              icon: Symbols.chevron_right_rounded,
                              tooltip: '下一张',
                              variant: MiriaIconButtonVariant.overlay,
                              onPressed: _index < images.length - 1
                                  ? () => _goTo(1)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewerPageItem extends StatelessWidget {
  const _ViewerPageItem({
    required this.image,
    required this.imageSource,
    required this.heroTag,
    required this.transform,
    required this.panEnabled,
    required this.onDoubleTapDown,
    required this.onDoubleTap,
    required this.onLongPress,
    super.key,
  });

  final ViewerImage image;
  final AnitabiImageSource imageSource;
  final Object? heroTag;
  final TransformationController transform;
  final bool panEnabled;
  final GestureTapDownCallback onDoubleTapDown;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget child = DefaultTextStyle.merge(
      style: TextStyle(color: c.onDarkroom.withValues(alpha: 0.75)),
      child: IconTheme(
        data: IconThemeData(color: c.onDarkroom.withValues(alpha: 0.75)),
        child: _ViewerImageContent(image: image, imageSource: imageSource),
      ),
    );
    if (heroTag != null) {
      child = Hero(tag: heroTag!, child: child);
    }
    return Semantics(
      image: true,
      label: image.label ?? '图片',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTapDown: onDoubleTapDown,
        onDoubleTap: onDoubleTap,
        onLongPress: onLongPress,
        child: InteractiveViewer(
          transformationController: transform,
          minScale: 0.5,
          maxScale: 5,
          panEnabled: panEnabled,
          child: SizedBox.expand(child: Center(child: child)),
        ),
      ),
    );
  }
}

class _ViewerImageContent extends StatelessWidget {
  const _ViewerImageContent({required this.image, required this.imageSource});

  final ViewerImage image;
  final AnitabiImageSource imageSource;

  @override
  Widget build(BuildContext context) {
    final bytes = image.bytes;
    if (bytes != null) {
      return BoundedImage(bytes: bytes, target: ImageDecodeTarget.preview);
    }
    final path = image.path;
    if (path != null) {
      return BoundedImage(
        path: path,
        target: ImageDecodeTarget.preview,
        source: imageSource,
      );
    }
    final url = image.url;
    if (url != null && url.isNotEmpty) {
      return _RemoteViewerImage(url: url, imageSource: imageSource);
    }
    return const ViewerPlaceholder(state: ViewerPlaceholderState.empty);
  }
}

class _RemoteViewerImage extends StatefulWidget {
  const _RemoteViewerImage({required this.url, required this.imageSource});

  final String url;
  final AnitabiImageSource imageSource;

  @override
  State<_RemoteViewerImage> createState() => _RemoteViewerImageState();
}

class _RemoteViewerImageState extends State<_RemoteViewerImage> {
  late Future<Uint8List?> _future = _load();

  Future<Uint8List?> _load() {
    final resolver = debugViewerRemoteImageResolver ?? _defaultRemoteResolver;
    return resolver(widget.url, widget.imageSource);
  }

  @override
  void didUpdateWidget(covariant _RemoteViewerImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.imageSource != widget.imageSource) {
      _future = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ViewerPlaceholder(state: ViewerPlaceholderState.loading);
        }
        final bytes = snapshot.data;
        if (snapshot.error is ImageBudgetException) {
          return BoundedImageError(error: snapshot.error!);
        }
        if (snapshot.hasError || bytes == null || bytes.isEmpty) {
          return const ViewerPlaceholder();
        }
        return BoundedImage(bytes: bytes, target: ImageDecodeTarget.preview);
      },
    );
  }
}

enum ViewerPlaceholderState { loading, unavailable, empty }

/// 图片加载中 / 暂无图片 / 图片暂不可用 on the dark viewer background.
class ViewerPlaceholder extends StatelessWidget {
  const ViewerPlaceholder({
    this.state = ViewerPlaceholderState.unavailable,
    super.key,
  });

  final ViewerPlaceholderState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = switch (state) {
      ViewerPlaceholderState.loading => '图片加载中',
      ViewerPlaceholderState.empty => '暂无图片',
      ViewerPlaceholderState.unavailable => '图片暂不可用',
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state == ViewerPlaceholderState.loading)
            ProgressRing(
              size: 30,
              strokeWidth: 3,
              color: c.onDarkroom.withValues(alpha: 0.75),
              trackColor: c.onDarkroom.withValues(alpha: 0.15),
            )
          else
            Icon(
              state == ViewerPlaceholderState.empty
                  ? Symbols.image_rounded
                  : Symbols.hide_image_rounded,
              size: 48,
              color: c.onDarkroom.withValues(alpha: 0.55),
            ),
          const SizedBox(height: Space.x3 + 2),
          Text(
            label,
            style: context.text.titleSmall?.copyWith(
              color: c.onDarkroom.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}
