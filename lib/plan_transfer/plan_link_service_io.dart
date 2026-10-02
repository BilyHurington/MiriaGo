import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../data/public_http.dart';
import 'plan_import_package.dart';
import 'plan_import_stream.dart';
import 'plan_link.dart';
import 'plan_transfer_background.dart';

PlanLinkService createPlanLinkService() => _IoPlanLinkService();

/// GitHub asks API clients to name themselves.
const _userAgent = 'MiriaGo';

class _IoPlanLinkService implements PlanLinkService {
  @override
  bool get available => true;

  @override
  Future<String> fetchRelease(GitHubReleaseLink link) async {
    final client = http.Client();
    try {
      final response = await getPublic(
        client,
        link.apiUri,
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': _userAgent,
        },
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw gitHubReleaseError(response.statusCode);
      }
      return response.body;
    } on PlanLinkException {
      rethrow;
    } on Object {
      throw const PlanLinkException('无法连接 GitHub，请检查网络后重试');
    } finally {
      client.close();
    }
  }

  @override
  Future<DownloadedPlanFile> download(
    Uri uri, {
    required String fileName,
    PlanLinkProgress? onProgress,
    PlanTransferCancellation? cancellation,
  }) async {
    final Directory directory;
    try {
      directory = await _downloadDirectory();
      await directory.create(recursive: true);
    } on Object {
      throw const PlanLinkException('无法创建临时文件，请检查存储空间');
    }
    final client = http.Client();
    // Closing the client aborts the transfer at once.
    unawaited(cancellation?.whenCancelled.then((_) => client.close()));
    final file = File(
      '${directory.path}/download_${DateTime.now().microsecondsSinceEpoch}',
    );
    IOSink? sink;
    try {
      final response = await sendPublicGet(
        client,
        uri,
        headers: const {'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.stream.listen(null).cancel();
        throw planLinkHttpError(response.statusCode);
      }
      final total = response.contentLength;
      final limit = maxPlanLinkDownloadBytes;
      if (total != null && total > limit) {
        await response.stream.listen(null).cancel();
        throw planLinkTooLarge;
      }
      sink = file.openWrite();
      var received = 0;
      onProgress?.call(0, total);
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 60),
      )) {
        cancellation?.throwIfCancelled();
        received += chunk.length;
        if (received > limit) {
          throw planLinkTooLarge;
        }
        sink.add(chunk);
        onProgress?.call(received, total);
      }
      await sink.close();
      sink = null;
      cancellation?.throwIfCancelled();
      return DownloadedPlanFile(fileName: fileName, path: file.path);
    } on Object catch (error) {
      await sink?.close().catchError((Object _) {});
      await _deleteQuietly(file);
      if (cancellation?.isCancelled ?? false) {
        throw const PlanTransferCancelledException();
      }
      if (error is PlanLinkException ||
          error is PlanTransferCancelledException) {
        rethrow;
      }
      if (error is http.ClientException &&
          error.message.contains('non-public')) {
        throw planLinkNotPublic;
      }
      if (error is FileSystemException) {
        throw const PlanLinkException('无法保存下载的文件，请检查存储空间');
      }
      throw const PlanLinkException('下载失败，请检查网络后重试');
    } finally {
      client.close();
    }
  }

  @override
  Future<PlanImportPackage> read(
    DownloadedPlanFile file, {
    String? entryName,
    PlanTransferCancellation? cancellation,
  }) {
    final path = file.path!;
    final sourceName = file.fileName;
    return runPlanTransferTask(
      () => _readDownload(path, sourceName, entryName),
      cancellation: cancellation,
    );
  }

  @override
  Future<void> sweep() async {
    try {
      final directory = await _downloadDirectory();
      if (!await directory.exists()) return;
      await for (final entry in directory.list()) {
        if (entry is File) await _deleteQuietly(entry);
      }
    } on Object {
      // Best effort; the system clears the temporary directory eventually.
    }
  }

  @override
  Future<void> discard(DownloadedPlanFile file) async {
    final path = file.path;
    if (path != null) {
      await _deleteQuietly(File(path));
    }
  }
}

Future<Directory> _downloadDirectory() async =>
    Directory('${(await getTemporaryDirectory()).path}/link_imports');

Future<PlanImportPackage> _readDownload(
  String path,
  String sourceName,
  String? entryName,
) async {
  final bytes = await readBoundedPlanImportStream(File(path).openRead());
  return readPlanImportPackageFromDownload(
    bytes,
    sourceName: sourceName,
    entryName: entryName,
  );
}

Future<void> _deleteQuietly(File file) async {
  try {
    if (await file.exists()) {
      await file.delete();
    }
  } on FileSystemException {
    // A leftover in the temporary directory is cleared by the system.
  }
}
