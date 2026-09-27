import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../data/anitabi_image_source_scope.dart';
import '../../../data/bounded_image_decoder.dart';
import '../../../widgets/bounded_image.dart';
import '../../../widgets/reference_thumbnail_stub.dart'
    if (dart.library.io) '../../../widgets/reference_thumbnail_io.dart';
import '../../components/components.dart';

/// Image provider for a record photo / local reference / remote reference
/// at [target] resolution, or null when there is nothing to show.
ImageProvider? recordImageProvider(
  BuildContext context, {
  String? path,
  String? url,
  ImageDecodeTarget target = ImageDecodeTarget.panel,
}) {
  final source = AnitabiImageSourceScope.of(context);
  final local = path?.trim();
  if (local != null && local.isNotEmpty) {
    return BoundedImageProvider(path: local, target: target, source: source);
  }
  final remote = url?.trim();
  if (remote != null && remote.isNotEmpty) {
    return BoundedImageProvider(path: remote, target: target, source: source);
  }
  return null;
}

/// Photo tile content: bounded decode, brand placeholder while loading or
/// when missing.
class RecordImage extends StatelessWidget {
  const RecordImage({
    this.path,
    this.url,
    this.fit = BoxFit.cover,
    this.target = ImageDecodeTarget.list,
    this.missingIcon = Symbols.image_not_supported_rounded,
    super.key,
  });

  final String? path;
  final String? url;
  final BoxFit fit;
  final ImageDecodeTarget target;
  final IconData missingIcon;

  @override
  Widget build(BuildContext context) {
    final provider = recordImageProvider(
      context,
      path: path,
      url: url,
      target: target,
    );
    if (provider == null) {
      return RecordImagePlaceholder(icon: missingIcon);
    }
    return Image(
      image: provider,
      fit: fit,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, synchronous) =>
          frame == null && !synchronous
          ? const RecordImagePlaceholder(loading: true)
          : child,
      errorBuilder: (context, error, _) =>
          const RecordImagePlaceholder(icon: Symbols.broken_image_rounded),
    );
  }
}

/// Small reference thumbnail (uses the cached/thumbnail pipeline).
class RecordReferenceThumbnail extends StatelessWidget {
  const RecordReferenceThumbnail({
    required this.localPath,
    required this.url,
    super.key,
  });

  final String? localPath;
  final String? url;

  @override
  Widget build(BuildContext context) {
    const placeholder = RecordImagePlaceholder(
      icon: Symbols.image_rounded,
      compact: true,
    );
    if ((localPath == null || localPath!.isEmpty) &&
        (url == null || url!.isEmpty)) {
      return placeholder;
    }
    return ReferenceThumbnail(
      localPath: localPath,
      imageUrl: url,
      imageSource: AnitabiImageSourceScope.of(context),
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      placeholder: placeholder,
    );
  }
}

/// Brand placeholder: warm paper with a route-dot glyph.
class RecordImagePlaceholder extends StatelessWidget {
  const RecordImagePlaceholder({
    this.icon = Symbols.photo_rounded,
    this.loading = false,
    this.compact = false,
    this.label,
    super.key,
  });

  final IconData icon;
  final bool loading;
  final bool compact;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (loading) {
      return ColoredBox(color: c.surfaceMuted);
    }
    return ColoredBox(
      color: c.surfaceMuted,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final small =
              compact ||
              constraints.maxHeight < 72 ||
              constraints.maxWidth < 96;
          final glyph = Icon(
            icon,
            size: small ? 18 : 28,
            color: c.textTertiary,
          );
          if (small || label == null) return Center(child: glyph);
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(Space.x2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  glyph,
                  const SizedBox(height: Space.x2),
                  Text(
                    label!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.caption,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
