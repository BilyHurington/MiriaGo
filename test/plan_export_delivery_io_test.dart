import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/plan_transfer/plan_export_delivery_io.dart';
import 'package:miriago/plan_transfer/plan_export_delivery_result.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  test('maps dismissed mobile share result to canceled export', () {
    expect(
      planExportDeliveryActionForShareResult(ShareResultStatus.dismissed),
      PlanExportDeliveryAction.canceled,
    );
  });

  test(
    'maps completed or unavailable mobile share result to shared export',
    () {
      expect(
        planExportDeliveryActionForShareResult(ShareResultStatus.success),
        PlanExportDeliveryAction.shared,
      );
      expect(
        planExportDeliveryActionForShareResult(ShareResultStatus.unavailable),
        PlanExportDeliveryAction.shared,
      );
    },
  );
}
