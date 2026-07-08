import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../plan/pilgrimage_models.dart';
import 'image_load_limiter.dart';
import 'reference_thumbnail_stub.dart'
    if (dart.library.io) 'reference_thumbnail_io.dart';

class MapThumbnailMarker extends StatelessWidget {
  const MapThumbnailMarker({
    required this.selected,
    required this.imported,
    required this.onTap,
    this.showThumbnail = true,
    this.markerColor,
    this.imageLoadLimiter,
    this.localPath,
    this.imageUrl,
    this.imageSource = AnitabiImageSource.auto,
    this.tooltip = '巡礼点',
    super.key,
  });

  final bool selected;
  final bool imported;
  final VoidCallback? onTap;
  final bool showThumbnail;
  final Color? markerColor;
  final ImageLoadLimiter? imageLoadLimiter;
  final String? localPath;
  final String? imageUrl;
  final AnitabiImageSource imageSource;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final pinColor =
        markerColor ?? (imported ? AppColors.textSecondary : AppColors.accent);
    final bubbleWidth = selected ? 76.0 : 64.0;
    final bubbleHeight = selected ? 56.0 : 48.0;
    final markerWidth = showThumbnail ? 84.0 : 24.0;
    final markerHeight = showThumbnail ? 82.0 : 24.0;
    final dotSize = showThumbnail ? 15.0 : 18.0;
    final tailWidth = selected ? 19.0 : 17.0;
    final tailHeight = 13.0;
    final bubbleBottomOffset = markerHeight - 58;
    final dotTop = markerHeight - dotSize;
    final tailBottom = markerHeight - dotTop - 3;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: markerWidth,
          height: markerHeight,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              if (showThumbnail) ...[
                Positioned(
                  bottom: bubbleBottomOffset,
                  child: _ThumbnailBubble(
                    localPath: localPath,
                    imageUrl: imageUrl,
                    imageSource: imageSource,
                    imageLoadLimiter: imageLoadLimiter,
                    borderColor: pinColor,
                    width: bubbleWidth,
                    height: bubbleHeight,
                    placeholder: Icon(
                      imported ? Icons.check : Icons.image_outlined,
                      color: imported ? AppColors.textSecondary : pinColor,
                      size: selected ? 24 : 22,
                    ),
                  ),
                ),
                Positioned(
                  bottom: tailBottom,
                  child: CustomPaint(
                    size: Size(tailWidth, tailHeight),
                    painter: _MarkerTailPainter(color: pinColor),
                  ),
                ),
              ],
              Positioned(
                bottom: showThumbnail ? 0 : 3,
                child: Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    color: pinColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
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

class _MarkerTailPainter extends CustomPainter {
  const _MarkerTailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MarkerTailPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _ThumbnailBubble extends StatelessWidget {
  const _ThumbnailBubble({
    required this.localPath,
    required this.imageUrl,
    required this.imageSource,
    required this.borderColor,
    required this.placeholder,
    required this.width,
    required this.height,
    this.imageLoadLimiter,
  });

  final String? localPath;
  final String? imageUrl;
  final AnitabiImageSource imageSource;
  final ImageLoadLimiter? imageLoadLimiter;
  final Color borderColor;
  final Widget placeholder;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5.5),
        child: ColoredBox(
          color: AppColors.surfaceMuted,
          child: ReferenceThumbnail(
            localPath: localPath,
            imageUrl: imageUrl,
            imageSource: imageSource,
            loadLimiter: imageLoadLimiter,
            width: width,
            height: height,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            placeholder: Center(child: placeholder),
          ),
        ),
      ),
    );
  }
}
