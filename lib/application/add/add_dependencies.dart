import 'package:flutter/foundation.dart';

import '../../data/anitabi_client.dart';
import '../../data/anitabi_service_config.dart';
import '../../data/bangumi_api_client.dart';
import '../../plan/pilgrimage_models.dart';

/// Severity of a user-facing notice produced by an add-flow service. The UI
/// maps it onto its toast kinds (the application layer knows no widgets).
enum AddNoticeKind { running, success, warning, error }

/// A toast-worthy message produced by an add-flow service. Titles are the
/// old app's strings, verbatim.
@immutable
class AddNotice {
  const AddNotice(this.kind, this.title, {this.duration});

  final AddNoticeKind kind;
  final String title;

  /// Shorter display time for progress notices (old: 1200 ms).
  final Duration? duration;

  @override
  bool operator ==(Object other) =>
      other is AddNotice && other.kind == kind && other.title == title;

  @override
  int get hashCode => Object.hash(kind, title);

  @override
  String toString() => 'AddNotice($kind, $title)';
}

typedef AnitabiClientFactory =
    AnitabiClient Function(AnitabiServiceConfig? serviceConfig);
typedef BangumiClientFactory = BangumiApiClient Function();

/// Caches one point's reference thumbnail; returns the local path or null.
typedef AnitabiThumbnailCacher =
    Future<String?> Function(PilgrimagePoint point, AnitabiImageSource source);

/// Network clients used by the add flows. Pages obtain their clients here so
/// tests can swap in fakes without touching the shared app providers.
abstract final class AddDependencies {
  static AnitabiClientFactory _anitabi = _defaultAnitabi;
  static BangumiClientFactory _bangumi = _defaultBangumi;

  /// Renders map pages without base tiles (widget tests have no network).
  static bool disableMapTiles = false;

  /// Replaces the thumbnail cache used after an import (null = default).
  static AnitabiThumbnailCacher? thumbnailCacher;

  static AnitabiClient anitabiClient(AnitabiServiceConfig? serviceConfig) =>
      _anitabi(serviceConfig);

  static BangumiApiClient bangumiClient() => _bangumi();

  @visibleForTesting
  static void overrideForTesting({
    AnitabiClientFactory? anitabi,
    BangumiClientFactory? bangumi,
    bool? disableTiles,
    AnitabiThumbnailCacher? cacheThumbnail,
  }) {
    if (cacheThumbnail != null) thumbnailCacher = cacheThumbnail;
    if (anitabi != null) _anitabi = anitabi;
    if (bangumi != null) _bangumi = bangumi;
    if (disableTiles != null) disableMapTiles = disableTiles;
  }

  @visibleForTesting
  static void resetForTesting() {
    _anitabi = _defaultAnitabi;
    _bangumi = _defaultBangumi;
    disableMapTiles = false;
    thumbnailCacher = null;
  }

  static AnitabiClient _defaultAnitabi(AnitabiServiceConfig? config) =>
      AnitabiClient(serviceConfig: config);

  static BangumiApiClient _defaultBangumi() => BangumiApiClient();
}
