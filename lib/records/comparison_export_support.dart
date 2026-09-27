import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../data/anitabi_image_fetcher.dart';
import '../data/anitabi_image_url.dart';
import '../data/bounded_image_decoder.dart';
import '../plan_transfer/plan_export_delivery.dart';
import '../plan_transfer/plan_export_delivery_result.dart';
import 'comparison_export_budget.dart';
import 'comparison_export_encoding.dart';
import 'comparison_export_result.dart';

class ComparisonSourceUnavailable implements Exception {
  const ComparisonSourceUnavailable(this.reason);
  final ComparisonExportFailureReason reason;
}

ComparisonExportImageResult comparisonExportFailure(Object error) {
  if (error is ComparisonSourceUnavailable) {
    return ComparisonExportImageResult.failure(error.reason);
  }
  if (error is ImageBudgetException) {
    return ComparisonExportImageResult.failure(switch (error.kind) {
      ImageBudgetFailure.unsupported =>
        ComparisonExportFailureReason.unsupportedFormat,
      ImageBudgetFailure.invalidData =>
        ComparisonExportFailureReason.invalidData,
      _ => ComparisonExportFailureReason.budgetExceeded,
    }, message: error.message);
  }
  if (error is ComparisonOutputLimitException) {
    return ComparisonExportImageResult.failure(
      ComparisonExportFailureReason.budgetExceeded,
      message: error.message,
    );
  }
  return const ComparisonExportImageResult.failure(
    ComparisonExportFailureReason.renderFailed,
  );
}

Future<Uint8List?> readRemoteComparisonImage(
  String? value, {
  int maxBytes = maxImageEncodedBytes,
  http.Client? client,
}) async {
  if (value == null || value.trim().isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || !['http', 'https', 'blob'].contains(uri.scheme)) {
    return null;
  }
  if (anitabiImageHosts.contains(uri.host)) {
    final bytes = await fetchAnitabiImageBytes(
      value,
      maxBytes: maxBytes,
      client: client,
    );
    return bytes == null || bytes is Uint8List
        ? bytes as Uint8List?
        : Uint8List.fromList(bytes);
  }
  final ownedClient = client ?? http.Client();
  try {
    final response = await ownedClient
        .send(http.Request('GET', uri))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.stream.listen(null).cancel();
      return null;
    }
    return await readImageStreamBounded(
      response.stream.timeout(const Duration(seconds: 12)),
      maxBytes: maxBytes,
      declaredLength: response.contentLength,
    );
  } finally {
    if (client == null) ownedClient.close();
  }
}

int _sequence = 0;
String comparisonFileName(EncodedComparisonImage image) =>
    'comparison_${DateTime.now().microsecondsSinceEpoch}_${_sequence++}.${image.extension}';

typedef ComparisonDownload =
    Future<PlanExportDeliveryResult> Function({
      required List<int> bytes,
      required String fileName,
      required String mimeType,
      required String shareSubject,
      required String shareText,
      required String extension,
    });

Future<ComparisonExportImageResult> downloadComparisonImage(
  EncodedComparisonImage image, {
  ComparisonDownload deliver = deliverPlanExport,
}) async {
  try {
    final result = await deliver(
      bytes: image.bytes,
      fileName: comparisonFileName(image),
      mimeType: image.mimeType,
      extension: image.extension,
      shareSubject: 'MiriaGo 对比图',
      shareText: 'MiriaGo 对比图',
    );
    return result.action == PlanExportDeliveryAction.canceled
        ? const ComparisonExportImageResult.canceled()
        : const ComparisonExportImageResult.downloaded();
  } on PlanExportCanceledException {
    return const ComparisonExportImageResult.canceled();
  }
}
