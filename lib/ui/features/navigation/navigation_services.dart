import 'package:flutter/widgets.dart';

import '../../../application/navigation/navigation_session.dart';
import '../../../application/navigation/route_planner.dart';
import '../../../map/map_navigation_launcher.dart';
import '../../../map/navigation_heading.dart';
import '../../../map/valhalla_route_client.dart';

/// Optional dependencies for the route preview and navigation pages
/// (tests, the layout lab). Provide above the router; every field falls
/// back to the real service when null.
class NavigationServices extends InheritedWidget {
  const NavigationServices({
    required super.child,
    this.routeClient,
    this.locationResolver,
    this.externalNavigationLauncher,
    this.locationStreamFactory,
    this.headingStreamFactory,
    this.preciseLocationCheck,
    this.disableMapTiles = false,
    super.key,
  });

  final ValhallaRouteClient? routeClient;
  final NavigationLocationResolver? locationResolver;
  final MapNavigationLauncher? externalNavigationLauncher;
  final NavigationLocationStreamFactory? locationStreamFactory;
  final NavigationHeadingStreamFactory? headingStreamFactory;
  final NavigationPreciseLocationCheck? preciseLocationCheck;

  /// Skip map tiles (widget tests).
  final bool disableMapTiles;

  static NavigationServices? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<NavigationServices>();

  @override
  bool updateShouldNotify(NavigationServices oldWidget) => false;
}
