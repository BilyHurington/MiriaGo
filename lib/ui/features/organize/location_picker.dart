import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Full-screen "center pin" location picker (drag the map so the crosshair
/// is on the target, then 「使用此位置」).
/// OWNER: feature agent C (organize).
Future<LatLng?> pickLocation(
  BuildContext context, {
  LatLng? initial,
  String title = '选择点位坐标',
}) async => null;

/// 「输入经纬度」 dialog with clipboard paste (full-width digits, NSEW, DMS).
/// OWNER: feature agent C (organize).
Future<LatLng?> showCoordinateInputDialog(
  BuildContext context, {
  LatLng? initial,
}) async => null;
