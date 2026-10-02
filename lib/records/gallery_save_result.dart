import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../widgets/snackbar_helper.dart';

enum GallerySaveResult { saved, permissionDenied, failed }

/// Error codes the native savers use when photo library access is refused
/// (iOS: add-only photo access; Android 9 and earlier: storage).
const galleryPermissionDeniedCodes = {
  'PHOTO_PERMISSION_DENIED',
  'PERMISSION_DENIED',
};

/// Reports a manual "保存到相册"; a refused permission offers the system
/// settings, since asking again does nothing once it was declined.
void showGallerySaveResult(
  ScaffoldMessengerState messenger,
  GallerySaveResult result, {
  String failedTitle = '保存失败，请稍后重试。',
}) {
  switch (result) {
    case GallerySaveResult.saved:
      messenger.showStatusSnack(
        kind: AppStatusBannerKind.success,
        title: '已保存到相册',
      );
    case GallerySaveResult.permissionDenied:
      messenger.showStatusSnack(
        kind: AppStatusBannerKind.error,
        title: '需要相册权限',
        subtitle: '请在系统设置中允许 MiriaGo 添加照片。',
        actionLabel: '设置',
        onAction: () {
          messenger.hideCurrentSnackBar();
          openAppSettings();
        },
        duration: const Duration(seconds: 6),
      );
    case GallerySaveResult.failed:
      messenger.showStatusSnack(
        kind: AppStatusBannerKind.error,
        title: failedTitle,
      );
  }
}
