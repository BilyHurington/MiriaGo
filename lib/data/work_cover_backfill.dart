import 'package:flutter/foundation.dart';

import '../plan/pilgrimage_models.dart';
import 'anitabi_client.dart';
import 'bangumi_api_client.dart';
import 'pilgrimage_repository.dart';

/// Fills in covers for works that have a Bangumi ID but no cover: works
/// imported from Anitabi before covers were read, plan packages without
/// covers, and works saved before covers existed.
///
/// Each work is looked up with a small Bangumi API request; Anitabi's static
/// index (about 2 MB) is only downloaded when Bangumi is unreachable. Each
/// Bangumi ID is looked up at most once per app session; works still without
/// a cover are retried on the next launch. Existing covers are never
/// replaced, and works deleted meanwhile are not brought back.
class WorkCoverBackfill {
  WorkCoverBackfill({
    required this.repository,
    AnitabiClient Function()? anitabiClient,
    BangumiApiClient Function()? bangumiApiClient,
  }) : _createAnitabiClient = anitabiClient,
       _createBangumiApiClient = bangumiApiClient;

  /// Off in widget tests, which have no network.
  static var automaticEnabled = true;

  /// Works looked up per run, to stay polite when many lack covers.
  static const maxLookupsPerRun = 20;

  static final _attempted = <int>{};
  static Future<void> _queue = Future.value();

  @visibleForTesting
  static void resetSession() => _attempted.clear();

  final PilgrimageRepository repository;
  final AnitabiClient Function()? _createAnitabiClient;
  final BangumiApiClient Function()? _createBangumiApiClient;

  /// Returns the stored works that got a cover, by plan ID. Runs one at a
  /// time.
  Future<Map<String, List<PilgrimageWork>>> run() {
    final result = _queue.then((_) => _run());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<Map<String, List<PilgrimageWork>>> _run() async {
    final plans = await repository.loadPlans();
    final pending = <int, List<({String planId, PilgrimageWork work})>>{};
    for (final plan in plans) {
      for (final work in plan.works) {
        final bangumiId = work.bangumiId;
        if (bangumiId == null ||
            (work.coverImageUrl?.trim().isNotEmpty ?? false) ||
            _attempted.contains(bangumiId)) {
          continue;
        }
        pending.putIfAbsent(bangumiId, () => []).add((
          planId: plan.id,
          work: work,
        ));
      }
    }
    if (pending.isEmpty) {
      return const {};
    }

    final bangumiIds = pending.keys.take(maxLookupsPerRun).toList();
    _attempted.addAll(bangumiIds);
    final covers = await _lookupCovers(bangumiIds);

    final updated = <String, List<PilgrimageWork>>{};
    for (final bangumiId in bangumiIds) {
      final cover = covers[bangumiId];
      if (cover == null) {
        continue;
      }
      for (final entry in pending[bangumiId]!) {
        try {
          final stored = await repository.fillMissingWorkFieldsIfPresent(
            planId: entry.planId,
            work: entry.work.withCoverImageUrl(cover),
          );
          if (stored != null) {
            updated.putIfAbsent(entry.planId, () => []).add(stored);
          }
        } on Object catch (error) {
          debugPrint('Failed to save work cover: $error');
        }
      }
    }
    return updated;
  }

  Future<Map<int, String>> _lookupCovers(List<int> bangumiIds) async {
    final covers = <int, String>{};
    final unreachable = <int>[];
    final bangumi = _createBangumiApiClient?.call() ?? BangumiApiClient();
    try {
      for (final bangumiId in bangumiIds) {
        try {
          final cover = await bangumi.fetchSubjectCover(bangumiId);
          if (cover != null) {
            covers[bangumiId] = cover;
          }
        } on Object catch (error) {
          debugPrint('Bangumi cover for $bangumiId unavailable: $error');
          unreachable.add(bangumiId);
        }
      }
    } finally {
      if (_createBangumiApiClient == null) {
        bangumi.close();
      }
    }
    if (unreachable.isEmpty) {
      return covers;
    }

    final anitabi = _createAnitabiClient?.call() ?? AnitabiClient();
    try {
      for (final bangumiId in unreachable) {
        final lite = await anitabi.fetchBangumiLiteFromStatic(bangumiId);
        final cover = lite?.coverImageUrl;
        if (cover != null) {
          covers[bangumiId] = cover;
        }
      }
    } on Object catch (error) {
      debugPrint('Anitabi covers unavailable: $error');
    } finally {
      if (_createAnitabiClient == null) {
        anitabi.close();
      }
    }
    return covers;
  }
}
