import '../plan/pilgrimage_models.dart';

/// Lets pages opened outside the app shell (record details, pushed from
/// several places) change a setting through the shell, so its copy of the
/// settings stays current and a later save never rolls the change back.
abstract final class AppSettingsUpdater {
  /// Set by AppShell. Applies [update] to the current settings and stores
  /// them; resolves to false when saving failed (the shell has already told
  /// the user and restored the stored settings).
  static Future<bool> Function(
    AppSettings Function(AppSettings current) update,
  )?
  handler;
}
