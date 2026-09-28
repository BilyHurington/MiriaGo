import 'package:flutter/foundation.dart';

import '../plan/pilgrimage_models.dart';
import 'anitabi_client.dart';
import 'bangumi_api_client.dart';
import 'pilgrimage_repository.dart';

/// Fills in covers for works that have a Bangumi ID but no cover: works
/// imported from Anitabi before covers were read, plan packages without
/// covers, and works saved before covers existed.
///
/// Anitabi's static index is tried first (one download covers every work),
/// then the Bangumi API. Each Bangumi ID is looked up at most once per app
/// session; failures are retried on the next launch. Existing covers are
/// never replaced.
class WorkCoverBackfill {
  WorkCoverBackfill({
    required this.repository,
    AnitabiClient? anitabiClient,
    BangumiApiClient? bangumiApiClient,
  }) : _anitabiClient = anitabiClient ?? AnitabiClient(),
       _bangumiApiClient = bangumiApiClient ?? BangumiApiClient();

  /// Off in widget tests, which have no network.
  static var automaticEnabled = true;

  /// Bangumi API lookups per run, to stay polite when many works lack covers.
  static const maxBangumiLookups = 20;

  static final _attempted = <int>{};
  static Future<void> _queue = Future.value();

  @visibleForTesting
  static void resetSession() => _attempted.clear();

  final PilgrimageRepository repository;
  final AnitabiClient _anitabiClient;
  final BangumiApiClient _bangumiApiClient;

  /// Returns the works that got a cover, by plan ID. Runs one at a time.
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
    _attempted.addAll(pending.keys);

    final covers = await _lookupCovers(pending.keys.toList());
    final updated = <String, List<PilgrimageWork>>{};
    for (final MapEntry(key: bangumiId, value: entries) in pending.entries) {
      final cover = covers[bangumiId];
      if (cover == null) {
        continue;
      }
      for (final entry in entries) {
        final work = entry.work.withCoverImageUrl(cover);
        try {
          await repository.addWorkToPlan(planId: entry.planId, work: work);
          updated.putIfAbsent(entry.planId, () => []).add(work);
        } on Object catch (error) {
          // The plan may have been deleted meanwhile.
          debugPrint('Failed to save work cover: $error');
        }
      }
    }
    return updated;
  }

  Future<Map<int, String>> _lookupCovers(List<int> bangumiIds) async {
    final covers = <int, String>{};
    try {
      for (final bangumiId in bangumiIds) {
        final lite = await _anitabiClient.fetchBangumiLiteFromStatic(bangumiId);
        final cover = lite?.coverImageUrl;
        if (cover != null) {
          covers[bangumiId] = cover;
        }
      }
    } on Object catch (error) {
      debugPrint('Anitabi covers unavailable: $error');
    }

    final remaining = [
      for (final bangumiId in bangumiIds)
        if (!covers.containsKey(bangumiId)) bangumiId,
    ].take(maxBangumiLookups);
    for (final bangumiId in remaining) {
      try {
        final cover = await _bangumiApiClient.fetchSubjectCover(bangumiId);
        if (cover != null) {
          covers[bangumiId] = cover;
        }
      } on Object catch (error) {
        debugPrint('Bangumi cover for $bangumiId unavailable: $error');
      }
    }
    return covers;
  }
}
