import 'package:flutter/material.dart';

import '../data/anitabi_image_url.dart';
import '../plan/pilgrimage_models.dart';

typedef AnitabiNetworkImageBuilder =
    Widget Function(
      String url,
      ImageLoadingBuilder loadingBuilder,
      ImageErrorWidgetBuilder errorBuilder,
    );

class AnitabiNetworkImage extends StatefulWidget {
  const AnitabiNetworkImage({
    required this.url,
    required this.errorBuilder,
    this.imageSource = AnitabiImageSource.auto,
    this.loadingBuilder,
    this.fit,
    this.width,
    this.height,
    this.gaplessPlayback = false,
    this.imageBuilder,
    super.key,
  });

  final String url;
  final AnitabiImageSource imageSource;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final bool gaplessPlayback;
  final WidgetBuilder? loadingBuilder;
  final WidgetBuilder errorBuilder;
  final AnitabiNetworkImageBuilder? imageBuilder;

  @override
  State<AnitabiNetworkImage> createState() => _AnitabiNetworkImageState();
}

class _AnitabiNetworkImageState extends State<AnitabiNetworkImage> {
  late List<String> _candidates;
  int _candidateIndex = 0;
  var _isTryingNextCandidate = false;

  @override
  void initState() {
    super.initState();
    _resetCandidates();
  }

  @override
  void didUpdateWidget(covariant AnitabiNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.imageSource != widget.imageSource) {
      _resetCandidates();
    }
  }

  void _resetCandidates() {
    _candidates = candidateAnitabiImageUrls(
      widget.url,
      source: widget.imageSource,
    );
    _candidateIndex = 0;
    _isTryingNextCandidate = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_candidates.isEmpty) {
      return widget.errorBuilder(context);
    }

    if (_isTryingNextCandidate) {
      return _loadingPlaceholder();
    }

    final candidate = _candidates[_candidateIndex];
    Widget loadingBuilder(
      BuildContext context,
      Widget child,
      ImageChunkEvent? loadingProgress,
    ) {
      if (loadingProgress == null) {
        return child;
      }
      return widget.loadingBuilder?.call(context) ?? child;
    }

    Widget errorBuilder(
      BuildContext context,
      Object error,
      StackTrace? stackTrace,
    ) {
      if (_candidateIndex < _candidates.length - 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          setState(() {
            _candidateIndex += 1;
            _isTryingNextCandidate = false;
          });
        });
        _isTryingNextCandidate = true;
        return _loadingPlaceholder();
      }
      return widget.errorBuilder(context);
    }

    return widget.imageBuilder?.call(candidate, loadingBuilder, errorBuilder) ??
        Image.network(
          candidate,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          gaplessPlayback: widget.gaplessPlayback,
          loadingBuilder: loadingBuilder,
          errorBuilder: errorBuilder,
        );
  }

  Widget _loadingPlaceholder() {
    return widget.loadingBuilder?.call(context) ?? const SizedBox.shrink();
  }
}
