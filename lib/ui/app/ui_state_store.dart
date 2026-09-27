import 'ui_state_store_stub.dart'
    if (dart.library.io) 'ui_state_store_io.dart'
    if (dart.library.js_interop) 'ui_state_store_web.dart'
    as impl;

/// Small per-device UI preferences that are not part of AppSettings
/// (e.g. the last used tab). Best effort: failures are ignored.
abstract final class UiStateStore {
  static const _lastTabKey = 'lastTab';
  static const tabPaths = ['/plan', '/go', '/records', '/settings'];

  static Future<String?> loadLastTabPath() async {
    final value = await impl.readUiState(_lastTabKey);
    final index = int.tryParse(value ?? '');
    if (index == null || index < 0 || index >= tabPaths.length) return null;
    return tabPaths[index];
  }

  static Future<void> saveLastTab(int index) =>
      impl.writeUiState(_lastTabKey, '$index');
}
