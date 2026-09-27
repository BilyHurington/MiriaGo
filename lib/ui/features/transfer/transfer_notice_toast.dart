import 'package:flutter/widgets.dart';

import '../../../application/transfer/transfer_notice.dart';
import '../../app/toast.dart';

ToastKind toastKindFor(TransferNoticeKind kind) => switch (kind) {
  TransferNoticeKind.running => ToastKind.running,
  TransferNoticeKind.success => ToastKind.success,
  TransferNoticeKind.warning => ToastKind.warning,
  TransferNoticeKind.error => ToastKind.error,
};

extension TransferNoticeToast on BuildContext {
  /// Shows a transfer status message as a toast.
  void showTransferNotice(TransferNotice notice) {
    showToast(
      notice.title,
      kind: toastKindFor(notice.kind),
      message: notice.message,
    );
  }
}
