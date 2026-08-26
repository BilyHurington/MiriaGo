import 'package:flutter/services.dart';

Future<String?> readClipboardText() async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  return data?.text;
}
