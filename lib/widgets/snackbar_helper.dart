import 'package:flutter/material.dart';

import 'app_status_banner.dart';

export 'app_status_banner.dart'
    show
        AppStatusBannerKind,
        appStatusSnackBar,
        appStatusSnackDuration;

extension ShowReplacingSnackBar on ScaffoldMessengerState {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
  showReplacingSnackBar(SnackBar snackBar) {
    removeCurrentSnackBar();
    return showSnackBar(snackBar);
  }

  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showStatusSnack({
    required AppStatusBannerKind kind,
    required String title,
    String? subtitle,
    IconData? icon,
    Duration duration = appStatusSnackDuration,
  }) {
    return showReplacingSnackBar(
      appStatusSnackBar(
        kind: kind,
        title: title,
        subtitle: subtitle,
        icon: icon,
        duration: duration,
      ),
    );
  }
}
