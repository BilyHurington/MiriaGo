import 'dart:convert';

import '../data/public_http.dart';
import 'plan_import_package.dart';
import 'plan_package.dart' show seichiPlanFileExtension;
import 'plan_transfer_background.dart';

/// What a pasted link points at.
sealed class PlanLink {
  const PlanLink();

  /// Reads [input] as a link to a plan file or a GitHub release. Accepts a
  /// missing scheme ("github.com/…"); refuses anything but HTTPS.
  static PlanLink parse(String input) {
    var text = input.trim();
    if (text.isEmpty) {
      throw const PlanLinkException('请输入链接');
    }
    if (!text.contains('://')) {
      text = 'https://$text';
    }
    final Uri uri;
    try {
      uri = Uri.parse(text);
    } on FormatException {
      throw const PlanLinkException('无法识别这个链接');
    }
    if (uri.scheme != 'https') {
      throw const PlanLinkException('只支持 https:// 开头的链接');
    }
    if (uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const PlanLinkException('无法识别这个链接');
    }
    if (!isPublicWebUri(uri)) {
      throw planLinkNotPublic;
    }
    final host = uri.host.toLowerCase();
    if (host == 'github.com' || host == 'www.github.com') {
      return _parseGitHub(uri) ?? PlanFileLink(uri);
    }
    return PlanFileLink(uri);
  }

  static PlanLink? _parseGitHub(Uri uri) {
    final segments = [
      for (final segment in uri.pathSegments)
        if (segment.isNotEmpty) segment,
    ];
    if (segments.length < 2) {
      return null;
    }
    final owner = segments[0];
    final repo = segments[1].endsWith('.git')
        ? segments[1].substring(0, segments[1].length - 4)
        : segments[1];
    final rest = segments.sublist(2);
    // github.com/o/r/releases/download/<tag>/<file> and
    // github.com/o/r/releases/latest/download/<file>: the file itself.
    if ((rest.length >= 4 && rest[0] == 'releases' && rest[1] == 'download') ||
        (rest.length >= 4 &&
            rest[0] == 'releases' &&
            rest[1] == 'latest' &&
            rest[2] == 'download')) {
      return PlanFileLink(uri);
    }
    // A file in the repository: github.com/o/r/raw/<ref>/<path> redirects to
    // its contents; the blob page is HTML, so fetch the raw file instead.
    if (rest.length >= 3 && rest[0] == 'raw') {
      return PlanFileLink(uri);
    }
    if (rest.length >= 3 && rest[0] == 'blob') {
      return PlanFileLink(
        Uri.https(
          'raw.githubusercontent.com',
          [owner, repo, ...rest.sublist(1)].join('/'),
        ),
      );
    }
    if (rest.length >= 3 && rest[0] == 'releases' && rest[1] == 'tag') {
      return GitHubReleaseLink(
        owner: owner,
        repo: repo,
        tag: rest.sublist(2).join('/'),
      );
    }
    // The repository, its release list or "latest": the newest release.
    return GitHubReleaseLink(owner: owner, repo: repo);
  }
}

/// A file to download as is.
class PlanFileLink extends PlanLink {
  const PlanFileLink(this.uri);

  final Uri uri;

  /// File name from the link, for messages and the import preview.
  String get fileName {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty);
    return segments.isEmpty ? uri.host : segments.last;
  }
}

/// A GitHub release whose plan files are listed through the GitHub API.
class GitHubReleaseLink extends PlanLink {
  const GitHubReleaseLink({required this.owner, required this.repo, this.tag});

  final String owner;
  final String repo;

  /// Null for the latest release.
  final String? tag;

  Uri get apiUri => Uri(
    scheme: 'https',
    host: 'api.github.com',
    // Segments, so a tag containing "/" is encoded as one segment.
    pathSegments: [
      'repos',
      owner,
      repo,
      'releases',
      ...tag == null ? ['latest'] : ['tags', tag!],
    ],
  );

  String get label => tag == null ? '$owner/$repo 最新发布' : '$owner/$repo $tag';
}

/// A downloadable file of a GitHub release.
class GitHubReleaseAsset {
  const GitHubReleaseAsset({
    required this.name,
    required this.size,
    required this.downloadUri,
  });

  final String name;
  final int size;
  final Uri downloadUri;

