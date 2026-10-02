import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../plan/pilgrimage_models.dart';
import 'anitabi_client.dart';
import 'anitabi_remote_state.dart';
import 'anitabi_service_config.dart';
import 'anitabi_static_data_reader.dart';
import 'public_http.dart';

/// Where the app looks for `config/anitabi-services.json`, in order.
/// raw.githubusercontent.com updates within minutes but is often unreachable
/// in mainland China; jsDelivr is reachable there but caches `@main` for up
/// to 12 hours.
const anitabiRemoteConfigUrls = [
  'https://raw.githubusercontent.com/BilyHurington/MiriaGo/main/config/anitabi-services.json',
  'https://cdn.jsdelivr.net/gh/BilyHurington/MiriaGo@main/config/anitabi-services.json',
  'https://fastly.jsdelivr.net/gh/BilyHurington/MiriaGo@main/config/anitabi-services.json',
];

/// Hook the Anitabi data layer calls after a request failed in a way that
/// suggests the service moved. Set by the app shell to the running
/// [AnitabiEndpointSync]; returns whether the addresses changed, in which case
/// the caller retries its request once.
abstract final class AnitabiEndpointRecovery {
  static Future<bool> Function()? handler;
}

enum AnitabiSyncOutcome {
  /// A newer validated configuration changed the addresses in use.
  updated,

  /// Checked successfully; nothing to change.
  unchanged,

  /// No configuration source was reachable (treated as offline).
  offline,

  /// A source answered with something that is not a valid configuration.
  invalid,

  /// The new addresses did not respond correctly; old ones are kept.
  verificationFailed,

  /// Automatic check skipped by the rate limit.
  rateLimited,

  /// Automatic updates are switched off.
  disabled,
}

extension AnitabiSyncOutcomeLabel on AnitabiSyncOutcome {
  String get label => switch (this) {
    AnitabiSyncOutcome.updated => '已更新服务地址',
    AnitabiSyncOutcome.unchanged => '服务地址已是最新',
    AnitabiSyncOutcome.offline => '无法获取远程配置，请检查网络',
    AnitabiSyncOutcome.invalid => '远程配置无效，已保留当前地址',
    AnitabiSyncOutcome.verificationFailed => '新地址暂不可用，已保留当前地址',
    AnitabiSyncOutcome.rateLimited => '检查过于频繁，稍后再试',
    AnitabiSyncOutcome.disabled => '已关闭自动更新',
  };
}

typedef AnitabiSettingsLoader = Future<AppSettings> Function();
typedef AnitabiSettingsSaver = Future<void> Function(AppSettings settings);

/// Checks that candidate addresses really serve Anitabi data.
typedef AnitabiServiceVerifier =
    Future<bool> Function(
      AnitabiServiceConfig candidate,
      Set<AnitabiServiceField> changed,
    );

/// Keeps the Anitabi service addresses in step with the remote
/// configuration published in the MiriaGo repository.
class AnitabiEndpointSync {
  AnitabiEndpointSync({
    required this.loadSettings,
    required this.saveSettings,
    http.Client? httpClient,
    AnitabiServiceVerifier? verifier,
    DateTime Function()? now,
    this.configUrls = anitabiRemoteConfigUrls,
    this.fetchTimeout = const Duration(seconds: 5),
  }) : _client = httpClient ?? http.Client(),
       _now = now ?? DateTime.now {
    _verifier = verifier ?? _defaultVerifier;
  }

  /// The sync the running app uses for automatic recovery; set by AppShell.
  static AnitabiEndpointSync? active;

  static const maxAutoChecksPerDay = 3;
  static const minAutoCheckInterval = Duration(hours: 1);
  static const quietAfterSuccess = Duration(hours: 24);
  static const manualCooldown = Duration(minutes: 1);

  /// Automatic checks pause this long after finding no source reachable:
  /// offline, every failed request would otherwise start another check.
  static const offlineCooldown = Duration(minutes: 10);
  static const maxConfigBytes = 16 * 1024;

  final AnitabiSettingsLoader loadSettings;
  final AnitabiSettingsSaver saveSettings;
  final http.Client _client;
  final DateTime Function() _now;
  final List<String> configUrls;
  final Duration fetchTimeout;
  late final AnitabiServiceVerifier _verifier;

