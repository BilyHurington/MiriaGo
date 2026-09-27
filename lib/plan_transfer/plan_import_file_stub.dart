import 'plan_import_package.dart';
import 'plan_transfer_background.dart';

bool canReadPlanImportFromPath(String path) => false;

Future<PlanImportPackage> readPlanImportPackageFromPath(
  String path, {
  String? sourceName,
  PlanTransferCancellation? cancellation,
}) async {
  throw UnsupportedError(
    'Plan package import is not available on this platform.',
  );
}
