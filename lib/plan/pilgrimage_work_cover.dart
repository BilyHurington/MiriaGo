import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_theme.dart';
import '../data/anitabi_image_source_scope.dart';
import '../data/anitabi_image_url.dart';
import '../widgets/anitabi_network_image.dart';
import 'pilgrimage_models.dart';

class PilgrimageWorkCover extends StatelessWidget {
  const PilgrimageWorkCover({
    required this.work,
    this.width = 58,
    this.height = 78,
    super.key,
  });

  final PilgrimageWork work;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final imageUrl = work.coverImageUrl?.trim();
    return Semantics(
      image: imageUrl != null && imageUrl.isNotEmpty,
      label: '${work.title}封面',
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border),
        ),
        child: imageUrl == null || imageUrl.isEmpty
            ? const _WorkCoverFallback()
            : isAnitabiImageUrl(imageUrl)
            // Anitabi covers follow the configured image services and fall
            // back to the mirror like reference images.
            ? AnitabiNetworkImage(
                url: anitabiThumbnailImageUrl(imageUrl) ?? imageUrl,
                imageSource: AnitabiImageSourceScope.of(context),
                width: width,
                height: height,
                fit: BoxFit.cover,
                loadingBuilder: (_) =>
                    ColoredBox(color: AppColors.surfaceMuted),
                errorBuilder: (_) => const _WorkCoverFallback(),
                imageBuilder:
                    (url, frameBuilder, loadingBuilder, errorBuilder) =>
                        Image.network(
                          url,
                          width: width,
                          height: height,
                          fit: BoxFit.cover,
                          cacheWidth: 200,
                          filterQuality: FilterQuality.medium,
                          frameBuilder: frameBuilder,
                          loadingBuilder: loadingBuilder,
                          errorBuilder: errorBuilder,
                        ),
              )
            : Image.network(
                imageUrl,
                width: width,
                height: height,
                fit: BoxFit.cover,
                cacheWidth: 200,
                filterQuality: FilterQuality.medium,
                loadingBuilder: (context, child, progress) {
                  return progress == null
                      ? child
                      : ColoredBox(color: AppColors.surfaceMuted);
                },
                errorBuilder: (context, error, stackTrace) {
                  return const _WorkCoverFallback();
                },
              ),
      ),
    );
  }
}

class _WorkCoverFallback extends StatelessWidget {
  const _WorkCoverFallback();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        LucideIcons.clapperboard,
        size: 22,
        color: AppColors.textSecondary,
      ),
    );
  }
}
