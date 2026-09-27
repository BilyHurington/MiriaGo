import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/plan_session.dart';
import '../../../plan/coordinate_parser.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../app/toast.dart';
import '../../components/components.dart';
import '../../map/map.dart';
import 'organize_common.dart';

/// Fallback centre of the pickers when nothing else is known (old app).
const LatLng kPickerFallbackCenter = LatLng(35, 135);

/// Average position of the points with coordinates, or null.
LatLng? averagePointPosition(Iterable<PilgrimagePoint> points) {
  var count = 0;
  var latitude = 0.0;
  var longitude = 0.0;
  for (final point in points) {
    if (!point.hasCoordinate) continue;
    count++;
    latitude += point.position.latitude;
    longitude += point.position.longitude;
  }
  if (count == 0) return null;
  return LatLng(latitude / count, longitude / count);
}

/// 「35.123456, 135.123456」.
String formatLatLng(LatLng position) =>
    '${position.latitude.toStringAsFixed(6)}, '
    '${position.longitude.toStringAsFixed(6)}';

/// Full-screen "center pin" location picker (drag the map so the crosshair
/// is on the target, then 「使用此位置」).
/// OWNER: feature agent C (organize).
Future<LatLng?> pickLocation(
  BuildContext context, {
  LatLng? initial,
  String title = '选择点位坐标',
}) async {
  var start = initial;
  if (start == null) {
    final session = context.read<PlanSession?>();
    if (session != null && session.isReady) {
      start = averagePointPosition(session.plan.points);
    }
  }
  return Navigator.of(context, rootNavigator: true).push<LatLng>(
    MaterialPageRoute(
      builder: (_) => _LocationPickerPage(
        title: title,
        initial: start ?? kPickerFallbackCenter,
      ),
    ),
  );
}

class _LocationPickerPage extends StatefulWidget {
  const _LocationPickerPage({required this.title, required this.initial});

  final String title;
  final LatLng initial;

