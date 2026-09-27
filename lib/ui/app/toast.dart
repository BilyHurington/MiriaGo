import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../design/theme.dart';
import '../layout/window_class.dart';

/// The four status kinds of the old `showStatusSnack`.
enum ToastKind { running, success, warning, error, info }

@immutable
class ToastAction {
  const ToastAction({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
}

@immutable
class ToastData {
  ToastData({
    required this.kind,
    required this.title,
    this.message,
    this.action,
    this.duration,
  }) : id = _nextId++;

  static int _nextId = 0;

  final int id;
  final ToastKind kind;
  final String title;
  final String? message;
  final ToastAction? action;

  /// Null → default (3 s; running toasts stay until replaced, max 30 s).
  final Duration? duration;
}

/// Global toast queue. Show toasts with `context.showToast(...)`.
class ToastController extends ChangeNotifier {
  final List<ToastData> _toasts = [];
  final Map<int, Timer> _timers = {};

  /// Extra bottom inset reserved by the shell (bottom navigation bar).
  double _bottomInset = 0;

  List<ToastData> get toasts => List.unmodifiable(_toasts);
  double get bottomInset => _bottomInset;

  set bottomInset(double value) {
    if (value == _bottomInset) return;
    _bottomInset = value;
    // Avoid notifying during build.
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  /// Shows a toast. By default a new toast replaces the previous ones
  /// (old behaviour); pass `stack: true` to keep up to three.
  ToastData show(ToastData toast, {bool stack = false}) {
    if (!stack) {
      for (final existing in List.of(_toasts)) {
        _remove(existing.id, notify: false);
      }
    } else if (_toasts.length >= 3) {
      _remove(_toasts.first.id, notify: false);
    }
    _toasts.add(toast);
    final duration =
        toast.duration ??
        (toast.kind == ToastKind.running
            ? const Duration(seconds: 30)
            : Duration(seconds: toast.action == null ? 3 : 5));
    _timers[toast.id] = Timer(duration, () => dismiss(toast.id));
    notifyListeners();
    final message = toast.message == null
        ? toast.title
        : '${toast.title}，${toast.message}';
    SemanticsService.sendAnnouncement(
      WidgetsBinding.instance.platformDispatcher.views.first,
      message,
      TextDirection.ltr,
    );
    return toast;
  }

  void dismiss(int id) => _remove(id);

  void _remove(int id, {bool notify = true}) {
    _timers.remove(id)?.cancel();
    _toasts.removeWhere((toast) => toast.id == id);
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    super.dispose();
  }
}

extension ToastContext on BuildContext {
  /// Shows a status toast (replaces the current one).
  ToastData showToast(
    String title, {
    ToastKind kind = ToastKind.success,
    String? message,
    ToastAction? action,
    Duration? duration,
  }) {
    return read<ToastController>().show(
      ToastData(
        kind: kind,
        title: title,
        message: message,
        action: action,
        duration: duration,
      ),
    );
  }

  void dismissToast(ToastData toast) =>
      read<ToastController>().dismiss(toast.id);
}

/// Renders the toast queue. Placed above the router in the app builder.
class ToastHost extends StatelessWidget {
  const ToastHost({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ToastController>();
    final layout = context.layout;
    final padding = MediaQuery.paddingOf(context);
    final wide = !layout.isCompact;
    final toasts = controller.toasts;
    return Stack(
      children: [
        child,
        if (toasts.isNotEmpty)
          Positioned(
            left: wide ? null : 12,
            right: 12 + (wide ? padding.right : 0),
            top: wide ? padding.top + 16 : null,
            bottom: wide ? null : padding.bottom + 12 + controller.bottomInset,
            child: SafeArea(
              top: false,
              bottom: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 400 : 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final toast in toasts)
                      Padding(
                        key: ValueKey(toast.id),
                        padding: const EdgeInsets.only(top: 8),
                        child: _ToastCard(
                          toast: toast,
                          onDismiss: () => controller.dismiss(toast.id),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({required this.toast, required this.onDismiss});

  final ToastData toast;
  final VoidCallback onDismiss;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: Motion.emphasis,
  )..forward();

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final toast = widget.toast;
    final (Color accent, IconData icon) = switch (toast.kind) {
      ToastKind.running => (c.primary, Symbols.progress_activity_rounded),
      ToastKind.success => (c.success, Symbols.check_circle_rounded),
      ToastKind.warning => (c.warning, Symbols.warning_rounded),
      ToastKind.error => (c.danger, Symbols.error_rounded),
      ToastKind.info => (c.info, Symbols.info_rounded),
    };
    final curved = CurvedAnimation(parent: _enter, curve: Motion.emphasized);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
        ).animate(curved),
        child: Dismissible(
          key: ValueKey('toast-${toast.id}'),
          onDismissed: (_) => widget.onDismiss(),
          child: Material(
            type: MaterialType.transparency,
            child: ClipRRect(
              borderRadius: Radii.mdAll,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: c.surface.withValues(alpha: 0.94),
                    borderRadius: Radii.mdAll,
                    border: Border.all(color: c.hairline),
                    boxShadow: Elevations.level2(c),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Row(
                    children: [
                      if (toast.kind == ToastKind.running)
                        SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: accent,
                          ),
                        )
                      else
                        Icon(icon, color: accent, size: 22, fill: 1),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(toast.title, style: text.titleSmall),
                            if (toast.message != null) ...[
                              const SizedBox(height: 2),
                              Text(toast.message!, style: text.bodySmall),
                            ],
                          ],
                        ),
                      ),
                      if (toast.action != null)
                        TextButton(
                          onPressed: () {
                            widget.onDismiss();
                            toast.action!.onPressed();
                          },
                          child: Text(toast.action!.label),
                        )
                      else
                        IconButton(
                          tooltip: '关闭',
                          visualDensity: VisualDensity.compact,
                          onPressed: widget.onDismiss,
                          icon: Icon(
                            Symbols.close_rounded,
                            size: 18,
                            color: c.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
