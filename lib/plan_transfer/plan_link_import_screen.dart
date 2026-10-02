import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_theme.dart';
import '../data/pilgrimage_repository.dart';
import '../widgets/app_back_button.dart';
import '../widgets/app_status_banner.dart';
import 'plan_import_package.dart';
import 'plan_import_preview_screen.dart';
import 'plan_link.dart';
import 'plan_link_service.dart';
import 'plan_transfer_background.dart';

/// "从链接导入": downloads a plan from a GitHub release or any HTTPS link
/// (a .sjhplan, or a .zip carrying one) and opens the import preview.
/// Resolves to true once a plan was imported.
class PlanLinkImportScreen extends StatefulWidget {
  PlanLinkImportScreen({
    required this.repository,
    PlanLinkService? service,
    this.initialLink,
    super.key,
  }) : service = service ?? createPlanLinkService();

  final PilgrimageRepository repository;
  final PlanLinkService service;
  final String? initialLink;

  @override
  State<PlanLinkImportScreen> createState() => _PlanLinkImportScreenState();
}

enum _Phase { idle, resolving, choosingAsset, downloading, reading }

class _PlanLinkImportScreenState extends State<PlanLinkImportScreen> {
  late final _link = TextEditingController(text: widget.initialLink ?? '');
  var _phase = _Phase.idle;
  String? _error;
  String _releaseName = '';
  List<GitHubReleaseAsset> _assets = const [];
  String _downloadName = '';
  var _received = 0;
  int? _total;
  PlanTransferCancellation? _cancellation;
  DownloadedPlanFile? _file;

  bool get _busy =>
      _phase == _Phase.resolving ||
      _phase == _Phase.downloading ||
      _phase == _Phase.reading;

  @override
  void initState() {
    super.initState();
    _link.addListener(_onLinkChanged);
    // Downloads left behind when the app was closed mid-import.
    widget.service.sweep();
  }

  @override
  void dispose() {
    _cancellation?.cancel();
    _discardFile();
    _link.dispose();
    super.dispose();
  }

  void _onLinkChanged() => setState(() {});

  /// The current attempt's download, deleted on cancel or close.
  void _discardFile() {
    final file = _file;
    if (file != null) _discard(file);
  }