  @override
  State<_LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<_LocationPickerPage> {
  final PlanMapController _map = PlanMapController();
  late LatLng _center = widget.initial;
  MapLocationController? _location;
  bool _locating = false;

  @override
  void dispose() {
    _location?.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _inputCoordinates() async {
    final result = await showCoordinateInputDialog(context, initial: _center);
    if (result == null || !mounted) return;
    setState(() => _center = result);
    unawaited(_map.moveTo(result, zoom: 16));
  }

  Future<void> _locate() async {
    if (_locating) return;
    final location = _location ??= MapLocationController();
    setState(() => _locating = true);
    final position = await location.locate();
    if (!mounted) return;
    setState(() => _locating = false);
    if (position == null) {
      context.showToast(location.error ?? '无法获取当前位置', kind: ToastKind.warning);
      return;
    }
    unawaited(_map.moveTo(position, zoom: 16));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MiriaPageScaffold(
      title: widget.title,
      actions: [
        MiriaIconButton(
          key: const ValueKey('location-picker-input'),
          icon: Symbols.edit_location_alt_rounded,
          tooltip: '输入经纬度',
          onPressed: _inputCoordinates,
        ),
        MiriaIconButton(
          key: const ValueKey('location-picker-locate'),
          icon: Symbols.my_location_rounded,
          tooltip: _locating ? '正在定位' : '定位',
          onPressed: _locating ? null : _locate,
        ),
      ],
      body: CenterPinPicker(
        controller: _map,
        initialCenter: widget.initial,
        disableTiles: OrganizeDebug.disableMapTiles,
        onChanged: (value) {
          if (value != _center) setState(() => _center = value);
        },
      ),
      bottomBar: Row(
        children: [
          Icon(Symbols.location_on_rounded, color: c.primary, fill: 1),
          const SizedBox(width: Space.x2),
          Expanded(
            child: Text(
              formatLatLng(_center),
              key: const ValueKey('location-picker-coordinates'),
              style: context.text.bodyMedium?.copyWith(
                fontFeatures: MiriaFonts.tabular,
              ),
            ),
          ),
          const SizedBox(width: Space.x2),
          MiriaButton(
            key: const ValueKey('location-picker-use'),
            label: '使用此位置',
            shortLabel: '使用',
            icon: Symbols.check_rounded,
            onPressed: () => Navigator.of(context).pop(_center),
          ),
        ],
      ),
    );
  }
}

/// 「输入经纬度」 dialog with clipboard paste (full-width digits, NSEW, DMS).
/// OWNER: feature agent C (organize).
Future<LatLng?> showCoordinateInputDialog(
  BuildContext context, {
  LatLng? initial,
}) async {
  return showDialog<LatLng>(
    context: context,
    builder: (_) => CoordinateInputDialog(initial: initial),
  );
}

/// Port of the old `coordinate_input_dialog.dart`.
class CoordinateInputDialog extends StatefulWidget {
  const CoordinateInputDialog({
    this.initial,
    this.readClipboardCoordinate = parseClipboardCoordinate,
    super.key,
  });

  final LatLng? initial;

  /// Reads and parses the clipboard (replaceable in tests).
  final Future<LatLng?> Function() readClipboardCoordinate;

  @override
  State<CoordinateInputDialog> createState() => _CoordinateInputDialogState();
}

class _CoordinateInputDialogState extends State<CoordinateInputDialog> {
  late final TextEditingController _latitude = TextEditingController(
    text: widget.initial?.latitude.toStringAsFixed(6) ?? '',
  );
  late final TextEditingController _longitude = TextEditingController(
    text: widget.initial?.longitude.toStringAsFixed(6) ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _paste() async {
    LatLng? coordinate;
    try {
      coordinate = await widget.readClipboardCoordinate();
    } on Object {
      if (!mounted) return;
      setState(() => _error = '无法读取剪贴板。');
      return;
    }
    if (!mounted) return;
    if (coordinate == null) {
      setState(() => _error = '剪贴板中没有可识别的坐标。');
      return;
    }
    final parsed = coordinate;
    setState(() {
      _error = null;
      _latitude.text = parsed.latitude.toStringAsFixed(6);
      _longitude.text = parsed.longitude.toStringAsFixed(6);
    });
  }

  void _submit() {
    final latitude = parseCoordinateComponent(_latitude.text, latitude: true);
    final longitude = parseCoordinateComponent(
      _longitude.text,
      latitude: false,
    );
    if (latitude == null || longitude == null) {
      setState(() => _error = '请输入有效经纬度');
      return;
    }
    Navigator.of(context).pop(LatLng(latitude, longitude));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const keyboard = TextInputType.numberWithOptions(
      signed: true,
      decimal: true,
    );
    return MiriaDialog(
      title: '输入经纬度',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: MiriaButton.ghost(
              key: const ValueKey('coordinate-dialog-paste'),
              label: '粘贴',
              icon: Symbols.content_paste_rounded,
              size: MiriaButtonSize.sm,
              onPressed: _paste,
            ),
          ),
          const SizedBox(height: Space.x2),
          MiriaTextField(
            key: const ValueKey('coordinate-dialog-latitude'),
            label: '纬度',
            controller: _latitude,
            keyboardType: keyboard,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearError(),
          ),
          const SizedBox(height: Space.x3 + 2),
          MiriaTextField(
            key: const ValueKey('coordinate-dialog-longitude'),
            label: '经度',
            controller: _longitude,
            keyboardType: keyboard,
            textInputAction: TextInputAction.done,
            onChanged: (_) => _clearError(),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: Space.x3),
            Text(
              _error!,
              key: const ValueKey('coordinate-dialog-error'),
              style: context.text.bodySmall?.copyWith(color: c.danger),
            ),
          ],
        ],
      ),
      actions: DialogActionRow(
        confirmLabel: '确定',
        onConfirm: _submit,
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }
}
