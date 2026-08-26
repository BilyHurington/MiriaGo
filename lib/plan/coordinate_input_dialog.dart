import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../app_theme.dart';
import '../widgets/input_dialog.dart';
import 'coordinate_parser.dart';

Future<LatLng?> showCoordinateInputDialog({
  required BuildContext context,
  required LatLng current,
}) {
  return showDialog<LatLng>(
    context: context,
    builder: (_) => _CoordinateInputDialog(current: current),
  );
}

class _CoordinateInputDialog extends StatefulWidget {
  const _CoordinateInputDialog({required this.current});

  final LatLng current;

  @override
  State<_CoordinateInputDialog> createState() => _CoordinateInputDialogState();
}

class _CoordinateInputDialogState extends State<_CoordinateInputDialog> {
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _latitudeController = TextEditingController(
      text: widget.current.latitude.toStringAsFixed(6),
    );
    _longitudeController = TextEditingController(
      text: widget.current.longitude.toStringAsFixed(6),
    );
  }

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
  }

  Future<void> _pasteFromClipboard() async {
    LatLng? coordinate;
    try {
      coordinate = await parseClipboardCoordinate();
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() => _errorText = '无法读取剪贴板。');
      return;
    }
    if (!mounted) {
      return;
    }
    if (coordinate == null) {
      setState(() => _errorText = '剪贴板中没有可识别的坐标。');
      return;
    }
    final parsed = coordinate;
    setState(() {
      _errorText = null;
      _latitudeController.text = parsed.latitude.toStringAsFixed(6);
      _longitudeController.text = parsed.longitude.toStringAsFixed(6);
    });
  }

  void _submit() {
    final latitude = double.tryParse(_latitudeController.text.trim());
    final longitude = double.tryParse(_longitudeController.text.trim());
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      setState(() => _errorText = '请输入有效经纬度');
      return;
    }
    Navigator.of(context).pop(LatLng(latitude, longitude));
  }

  @override
  Widget build(BuildContext context) {
    return AppInputDialog(
      title: '输入经纬度',
      errorText: _errorText,
      titleTrailing: AppDialogPasteButton(onPressed: _pasteFromClipboard),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppDialogField(
            label: '纬度',
            child: TextField(
              onTapOutside: dismissKeyboardOnTapOutside,
              controller: _latitudeController,
              onChanged: (_) => _clearError(),
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              decoration: appDialogInputDecoration(),
            ),
          ),
          const SizedBox(height: 14),
          AppDialogField(
            label: '经度',
            child: TextField(
              onTapOutside: dismissKeyboardOnTapOutside,
              controller: _longitudeController,
              onChanged: (_) => _clearError(),
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              decoration: appDialogInputDecoration(),
            ),
          ),
        ],
      ),
      confirmLabel: '确定',
      onConfirm: _submit,
    );
  }
}
