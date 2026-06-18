import 'package:flutter/material.dart';

extension ShowReplacingSnackBar on ScaffoldMessengerState {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
  showReplacingSnackBar(SnackBar snackBar) {
    removeCurrentSnackBar();
    return showSnackBar(snackBar);
  }
}
