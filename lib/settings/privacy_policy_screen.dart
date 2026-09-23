import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_theme.dart';
import '../widgets/app_back_button.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  static const assetPath = 'docs/privacy.md';

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  AssetBundle? _bundle;
  late Future<String> _policy;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bundle = DefaultAssetBundle.of(context);
    if (!identical(bundle, _bundle)) {
      _bundle = bundle;
      _policy = _loadPolicy();
    }
  }

  Future<String> _loadPolicy() async =>
      _bundle!.loadString(PrivacyPolicyScreen.assetPath, cache: false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: appBackButtonIfCanPop(context),
        title: const Text('隐私政策'),
      ),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: _policy,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在读取隐私政策...'),
                  ],
                ),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('隐私政策读取失败', textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _policy = _loadPolicy();
                        }),
                        icon: const Icon(LucideIcons.refreshCw),
                        label: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Markdown(
              data: snapshot.data!,
              selectable: true,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              // The bundled policy never needs remote media or link launching.
              imageBuilder: (_, _, alt) => Text(alt ?? ''),
            );
          },
        ),
      ),
    );
  }
}
