import 'dart:convert';

import 'anitabi_service_config.dart';

/// Addresses published in the remote `config/anitabi-services.json`.
class AnitabiRemoteServices {
  const AnitabiRemoteServices({
    required this.version,
    required this.site,
    required this.staticData,
    required this.api,
    required this.officialImage,
    required this.mirrorImage,
    this.updatedAt,
  });

  static const supportedSchema = 1;

  final int version;
  final String? updatedAt;
  final String site;
  final String staticData;
  final String api;
  final String officialImage;
  final String mirrorImage;

  /// Parses a remote document; returns null unless every field is present and
  /// every address passes the same checks as addresses typed in settings.
  static AnitabiRemoteServices? tryParse(Object? json) {
    if (json is! Map) return null;
    if (json['schema'] != supportedSchema) return null;
    final version = json['version'];
    final services = json['services'];
    if (version is! int || version < 1 || services is! Map) return null;
    String? address(String key) {
      final value = services[key];
      if (value is! String || validateAnitabiBaseUrl(value) != null) {
        return null;
      }
      return normalizeAnitabiBaseUrl(value, fallback: value.trim());
    }

    final site = address('site');
    final staticData = address('staticData');
    final api = address('api');
    final officialImage = address('officialImage');
    final mirrorImage = address('mirrorImage');
    if (site == null ||
        staticData == null ||
        api == null ||
        officialImage == null ||
        mirrorImage == null) {
      return null;
    }
    final updatedAt = json['updatedAt'];
    return AnitabiRemoteServices(
      version: version,
      updatedAt: updatedAt is String ? updatedAt : null,
      site: site,
      staticData: staticData,
      api: api,
      officialImage: officialImage,
      mirrorImage: mirrorImage,
    );
  }

  Map<String, Object?> toJson() => {
    'schema': supportedSchema,
    'version': version,
    if (updatedAt != null) 'updatedAt': updatedAt,
    'services': {
      'site': site,
      'staticData': staticData,
      'api': api,
      'officialImage': officialImage,
      'mirrorImage': mirrorImage,
    },
  };

  String valueFor(AnitabiServiceField field) => switch (field) {
    AnitabiServiceField.site => site,
    AnitabiServiceField.staticData => staticData,
    AnitabiServiceField.api => api,
    AnitabiServiceField.officialImage => officialImage,
    AnitabiServiceField.mirrorImage => mirrorImage,
  };
}

enum AnitabiServiceField { site, staticData, api, officialImage, mirrorImage }

/// Where an effective Anitabi address comes from.
enum AnitabiServiceSource { builtIn, remote, custom }

String builtInAnitabiAddress(AnitabiServiceField field) => switch (field) {
  AnitabiServiceField.site => defaultAnitabiSiteBaseUrl,
  AnitabiServiceField.staticData => defaultAnitabiStaticDataBaseUrl,
  AnitabiServiceField.api => defaultAnitabiApiBaseUrl,
  AnitabiServiceField.officialImage => defaultAnitabiOfficialImageBaseUrl,
  AnitabiServiceField.mirrorImage => defaultAnitabiMirrorImageBaseUrl,
};

/// Persisted state of the remote address sync, stored as JSON in the app
/// settings (never in plan packages).
class AnitabiRemoteState {
  const AnitabiRemoteState({
    this.autoUpdate = true,
    this.lastGood,
    this.recentAutoChecks = const [],
    this.lastCheckAt,
    this.lastSuccessAt,
    this.lastResult,
  });

  /// Automatic checks after failures; manual checks work either way.
  final bool autoUpdate;

  /// Last remote configuration that was validated and applied.
  final AnitabiRemoteServices? lastGood;

  /// Automatic checks that reached the network, for rate limiting.
  final List<DateTime> recentAutoChecks;
  final DateTime? lastCheckAt;
  final DateTime? lastSuccessAt;

  /// Short machine-readable outcome of the last check.
  final String? lastResult;

  static const empty = AnitabiRemoteState();

  static AnitabiRemoteState decode(String raw) {
    if (raw.trim().isEmpty) return empty;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return empty;
      DateTime? time(Object? value) =>
          value is String ? DateTime.tryParse(value)?.toUtc() : null;
      final checks = json['recentAutoChecks'];
      return AnitabiRemoteState(
        autoUpdate: json['autoUpdate'] != false,
        lastGood: AnitabiRemoteServices.tryParse(json['lastGood']),
        recentAutoChecks: [
          if (checks is List)
            for (final value in checks) ?time(value),
        ],
        lastCheckAt: time(json['lastCheckAt']),
        lastSuccessAt: time(json['lastSuccessAt']),
        lastResult: json['lastResult'] is String
            ? json['lastResult'] as String
            : null,
      );
    } on FormatException {
      return empty;
    }
  }

  String encode() => jsonEncode({
    'autoUpdate': autoUpdate,
    if (lastGood != null) 'lastGood': lastGood!.toJson(),
    'recentAutoChecks': [
      for (final time in recentAutoChecks) time.toUtc().toIso8601String(),
    ],
    if (lastCheckAt != null) 'lastCheckAt': lastCheckAt!.toIso8601String(),
    if (lastSuccessAt != null)
      'lastSuccessAt': lastSuccessAt!.toIso8601String(),
    if (lastResult != null) 'lastResult': lastResult,
  });

  AnitabiRemoteState copyWith({
    bool? autoUpdate,
    AnitabiRemoteServices? lastGood,
    List<DateTime>? recentAutoChecks,
    DateTime? lastCheckAt,
    DateTime? lastSuccessAt,
    String? lastResult,
  }) {
    return AnitabiRemoteState(
      autoUpdate: autoUpdate ?? this.autoUpdate,
      lastGood: lastGood ?? this.lastGood,
      recentAutoChecks: recentAutoChecks ?? this.recentAutoChecks,
      lastCheckAt: lastCheckAt ?? this.lastCheckAt,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

/// Resolves one Anitabi address: an address the user changed wins; one left
/// at the built-in default follows the last validated remote configuration.
({String value, AnitabiServiceSource source}) resolveAnitabiAddress(
  AnitabiServiceField field, {
  required String stored,
  required AnitabiRemoteServices? remote,
}) {
  final builtIn = builtInAnitabiAddress(field);
  final normalized = normalizeAnitabiBaseUrl(stored, fallback: builtIn);
  if (normalized != builtIn) {
    return (value: normalized, source: AnitabiServiceSource.custom);
  }
  if (remote != null) {
    final remoteValue = remote.valueFor(field);
    if (remoteValue != builtIn) {
      return (value: remoteValue, source: AnitabiServiceSource.remote);
    }
  }
  return (value: builtIn, source: AnitabiServiceSource.builtIn);
}
