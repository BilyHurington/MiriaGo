import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../components/components.dart';

/// 隐私政策: the bundled `docs/privacy.md`, selectable, without remote
/// images (replaced by their alt text) or tappable links.
class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});

  static const assetPath = 'docs/privacy.md';

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  AssetBundle? _bundle;
  late Future<String> _policy;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bundle = DefaultAssetBundle.of(context);
    if (!identical(bundle, _bundle)) {
      _bundle = bundle;
      _policy = _load();
    }
  }

  Future<String> _load() =>
      _bundle!.loadString(PrivacyPage.assetPath, cache: false);

  void _retry() {
    setState(() {
      _policy = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MiriaPageScaffold(
      title: '隐私政策',
      body: SafeArea(
        top: false,
        child: FutureBuilder<String>(
          future: _policy,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ProgressRing(),
                    const SizedBox(height: Space.x4),
                    Text('正在读取隐私政策...', style: context.text.bodyMedium),
                  ],
                ),
              );
            }
            if (snapshot.hasError) {
              return ErrorState(
                title: '隐私政策读取失败',
                icon: Symbols.error_rounded,
                onRetry: _retry,
              );
            }
            return _PolicyMarkdown(data: snapshot.data!);
          },
        ),
      ),
    );
  }
}

class _PolicyMarkdown extends StatelessWidget {
  const _PolicyMarkdown({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final gutter = context.layout.gutter;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.max(
          gutter,
          (constraints.maxWidth - WindowLayout.readingWidth) / 2,
        );
        return Markdown(
          data: data,
          selectable: true,
          padding: EdgeInsets.fromLTRB(side, Space.x2, side, Space.x6),
          // The bundled policy never needs remote media or link launching.
          imageBuilder: (_, _, alt) => Text(alt ?? ''),
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: text.bodyMedium,
            h1: text.headlineSmall,
            h2: text.titleLarge,
            h3: text.titleMedium,
            listBullet: text.bodyMedium,
            a: text.bodyMedium?.copyWith(color: c.primaryText),
            code: text.bodySmall?.copyWith(
              backgroundColor: c.surfaceMuted,
              fontFamily: 'monospace',
            ),
            blockquoteDecoration: BoxDecoration(
              color: c.surfaceMuted,
              borderRadius: Radii.smAll,
            ),
            horizontalRuleDecoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.hairline)),
            ),
          ),
        );
      },
    );
  }
}