  Future<AnitabiSyncOutcome>? _running;
  DateTime? _lastManualCheck;
  DateTime? _lastOfflineAt;

  /// Called after an Anitabi request failed in a way that suggests the
  /// address changed. Rate limited; returns whether addresses changed.
  Future<bool> recoverAfterFailure() async {
    try {
      return await _runOnce(automatic: true) == AnitabiSyncOutcome.updated;
    } on Object catch (error) {
      // e.g. the new addresses could not be saved; the caller reports its
      // own failure instead.
      debugPrint('Anitabi address recovery failed: $error');
      return false;
    }
  }

  /// "立即检查" in settings: ignores the daily limit but has a short cooldown.
  Future<AnitabiSyncOutcome> checkNow() {
    final last = _lastManualCheck;
    if (last != null && _now().difference(last) < manualCooldown) {
      return Future.value(AnitabiSyncOutcome.rateLimited);
    }
    _lastManualCheck = _now();
    return _runOnce(automatic: false);
  }

  Future<void> setAutoUpdate(bool enabled) =>
      _saveState((latest) => latest.copyWith(autoUpdate: enabled));

  /// Concurrent failures share one check.
  Future<AnitabiSyncOutcome> _runOnce({required bool automatic}) {
    return _running ??= _run(
      automatic: automatic,
    ).whenComplete(() => _running = null);
  }

  Future<AnitabiSyncOutcome> _run({required bool automatic}) async {
    final settings = await loadSettings();
    final state = settings.anitabiRemoteState;
    final now = _now().toUtc();
    final recent = [
      for (final time in state.recentAutoChecks)
        if (now.difference(time) < const Duration(hours: 24)) time,
    ];
    if (automatic) {
      if (!state.autoUpdate) return AnitabiSyncOutcome.disabled;
      final offlineAt = _lastOfflineAt;
      if (offlineAt != null && _now().difference(offlineAt) < offlineCooldown) {
        return AnitabiSyncOutcome.rateLimited;
      }
      final lastSuccess = state.lastSuccessAt;
      final lastAttempt = recent.isEmpty ? null : recent.last;
      if ((lastSuccess != null &&
              now.difference(lastSuccess) < quietAfterSuccess) ||
          recent.length >= maxAutoChecksPerDay ||
          (lastAttempt != null &&
              now.difference(lastAttempt) < minAutoCheckInterval)) {
        return AnitabiSyncOutcome.rateLimited;
      }
    }

    final fetched = await _fetchRemote();
    if (fetched.outcome == AnitabiSyncOutcome.offline) {
      // Not counted: an offline device should not use up its checks. Only a
      // manual check records it (settings shows the result); an automatic
      // one would store the settings and rebuild the app for nothing.
      _lastOfflineAt = _now();
      if (!automatic) {
        await _saveState(
          (latest) => latest.copyWith(lastCheckAt: now, lastResult: 'offline'),
        );
      }
      return AnitabiSyncOutcome.offline;
    }
    _lastOfflineAt = null;
    AnitabiRemoteState attempted(AnitabiRemoteState latest) => latest.copyWith(
      lastCheckAt: now,
      recentAutoChecks: automatic ? [...recent, now] : recent,
    );

    final remote = fetched.services;
    if (remote == null) {
      await _saveState(
        (latest) => attempted(latest).copyWith(lastResult: 'invalid'),
      );
      return AnitabiSyncOutcome.invalid;
    }
    final lastGood = state.lastGood;
    if (lastGood != null && remote.version <= lastGood.version) {
      await _saveState(
        (latest) => attempted(
          latest,
        ).copyWith(lastSuccessAt: now, lastResult: 'unchanged'),
      );
      return AnitabiSyncOutcome.unchanged;
    }

    final current = settings.anitabiServiceConfig;
    final candidate = settings.anitabiServiceConfigWith(remote);
    final changed = _changedFields(current, candidate);
    if (changed.isNotEmpty && !await _verifier(candidate, changed)) {
      await _saveState(
        (latest) =>
            attempted(latest).copyWith(lastResult: 'verificationFailed'),
      );
      return AnitabiSyncOutcome.verificationFailed;
    }
    await _saveState(
      (latest) => attempted(latest).copyWith(
        lastGood: remote,
        lastSuccessAt: now,
        lastResult: changed.isEmpty ? 'unchanged' : 'updated',
      ),
    );
    return changed.isEmpty
        ? AnitabiSyncOutcome.unchanged
        : AnitabiSyncOutcome.updated;
  }

