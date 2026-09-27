import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';

/// Opens the route preview (in-app walking navigation) for [pointId].
Future<void> openRoutePreview(
  BuildContext context, {
  required String pointId,
}) => context.push<void>('/route/${Uri.encodeComponent(pointId)}');

/// Closes the route preview / in-app navigation. Opened by a deep link or
/// after a browser reload there is no page underneath, so it goes to 巡礼.
void closeNavigationRoute(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router == null) {
    unawaited(Navigator.of(context).maybePop());
  } else if (router.canPop()) {
    router.pop();
  } else {
    router.go(Routes.go);
  }
}

/// App bar leading for a full-screen navigation route without a page
/// underneath (deep link / browser reload): a close button that goes to
/// 巡礼. Null otherwise, so the app bar shows its usual close button.
Widget? navigationRouteLeading(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router == null || router.canPop()) return null;
  return CloseButton(onPressed: () => closeNavigationRoute(context));
}
