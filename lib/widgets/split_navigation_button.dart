import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SplitNavigationButton extends StatelessWidget {
  const SplitNavigationButton({
    required this.inAppLabel,
    required this.onOpenInAppNavigation,
    required this.onOpenExternalNavigation,
    this.height = 44,
    this.walkIconSize = 24,
    this.inAppKey = const ValueKey('map-in-app-navigation-button'),
    this.externalKey = const ValueKey('map-external-navigation-button'),
    this.dividerKey = const ValueKey('map-navigation-button-divider'),
    super.key,
  });

  final String inAppLabel;
  final VoidCallback? onOpenInAppNavigation;
  final VoidCallback? onOpenExternalNavigation;
  final double height;
  final double walkIconSize;
  final Key inAppKey;
  final Key externalKey;
  final Key dividerKey;

  static final _overlayColor = WidgetStateProperty.resolveWith<Color?>((
    states,
  ) {
    if (states.contains(WidgetState.pressed)) {
      return Colors.white.withValues(alpha: 0.18);
    }
    if (states.contains(WidgetState.hovered)) {
      return Colors.white.withValues(alpha: 0.1);
    }
    return Colors.transparent;
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled =
        onOpenInAppNavigation != null || onOpenExternalNavigation != null;
    final foregroundColor = enabled
        ? colorScheme.onPrimary
        : colorScheme.onSurface.withValues(alpha: 0.38);
    final backgroundColor = enabled
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: 0.12);

    return Material(
      color: backgroundColor,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _SplitNavHalf(
                buttonKey: inAppKey,
                enabled: onOpenInAppNavigation != null,
                label: '应用内导航：$inAppLabel',
                onTap: onOpenInAppNavigation,
                iconColor: foregroundColor,
                child: Icon(Icons.directions_walk, size: walkIconSize),
              ),
            ),
            Center(
              child: Container(
                key: dividerKey,
                width: 1,
                height: (height - 16).clamp(12, 28),
                color: foregroundColor.withValues(alpha: 0.38),
              ),
            ),
            Expanded(
              child: _SplitNavHalf(
                buttonKey: externalKey,
                enabled: onOpenExternalNavigation != null,
                label: '打开外部地图',
                onTap: onOpenExternalNavigation,
                iconColor: foregroundColor,
                child: Icon(LucideIcons.navigation, size: 21),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplitNavHalf extends StatelessWidget {
  const _SplitNavHalf({
    required this.buttonKey,
    required this.enabled,
    required this.label,
    required this.onTap,
    required this.iconColor,
    required this.child,
  });

  final Key buttonKey;
  final bool enabled;
  final String label;
  final VoidCallback? onTap;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: buttonKey,
            onTap: onTap,
            overlayColor: SplitNavigationButton._overlayColor,
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            child: Center(
              child: IconTheme(
                data: IconThemeData(color: iconColor),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
