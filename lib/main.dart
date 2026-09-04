import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_shell.dart';
import 'app_theme.dart';
import 'data/local/sqlite_pilgrimage_repository.dart';
import 'data/pilgrimage_repository.dart';
import 'data/sample_pilgrimage_repository.dart';
import 'desktop/desktop_pilgrimage_repository.dart';
import 'desktop/tauri_bridge.dart';
import 'widgets/copyable_text.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
  _installDesktopErrorLogging();
  runApp(const MiriaGoBootstrap());
}

typedef PilgrimageRepositoryLoader = Future<PilgrimageRepository> Function();

class MiriaGoBootstrap extends StatefulWidget {
  const MiriaGoBootstrap({
    this.repositoryLoader = _createDefaultRepository,
    super.key,
  });

  final PilgrimageRepositoryLoader repositoryLoader;

  @override
  State<MiriaGoBootstrap> createState() => _MiriaGoBootstrapState();
}

class _MiriaGoBootstrapState extends State<MiriaGoBootstrap> {
  PilgrimageRepository? _repository;
  DesktopLauncherInfo? _launcherInfo;
  Object? _error;
  StackTrace? _stackTrace;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
      _stackTrace = null;
    });
    try {
      if (isTauriLauncherAvailable) {
        try {
          _launcherInfo = await loadDesktopLauncherInfo();
        } catch (_) {
          _launcherInfo = null;
        }
      }
      final repository = await widget.repositoryLoader();
      if (!mounted) {
        return;
      }
      setState(() {
        _repository = repository;
        _loading = false;
      });
    } catch (error, stackTrace) {
      unawaited(_writeDesktopError('startup failed', error, stackTrace));
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _stackTrace = stackTrace;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = _repository;
    if (repository != null) {
      return MiriaGoApp(repository: repository);
    }
    return MaterialApp(
      title: 'MiriaGo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Scaffold(
        body: SafeArea(
          child: _loading
              ? const _DesktopStartupLoading()
              : _DesktopStartupError(
                  error: _error,
                  stackTrace: _stackTrace,
                  launcherInfo: _launcherInfo,
                  onRetry: _start,
                ),
        ),
      ),
    );
  }
}

class _DesktopStartupLoading extends StatelessWidget {
  const _DesktopStartupLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('正在加载 MiriaGo...'),
        ],
      ),
    );
  }
}

class _DesktopStartupError extends StatelessWidget {
  const _DesktopStartupError({
    required this.error,
    required this.stackTrace,
    required this.launcherInfo,
    required this.onRetry,
  });

  final Object? error;
  final StackTrace? stackTrace;
  final DesktopLauncherInfo? launcherInfo;
  final Future<void> Function() onRetry;

  Future<void> _openDirectory(BuildContext context, String target) async {
    try {
      await openDesktopDirectory(target: target);
    } catch (openError) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法打开目录：$openError')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = [
      if (error != null) error.toString(),
      if (stackTrace != null) stackTrace.toString(),
    ].join('\n');
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 52,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'MiriaGo 启动失败',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                '用户数据没有被删除。请重试，或打开日志目录查看 startup.log。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const ValueKey('desktop-startup-retry'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
              if (launcherInfo != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _openDirectory(context, 'logs'),
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('打开日志目录'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openDirectory(context, 'data'),
                      icon: const Icon(Icons.folder_open_outlined),
                      label: const Text('打开数据目录'),
                    ),
                  ],
                ),
              ],
              if (details.isNotEmpty) ...[
                const SizedBox(height: 20),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('错误详情'),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: SelectionArea(
                        child: Text(
                          details,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class MiriaGoApp extends StatelessWidget {
  const MiriaGoApp({this.repository, super.key});

  final PilgrimageRepository? repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MiriaGo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      navigatorObservers: [copyOverlayNavigatorObserver],
      home: AppShell(
        repository:
            repository ??
            (kIsWeb
                ? SamplePilgrimageRepository()
                : SqlitePilgrimageRepository()),
      ),
    );
  }
}

Future<PilgrimageRepository> _createDefaultRepository() async {
  if (!kIsWeb) {
    return SqlitePilgrimageRepository();
  }
  if (isTauriLauncherAvailable) {
    return DesktopPilgrimageRepository.create();
  }
  return SamplePilgrimageRepository();
}

void _installDesktopErrorLogging() {
  if (!kIsWeb || !isTauriLauncherAvailable) {
    return;
  }
  final previousFlutterHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    unawaited(
      _writeDesktopError(
        'Flutter framework error',
        details.exception,
        details.stack,
      ),
    );
    if (previousFlutterHandler != null) {
      previousFlutterHandler(details);
    } else {
      FlutterError.presentError(details);
    }
  };
  final previousPlatformHandler = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(_writeDesktopError('uncaught Dart error', error, stackTrace));
    return previousPlatformHandler?.call(error, stackTrace) ?? false;
  };
}

Future<void> _writeDesktopError(
  String label,
  Object error,
  StackTrace? stackTrace,
) async {
  if (!isTauriLauncherAvailable) {
    return;
  }
  try {
    await appendDesktopStartupLog(
      message: '$label: $error${stackTrace == null ? '' : '\n$stackTrace'}',
    );
  } catch (_) {}
}
