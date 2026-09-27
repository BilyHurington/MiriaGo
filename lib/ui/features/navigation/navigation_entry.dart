import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Opens the route preview (in-app walking navigation) for [pointId].
Future<void> openRoutePreview(
  BuildContext context, {
  required String pointId,
}) => context.push<void>('/route/${Uri.encodeComponent(pointId)}');
