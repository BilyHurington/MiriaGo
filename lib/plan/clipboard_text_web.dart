import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

Future<String?> readClipboardText() async {
  try {
    final text = await web.window.navigator.clipboard.readText().toDart;
    return text.toDart;
  } catch (_) {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }
}
