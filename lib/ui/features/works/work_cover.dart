import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../plan/pilgrimage_models.dart';
import '../../components/components.dart';

/// Work cover (Bangumi `coverImageUrl`) with a brand placeholder when there
/// is no cover or it fails to load (old `PilgrimageWorkCover`).
class WorkCover extends StatelessWidget {
  const WorkCover({
    required this.work,
    this.width = 58,
    this.height = 78,
    this.borderRadius = Radii.xsAll,
    super.key,
  });

  final PilgrimageWork work;
  final double width;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final imageUrl = work.coverImageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Semantics(
      image: hasImage,
      label: '${work.title}封面',
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.surfaceMuted,
          borderRadius: borderRadius,
          border: Border.all(color: c.hairline),
        ),
        child: !hasImage
            ? _Fallback(size: width)
            : Image.network(
                imageUrl,
                width: width,
                height: height,
                fit: BoxFit.cover,
                cacheWidth: (width * dpr).round().clamp(48, 400),
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : ColoredBox(color: c.surfaceMuted),
                errorBuilder: (context, error, stackTrace) =>
                    _Fallback(size: width),
              ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Symbols.movie_rounded,
        size: (size * 0.4).clamp(14, 24),
        color: context.colors.textTertiary,
      ),
    );
  }
}
