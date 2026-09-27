import 'package:flutter/widgets.dart';

/// Width classes (logical px, after the in-app UI scale is applied).
enum WindowClass {
  compact(0),
  medium(600),
  expanded(840),
  large(1200),
  xlarge(1600);

  const WindowClass(this.minWidth);
  final double minWidth;

  static WindowClass fromWidth(double width) {
    if (width >= xlarge.minWidth) return xlarge;
    if (width >= large.minWidth) return large;
    if (width >= expanded.minWidth) return expanded;
    if (width >= medium.minWidth) return medium;
    return compact;
  }

  bool operator >=(WindowClass other) => index >= other.index;
  bool operator <(WindowClass other) => index < other.index;
  bool operator >(WindowClass other) => index > other.index;
  bool operator <=(WindowClass other) => index <= other.index;
}

/// Height below which a window is "short" (phone landscape): no bottom
/// bars or bottom sheets, use rails and side panels instead.
const double kShortHeight = 480;

/// Width from which map pages put their panel on the side instead of a
/// bottom sheet.
const double kSidePanelMinWidth = 720;

/// Resolved layout facts for the current window.
@immutable
class WindowLayout {
  const WindowLayout(this.size);

  final Size size;

  double get width => size.width;
  double get height => size.height;

  WindowClass get windowClass => WindowClass.fromWidth(width);

  bool get isShort => height < kShortHeight;

  bool get isCompact => windowClass == WindowClass.compact;

  /// Bottom navigation bar only for compact, non-short windows.
  bool get usesBottomBar => isCompact && !isShort;

  /// Full sidebar for large windows (and not short).
  bool get usesSidebar => windowClass >= WindowClass.large && !isShort;

  /// Rail for everything in between.
  bool get usesRail => !usesBottomBar && !usesSidebar;

  /// Map pages: side panel instead of a bottom sheet.
  bool get usesSidePanel => width >= kSidePanelMinWidth || isShort;

  /// List/detail pages show both panes.
  bool get showsListDetail => windowClass >= WindowClass.expanded;

  /// Page gutter.
  double get gutter => switch (windowClass) {
    WindowClass.compact => 16,
    WindowClass.medium => 24,
    WindowClass.expanded => 24,
    WindowClass.large => 32,
    WindowClass.xlarge => 32,
  };

  /// Max width for reading/forms content.
  static const double readingWidth = 720;
}

extension WindowLayoutContext on BuildContext {
  WindowLayout get layout => WindowLayout(MediaQuery.sizeOf(this));

  WindowClass get windowClass => layout.windowClass;
}
