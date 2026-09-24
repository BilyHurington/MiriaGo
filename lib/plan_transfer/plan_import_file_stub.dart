import 'plan_import_package.dart';
import 'plan_transfer_background.dart';

Future<PlanImportPackage> readPlanImportPackageFromPath(
  String path, {
  PlanTransferCancellation? cancellation,
}) async {
  throw UnsupportedError(
    'Plan package import is not available on this platform.',
  );
}
