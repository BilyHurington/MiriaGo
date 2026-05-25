import 'package:flutter/material.dart';

extension ShowReplacingSnackBar on ScaffoldMessengerState {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showReplacingSnackBar(
    SnackBar snackBar,
  ) {
    hideCurrentSnackBar();
    return showSnackBar(snackBar);
  }
}
