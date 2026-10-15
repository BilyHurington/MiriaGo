import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_theme.dart';
import '../data/pilgrimage_repository.dart';
import '../widgets/app_back_button.dart';
import '../widgets/app_status_banner.dart';
import '../widgets/input_dialog.dart';
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

class _LinkImportAction extends StatelessWidget {
  const _LinkImportAction({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.primary = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final foreground = enabled && primary
        ? AppColors.onAccent
        : enabled
        ? AppColors.textPrimary
        : AppColors.textSecondary;
    final radius = BorderRadius.circular(8);
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: enabled && primary
            ? AppColors.accent
            : enabled
            ? AppColors.surface
            : AppColors.surfaceMuted,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: enabled && primary ? AppColors.accent : AppColors.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: enabled && !primary
                      ? AppColors.accentForeground
                      : foreground,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(LucideIcons.chevronRight, size: 18, color: foreground),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
      backgroundColor: AppColors.overlaySurface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        side: AppColors.isDark
            ? BorderSide(color: AppColors.border)
            : BorderSide.none,
      ),
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          key: const ValueKey('plan-link-entry-sheet'),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
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
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _LinkImportAction(
                  key: ValueKey('plan-link-entry-${entry.name}'),
                  icon: LucideIcons.package,
                  title: entry.fileName,
                  subtitle: formatPlanLinkBytes(entry.size),
                  onTap: () => Navigator.of(context).pop(entry.name),
                ),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '通过链接获取计划',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '粘贴 GitHub 发布页面或计划文件的下载链接。',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.eye,
                            size: 16,
                            color: AppColors.accentForeground,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '下载后先预览，再选择导入内容。',
                              style: TextStyle(
                                color: AppColors.accentForeground,
                                fontSize: 12,
                                height: 1.3,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
                  AppDialogField(
                    label: '链接',
                    child: TextField(
                      key: const ValueKey('plan-link-input'),
                      controller: _link,
                      enabled: available && !_busy,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.go,
                      onSubmitted: available && !_busy ? (_) => _start() : null,
                      onTapOutside: dismissKeyboardOnTapOutside,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      decoration:
                          appDialogInputDecoration(
                            hintText: 'https://github.com/…/releases/…',
                          ).copyWith(
                            suffixIcon: IconButton(
                              key: const ValueKey('plan-link-paste'),
                              tooltip: '粘贴',
                              onPressed: available && !_busy ? _paste : null,
                              icon: const Icon(LucideIcons.clipboardPaste),
                              style: IconButton.styleFrom(
                                foregroundColor: AppColors.accentForeground,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LinkImportAction(
                    key: const ValueKey('plan-link-start'),
                    primary: true,
                    onTap: available && !_busy && _link.text.trim().isNotEmpty
                        ? _start
                        : null,
                    icon: LucideIcons.download,
                    title: '读取链接',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ..._status(),
            const SizedBox(height: 16),
            Text(
              '支持的链接类型',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  for (final (index, (icon, title, description)) in const [
                    (LucideIcons.package, 'GitHub 发布页面或仓库', '自动列出最新发布中的计划文件'),
                    (LucideIcons.download, 'GitHub 文件下载链接', '直接读取发布中的计划文件'),
                    (
                      LucideIcons.link,
                      'HTTPS 文件直链',
                      '支持 .sjhplan 计划包和 .zip 压缩包',
                    ),
                  ].indexed) ...[
                    if (index > 0) const AppHairline(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              icon,
                              size: 18,
                              color: AppColors.accentForeground,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  description,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    height: 1.3,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '.zip 中可以带说明等其他文件，MiriaGo 只读取其中的 .sjhplan。\n'
              '下载会连接你输入的地址及其跳转到的下载服务器；'
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
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _LinkImportAction(
                key: ValueKey('plan-link-asset-$i'),
                icon: _assets[i].isPlan
                    ? LucideIcons.package
                    : LucideIcons.fileArchive,
                title: _assets[i].name,
                subtitle:
                    '${formatPlanLinkBytes(_assets[i].size)}'
                    '${_assets[i].isPlan ? '' : ' · 压缩包'}',
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
