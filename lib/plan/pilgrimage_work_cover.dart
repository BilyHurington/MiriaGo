import 'package:flutter/material.dart';

import '../app_theme.dart';
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
                      : const ColoredBox(color: AppColors.surfaceMuted);
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
    return const Center(
      child: Icon(
        Icons.movie_filter_outlined,
        size: 22,
        color: AppColors.textSecondary,
      ),
    );
  }
}
