import 'package:flutter/material.dart';

/// Observes iOS Reduce Motion as well as Android's disable-animations setting.
class AppMotionScope extends StatefulWidget {
  const AppMotionScope({required this.child, super.key});

  final Widget child;

  @override
  State<AppMotionScope> createState() => _AppMotionScopeState();
}

class _AppMotionScopeState extends State<AppMotionScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAccessibilityFeatures() => setState(() {});

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final features =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    return _MotionPreference(
      reduced: features.reduceMotion || features.disableAnimations,
      child: widget.child,
    );
  }
}

class _MotionPreference extends InheritedWidget {
  const _MotionPreference({required this.reduced, required super.child});
  final bool reduced;

  @override
  bool updateShouldNotify(_MotionPreference oldWidget) =>
      reduced != oldWidget.reduced;
}

abstract final class AppMotion {
  static Duration durationOf(BuildContext context, {int milliseconds = 160}) {
    final preference = context
        .dependOnInheritedWidgetOfExactType<_MotionPreference>();
    final features =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    final reduced =
        (preference?.reduced ??
            (features.reduceMotion || features.disableAnimations)) ||
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled;
    return reduced ? Duration.zero : Duration(milliseconds: milliseconds);
  }
}

/// Emphasizes updated content without retaining an outgoing copy of its controls.
class AppContentFade extends StatefulWidget {
  const AppContentFade({
    required this.revision,
    required this.child,
    super.key,
  });
  final Object? revision;
  final Widget child;

  @override
  State<AppContentFade> createState() => _AppContentFadeState();
}

class _AppContentFadeState extends State<AppContentFade>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, value: 1);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = AppMotion.durationOf(context, milliseconds: 140);
    if (_controller.duration == Duration.zero) _controller.value = 1;
  }

  @override
  void didUpdateWidget(AppContentFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revision != oldWidget.revision &&
        _controller.duration != Duration.zero) {
      _controller.forward(from: 0.65);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _controller,
    alwaysIncludeSemantics: true,
    child: widget.child,
  );
}

/// Collapses small tool/status regions, never scrollable lists or map surfaces.
class AppReveal extends StatefulWidget {
  const AppReveal({required this.visible, required this.child, super.key});
  final bool visible;
  final Widget child;

  @override
  State<AppReveal> createState() => _AppRevealState();
}

class _AppRevealState extends State<AppReveal>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    value: widget.visible ? 1 : 0,
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  void _update() {
    if (_controller.duration == Duration.zero) {
      _controller.value = widget.visible ? 1 : 0;
    } else if (widget.visible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = AppMotion.durationOf(context, milliseconds: 180);
    _update();
  }

  @override
  void didUpdateWidget(AppReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) _update();
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) => Offstage(
      offstage: !widget.visible && _controller.isDismissed,
      child: SizeTransition(
        sizeFactor: _curve,
        alignment: Alignment.topCenter,
        child: child,
      ),
    ),
    child: IgnorePointer(
      ignoring: !widget.visible,
      child: ExcludeFocus(
        excluding: !widget.visible,
        child: ExcludeSemantics(
          excluding: !widget.visible,
          child: TickerMode(enabled: widget.visible, child: widget.child),
        ),
      ),
    ),
  );
}