  /// Saves the sync state onto the latest settings, so a check never
  /// overwrites settings changed while it ran.
  Future<void> _saveState(
    AnitabiRemoteState Function(AnitabiRemoteState latest) update,
  ) async {
    final latest = await loadSettings();
    await saveSettings(
      latest.copyWith(
        anitabiRemoteStateJson: update(latest.anitabiRemoteState).encode(),
      ),
    );
  }

  Future<({AnitabiSyncOutcome outcome, AnitabiRemoteServices? services})>
  _fetchRemote() async {
    var reachedSource = false;
    for (final url in configUrls) {
      try {
        final response = await _client
            .get(Uri.parse(url), headers: const {'Accept': 'application/json'})
            .timeout(fetchTimeout);
        reachedSource = true;
        if (response.statusCode != 200 ||
            response.bodyBytes.length > maxConfigBytes) {
          continue;
        }
        final services = AnitabiRemoteServices.tryParse(
          jsonDecode(utf8.decode(response.bodyBytes)),
        );
        if (services != null) {
          return (outcome: AnitabiSyncOutcome.updated, services: services);
        }
      } on FormatException {
        reachedSource = true;
      } on Object {
        // Unreachable source; try the next one.
      }
    }
    return (
      outcome: reachedSource
          ? AnitabiSyncOutcome.invalid
          : AnitabiSyncOutcome.offline,
      services: null,
    );
  }

  static Set<AnitabiServiceField> _changedFields(
    AnitabiServiceConfig a,
    AnitabiServiceConfig b,
  ) => {
    if (a.siteBaseUrl != b.siteBaseUrl) AnitabiServiceField.site,
    if (a.staticDataBaseUrl != b.staticDataBaseUrl)
      AnitabiServiceField.staticData,
    if (a.apiBaseUrl != b.apiBaseUrl) AnitabiServiceField.api,
    if (a.officialImageBaseUrl != b.officialImageBaseUrl)
      AnitabiServiceField.officialImage,
    if (a.mirrorImageBaseUrl != b.mirrorImageBaseUrl)
      AnitabiServiceField.mirrorImage,
  };

  /// Checks the data sources the app depends on. Image hosts are not
  /// probed: image loading already falls back between the two hosts.
  Future<bool> _defaultVerifier(
    AnitabiServiceConfig candidate,
    Set<AnitabiServiceField> changed,
  ) async {
    try {
      if (changed.contains(AnitabiServiceField.staticData)) {
        final body = await AnitabiStaticDataReader(
          httpClient: _client,
          serviceConfig: candidate,
          reportFailures: false,
        ).read('g.json');
        final index = jsonDecode(body);
        if (index is! List || index.isEmpty) return false;
      }
      if (changed.contains(AnitabiServiceField.api)) {
        final response = await getPublic(
          _client,
          candidate.apiUri('bangumi/115908/lite'),
        ).timeout(const Duration(seconds: 12));
        if (response.statusCode != 200) return false;
        final lite = jsonDecode(utf8.decode(response.bodyBytes));
        if (lite is! Map || lite['id'] == null) return false;
      }
      return true;
    } on Object {
      return false;
    }
  }
}

/// Whether a failed Anitabi request suggests the service moved, rather than
/// the device being offline, rate limited or the item missing.
///
/// [notFoundMeansMoved] is true for the static data files, which always exist
/// at a working address; an API 404 only means that work is unknown.
bool isSuspectedAnitabiAddressFailure(
  Object error, {
  bool notFoundMeansMoved = true,
}) {
  // Slow networks time out far more often than Anitabi moves.
  if (error is TimeoutException) {
    return false;
  }
  final code = error is AnitabiException
      ? error.statusCode
      // The desktop launcher reports "request failed: 404 Not Found".
      : int.tryParse(
          RegExp(
                r'request failed: (\d{3})\b',
              ).firstMatch(error.toString())?.group(1) ??
              '',
        );
  if (code != null) {
    if (code == 429) return false;
    return code >= 500 ||
        (notFoundMeansMoved && (code == 404 || code == 403 || code == 410));
  }
  // Connection, DNS, TLS and timeout failures, and HTML pages served where
  // JSON was expected.
  return true;
}
