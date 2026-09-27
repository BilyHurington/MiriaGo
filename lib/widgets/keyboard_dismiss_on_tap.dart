import 'package:flutter/material.dart';

void dismissKeyboardOnTapOutside(PointerDownEvent event) {
  FocusManager.instance.primaryFocus?.unfocus();
}
