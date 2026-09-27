import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Opens the reference camera for [pointId] (full-screen route).
/// Resolves when the camera closes.
Future<void> openCamera(BuildContext context, {required String pointId}) =>
    context.push<void>('/camera/${Uri.encodeComponent(pointId)}');
