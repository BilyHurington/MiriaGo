import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Tracks the kind of the most recent pointer input (DESIGN §5.5).
///
/// The decision is based on what the user last *did*, not on the platform:
/// an iPad with a trackpad gets pointer affordances, a touch-screen laptop
/// used with a finger gets touch affordances.
///
/// ```dart
/// if (InputMode.isPointer) { /* anchored popup, hover-only chrome */ }
///
/// InputModeBuilder(
///   builder: (context, pointer) => pointer ? compactRow : touchRow,
/// )
/// ```
abstract final class InputMode {
  static final ValueNotifier<bool> _pointer = ValueNotifier<bool>(
    _defaultPointer(),
  );
  static final ValueNotifier<bool> _keyboard = ValueNotifier<bool>(false);
  static bool _installed = false;

  static final Set<LogicalKeyboardKey> _navigationKeys = {
    LogicalKeyboardKey.tab,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.pageUp,
    LogicalKeyboardKey.pageDown,
    LogicalKeyboardKey.home,
    LogicalKeyboardKey.end,
  };

  static bool _defaultPointer() {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };
  }

  /// Starts listening to global pointer events. Safe to call repeatedly;
  /// every public accessor calls it.
  static void ensureInitialized() {
    if (_installed) return;
    _installed = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handle);
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  static bool _handleKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        !_keyboard.value &&
        _navigationKeys.contains(event.logicalKey)) {
      _keyboard.value = true;
    }
    return false;
  }

  static void _handle(PointerEvent event) {
    if (event is PointerDownEvent && _keyboard.value) _keyboard.value = false;
    if (event is! PointerDownEvent &&
        event is! PointerHoverEvent &&
        event is! PointerPanZoomStartEvent) {
      return;
    }
    final pointer =
        event.kind == PointerDeviceKind.mouse ||
        event.kind == PointerDeviceKind.trackpad;
    if (_pointer.value != pointer) _pointer.value = pointer;
  }

  /// Whether the last input came from a mouse or trackpad.
  static bool get isPointer {
    ensureInitialized();
    return _pointer.value;
  }

  /// Listenable form of [isPointer].
  static ValueListenable<bool> get pointer {
    ensureInitialized();
    return _pointer;
  }

  /// Whether the user is navigating with the keyboard (Tab / arrows since
  /// the last pointer press). Focus rings are drawn only then.
  static bool get isKeyboardNavigating {
    ensureInitialized();
    return _keyboard.value;
  }

  /// Listenable form of [isKeyboardNavigating].
  static ValueListenable<bool> get keyboardNavigating {
    ensureInitialized();
    return _keyboard;
  }

  /// Overrides the detected mode until the next real input (tests and the
  /// component gallery).
  static void debugSetPointer(bool value) {
    ensureInitialized();
    _pointer.value = value;
  }
}

/// Rebuilds when the input mode switches between touch and pointer.
///
/// Use it for density tweaks (e.g. hover-only copy buttons, 36 px pointer
/// rows vs 44 px touch rows). Hover effects themselves need no builder:
/// Flutter only sends hover events for mice and trackpads.
class InputModeBuilder extends StatelessWidget {
  const InputModeBuilder({required this.builder, super.key});

  /// `pointer` is true when the last input was a mouse or trackpad.
  final Widget Function(BuildContext context, bool pointer) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: InputMode.pointer,
      builder: (context, pointer, _) => builder(context, pointer),
    );
  }
}