  bool get isPlan => name.toLowerCase().endsWith('.$seichiPlanFileExtension');
}

/// The release name and its plan-like files (.sjhplan first, then .zip).
({String releaseName, List<GitHubReleaseAsset> assets}) parseGitHubRelease(
  String body,
) {
  final Object? json;
  try {
    json = jsonDecode(body);
  } on FormatException {
    throw const PlanLinkException('GitHub 返回的发布信息无法读取');
  }
  if (json is! Map) {
    throw const PlanLinkException('GitHub 返回的发布信息无法读取');
  }
  final name = json['name'];
  final tag = json['tag_name'];
  final assets = <GitHubReleaseAsset>[];
  final rawAssets = json['assets'];
  if (rawAssets is List) {
    for (final asset in rawAssets) {
      if (asset is! Map) continue;
      final assetName = asset['name'];
      final url = asset['browser_download_url'];
      final size = asset['size'];
      if (assetName is! String || url is! String) continue;
      final lower = assetName.toLowerCase();
      if (!lower.endsWith('.$seichiPlanFileExtension') &&
          !lower.endsWith('.zip')) {
        continue;
      }
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https') continue;
      assets.add(
        GitHubReleaseAsset(
          name: assetName,
          size: size is int ? size : 0,
          downloadUri: uri,
        ),
      );
    }
  }
  assets.sort((a, b) {
    if (a.isPlan != b.isPlan) return a.isPlan ? -1 : 1;
    return a.name.compareTo(b.name);
  });
  return (
    releaseName: name is String && name.trim().isNotEmpty
        ? name.trim()
        : tag is String
        ? tag
        : '',
    assets: assets,
  );
}

/// A problem with the link or its download, worded for the user.
class PlanLinkException implements Exception {
  const PlanLinkException(this.message);

  final String message;

  @override
  String toString() => 'PlanLinkException($message)';
}

/// "41.7 MB"-style size for lists and progress.
String formatPlanLinkBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

typedef PlanLinkProgress = void Function(int received, int? total);

/// A plan file downloaded from a link: in a temporary file on phones, in
/// memory on the desktop.
class DownloadedPlanFile {
  const DownloadedPlanFile({required this.fileName, this.path, this.bytes});

  final String fileName;
  final String? path;
  final List<int>? bytes;
}

/// Network and file work behind "从链接导入"; replaced in tests.
abstract class PlanLinkService {
  /// False where links cannot be downloaded (the browser build).
  bool get available;

  /// The GitHub API answer for [link].
  Future<String> fetchRelease(GitHubReleaseLink link);

  Future<DownloadedPlanFile> download(
    Uri uri, {
    required String fileName,
    PlanLinkProgress? onProgress,
    PlanTransferCancellation? cancellation,
  });

  /// Reads the plan; see [readPlanImportPackageFromDownload].
  Future<PlanImportPackage> read(
    DownloadedPlanFile file, {
    String? entryName,
    PlanTransferCancellation? cancellation,
  });

  /// Deletes a temporary download.
  Future<void> discard(DownloadedPlanFile file);

  /// Deletes downloads left behind by an import that never finished (the
  /// app was closed during it).
  Future<void> sweep();
}

/// A download larger than [maxPlanLinkDownloadBytes].
const planLinkTooLarge = PlanLinkException('文件超过 128 MB 上限，无法导入');

const planLinkNotPublic = PlanLinkException('不支持本机或局域网地址');

/// The largest download accepted, same as a picked plan file.
int get maxPlanLinkDownloadBytes => const PlanImportLimits().maxCompressedBytes;

PlanLinkException planLinkHttpError(int statusCode) => PlanLinkException(
  statusCode == 404
      ? '链接指向的文件不存在（HTTP 404）'
      : statusCode == 403 || statusCode == 429
      ? '服务器拒绝了下载（HTTP $statusCode），请稍后再试'
      : '下载失败（HTTP $statusCode）',
);

PlanLinkException gitHubReleaseError(int statusCode) => PlanLinkException(
  statusCode == 404
      ? '没有找到这个发布：仓库可能是私有的、还没有发布版本，或只有预发布版本（请粘贴具体发布页链接）'
      : statusCode == 403 || statusCode == 429
      ? 'GitHub 请求过于频繁，请稍后再试'
      : 'GitHub 发布信息读取失败（HTTP $statusCode）',
);
