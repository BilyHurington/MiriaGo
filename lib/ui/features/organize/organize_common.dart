import 'package:flutter/material.dart';

import '../../../application/organize/organize_service.dart';
import '../../app/toast.dart';
import '../../components/components.dart';

/// Test hooks of the organize feature.
abstract final class OrganizeDebug {
  /// Renders the organize maps without a base map (widget tests have no
  /// network / platform views).
  static bool disableMapTiles = false;
}

/// Runs an organize write and shows its old failure toast
/// ([OrganizeFailure.message]). Returns the action result, or null when it
/// failed.
Future<T?> runOrganizeWrite<T>(
  BuildContext context,
  Future<T> Function() action,
) async {
  try {
    return await action();
  } on OrganizeFailure catch (failure) {
    if (context.mounted) {
      context.showToast(failure.message, kind: ToastKind.error);
    }
    return null;
  }
}

/// A floating card over a map tool (control card, point card, hint).
class MapToolCard extends StatelessWidget {
  const MapToolCard({
    required this.child,
    this.padding = const EdgeInsets.all(Space.x3),
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final panel = GlassPanel(
      padding: padding,
      borderRadius: Radii.mdAll,
      child: child,
    );
    if (onTap == null) return panel;
    return MiriaPressable(
      onTap: onTap,
      borderRadius: Radii.mdAll,
      child: panel,
    );
  }
}

/// Lays a map tool out: [map] fills the area; [top] floats at the top and
/// [bottom] at the bottom (both max 480 wide, safe-area aware). The map is
/// told how much of it is covered so camera helpers avoid the cards.
class MapToolLayout extends StatelessWidget {
  const MapToolLayout({
    required this.map,
    this.top,
    this.bottom,
    this.trailing,
    super.key,
  });

  final Widget map;
  final Widget? top;
  final Widget? bottom;

  /// Vertical tool buttons at the top right (below [top] on compact).
  final Widget? trailing;

  static const double maxCardWidth = 480;

  @override
  Widget build(BuildContext context) {
    final gutter = context.layout.isCompact ? Space.x3 : Space.x4;
    Widget card(Widget child, double maxHeight, AlignmentGeometry alignment) =>
        Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxCardWidth,
              maxHeight: maxHeight,
            ),
            child: SingleChildScrollView(primary: false, child: child),
          ),
        );
    return Stack(
      fit: StackFit.expand,
      children: [
        map,
        SafeArea(
          child: Padding(
            padding: EdgeInsets.all(gutter),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final height = constraints.maxHeight;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (top != null)
                      card(top!, height * 0.6, AlignmentDirectional.topStart),
                    if (trailing != null)
                      Padding(
                        padding: EdgeInsets.only(
                          top: top == null ? 0 : Space.x2,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.topEnd,
                          child: trailing,
                        ),
                      ),
                    const Spacer(),
                    if (bottom != null)
                      card(
                        bottom!,
                        height * 0.34,
                        AlignmentDirectional.bottomStart,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