  /// Deletes one attempt's download; never another attempt's.
  void _discard(DownloadedPlanFile file) {
    if (identical(_file, file)) _file = null;
    widget.service.discard(file);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty || !mounted) return;
    _link.text = text;
    _link.selection = TextSelection.collapsed(offset: text.length);
  }

  Future<void> _start() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final PlanLink link;
    try {
      link = PlanLink.parse(_link.text);
    } on PlanLinkException catch (error) {
      setState(() => _error = error.message);
      return;
    }
    final cancellation = _beginWork(_Phase.resolving);
    switch (link) {
      case PlanFileLink():
        await _download(link.uri, link.fileName, cancellation);
      case GitHubReleaseLink():
        await _resolveRelease(link, cancellation);
    }
  }

  PlanTransferCancellation _beginWork(_Phase phase) {
    _cancellation?.cancel();
    final cancellation = PlanTransferCancellation();
    _cancellation = cancellation;
    setState(() {
      _phase = phase;
      _error = null;
    });
    return cancellation;
  }

  Future<void> _resolveRelease(
    GitHubReleaseLink link,
    PlanTransferCancellation cancellation,
  ) async {
    try {
      final release = parseGitHubRelease(
        await widget.service.fetchRelease(link),
      );
      if (!mounted || cancellation.isCancelled) return;
      if (release.assets.isEmpty) {
        throw const PlanLinkException('这个发布中没有 .sjhplan 或 .zip 文件');
      }
      if (release.assets.length == 1) {
        final asset = release.assets.single;
        await _download(asset.downloadUri, asset.name, cancellation);
        return;
      }
      setState(() {
        _phase = _Phase.choosingAsset;
        _releaseName = release.releaseName.isEmpty
            ? link.label
            : release.releaseName;
        _assets = release.assets;
      });
    } on Object catch (error) {
      _fail(error, cancellation);
    }
  }

  Future<void> _downloadAsset(GitHubReleaseAsset asset) async {
    final cancellation = _beginWork(_Phase.downloading);
    await _download(asset.downloadUri, asset.name, cancellation);
  }

  Future<void> _download(
    Uri uri,
    String fileName,
    PlanTransferCancellation cancellation,
  ) async {
    // Link and GitHub file names are already decoded.
    setState(() {
      _phase = _Phase.downloading;
      _downloadName = fileName;
      _received = 0;
      _total = null;
    });
    var lastProgress = DateTime.fromMillisecondsSinceEpoch(0);
    final DownloadedPlanFile file;
    try {
      file = await widget.service.download(
        uri,
        fileName: fileName,
        cancellation: cancellation,
        onProgress: (received, total) {
          if (!mounted || cancellation.isCancelled) return;
          // A rebuild per network chunk would be thousands for a large plan.
          final now = DateTime.now();
          if (now.difference(lastProgress) <
                  const Duration(milliseconds: 100) &&
              received != total) {
            return;
          }
          lastProgress = now;
          setState(() {
            _received = received;
            _total = total;
          });
        },
      );
    } on Object catch (error) {
      _fail(error, cancellation);
      return;
    }
    if (!mounted || cancellation.isCancelled) {
      await widget.service.discard(file);
      return;
    }
    _file = file;
    await _read(file, cancellation);
  }

  Future<void> _read(
    DownloadedPlanFile file,
    PlanTransferCancellation cancellation, {
    String? entryName,
  }) async {
    setState(() => _phase = _Phase.reading);
    final PlanImportPackage importPackage;
    try {
      importPackage = await widget.service.read(
        file,
        entryName: entryName,
        cancellation: cancellation,
      );
    } on PlanArchiveChoiceRequired catch (choice) {
      if (!mounted || cancellation.isCancelled) return;
      // Nothing is running while the user picks.
      setState(() => _phase = _Phase.idle);
      final chosen = await _chooseEntry(choice.entries);
      if (!mounted || cancellation.isCancelled) return;
      if (chosen == null) {
        _discard(file);
        setState(() => _phase = _Phase.idle);
        return;
      }
      await _read(file, cancellation, entryName: chosen);
      return;
    } on Object catch (error) {
      _discard(file);
      _fail(error, cancellation);
      return;
    }
    // Everything needed is in memory now.
    _discard(file);
    if (!mounted || cancellation.isCancelled) return;
    setState(() => _phase = _Phase.idle);
    final imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PlanImportPreviewScreen(
          importPackage: importPackage,
          repository: widget.repository,
        ),
      ),
    );
    if (imported == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<String?> _chooseEntry(List<PlanArchiveEntry> entries) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          key: const ValueKey('plan-link-entry-sheet'),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '压缩包里有多个计划，选择要导入的一个',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            for (final entry in entries)
              ListTile(
                key: ValueKey('plan-link-entry-${entry.name}'),
                leading: Icon(LucideIcons.package, color: AppColors.accentDark),
                title: Text(entry.fileName),
                subtitle: Text(formatPlanLinkBytes(entry.size)),
                onTap: () => Navigator.of(context).pop(entry.name),
              ),
          ],
        ),
      ),
    );
  }

  /// Reports a failure of the attempt [cancellation] belongs to; a
  /// cancelled (older) attempt stays silent.
  void _fail(Object error, PlanTransferCancellation cancellation) {
    if (!mounted || cancellation.isCancelled) return;
    if (error is PlanTransferCancelledException) {
      setState(() => _phase = _Phase.idle);
      return;
    }
    debugPrint('Link import failed: $error');
    setState(() {
      _phase = _Phase.idle;
      _error = _messageFor(error);
    });
  }

  void _cancel() {
    _cancellation?.cancel();
    _cancellation = null;
    _discardFile();
    setState(() => _phase = _Phase.idle);
  }

  static String _messageFor(Object error) => switch (error) {
    PlanLinkException() => error.message,
    PlanImportLimitException() => error.message,
    PlanArchiveHasNoPlanException() => '压缩包里没有 .sjhplan 计划文件',
    FormatException() => '下载的文件不是 MiriaGo 计划包',
    _ => '读取失败，请重试',
  };

  @override
  Widget build(BuildContext context) {
    final available = widget.service.available;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _cancellation?.cancel();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          title: const Text('从链接导入'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              '粘贴 GitHub 发布页面或计划文件的下载链接，MiriaGo 会下载计划并打开导入预览。',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 14),
            if (!available) ...[
              const AppStatusBanner(
                kind: AppStatusBannerKind.warning,
                title: '网页版无法直接下载',
                subtitle:
                    '请先在浏览器中下载 .sjhplan 或 .zip，再回到“导入导出”，用“导入 MiriaGo 文件”导入。',
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              key: const ValueKey('plan-link-input'),
              controller: _link,
              enabled: available && !_busy,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _start(),
              decoration: InputDecoration(
                labelText: '链接',
                hintText: 'https://github.com/…/releases/…',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  key: const ValueKey('plan-link-paste'),
                  tooltip: '粘贴',
                  onPressed: available && !_busy ? _paste : null,
                  icon: const Icon(LucideIcons.clipboardPaste),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('plan-link-start'),
              onPressed: available && !_busy && _link.text.trim().isNotEmpty
                  ? _start
                  : null,
              icon: const Icon(LucideIcons.download),
              label: const Text('读取链接'),
            ),
            const SizedBox(height: 16),
            ..._status(),
            const SizedBox(height: 16),
            Text(
              '支持：\n'
              '• GitHub 发布页面或仓库链接（自动列出最新发布中的计划文件）\n'
              '• GitHub 发布中的文件下载链接\n'
              '• 其他 https:// 开头的 .sjhplan 或 .zip 直链\n'
              '.zip 中可以带说明等其他文件，MiriaGo 只读取其中的 .sjhplan。'
              '下载会连接你输入的地址（以及它跳转到的下载服务器）；'
              'GitHub 发布或仓库链接还会向 api.github.com 查询发布中的文件。',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.5,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _status() {
    final error = _error;
    switch (_phase) {
      case _Phase.idle:
        return [
          if (error != null)
            AppStatusBanner(
              key: const ValueKey('plan-link-error'),
              kind: AppStatusBannerKind.error,
              title: error,
            ),
        ];
      case _Phase.resolving:
        return [
          AppStatusBanner(
            kind: AppStatusBannerKind.running,
            title: '正在查找发布中的计划文件…',
            actionLabel: '取消',
            actionKey: const ValueKey('plan-link-cancel'),
            onAction: _cancel,
          ),
        ];
      case _Phase.choosingAsset:
        return [
          Text(
            '选择要导入的文件',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _releaseName,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _assets.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                key: ValueKey('plan-link-asset-$i'),
                leading: Icon(
                  _assets[i].isPlan
                      ? LucideIcons.package
                      : LucideIcons.fileArchive,
                  color: AppColors.accentDark,
                ),
                title: Text(_assets[i].name),
                subtitle: Text(
                  '${formatPlanLinkBytes(_assets[i].size)}'
                  '${_assets[i].isPlan ? '' : ' · 压缩包'}',
                ),
                trailing: const Icon(LucideIcons.download),
                onTap: () => _downloadAsset(_assets[i]),
              ),
            ),
        ];
      case _Phase.downloading:
        final total = _total;
        return [
          AppStatusBanner(
            kind: AppStatusBannerKind.running,
            title: '正在下载 $_downloadName',
            subtitle: total == null || total <= 0
                ? '已下载 ${formatPlanLinkBytes(_received)}'
                : '${formatPlanLinkBytes(_received)} / '
                      '${formatPlanLinkBytes(total)}',
            footer: LinearProgressIndicator(
              key: const ValueKey('plan-link-progress'),
              value: total == null || total <= 0
                  ? null
                  : (_received / total).clamp(0.0, 1.0),
            ),
            actionLabel: '取消',
            actionKey: const ValueKey('plan-link-cancel'),
            onAction: _cancel,
          ),
        ];
      case _Phase.reading:
        return [
          AppStatusBanner(
            kind: AppStatusBannerKind.running,
            title: '正在读取计划…',
            footer: const LinearProgressIndicator(),
            actionLabel: '取消',
            actionKey: const ValueKey('plan-link-cancel'),
            onAction: _cancel,
          ),
        ];
    }
  }
}
