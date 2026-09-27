import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../../application/settings/diagnostics_service.dart';
import '../../../../application/settings/settings_options.dart';
import '../../../../application/settings_store.dart';
import '../../../../data/anitabi_service_config.dart';
import '../../../../plan/pilgrimage_models.dart';
import '../../../components/components.dart';
import '../settings_widgets.dart';

/// Anitabi 服务地址 sub page: five editable HTTPS base addresses, connection
/// tests and 「恢复默认地址」.
class AnitabiServiceSettingsSection extends StatefulWidget {
  const AnitabiServiceSettingsSection({this.diagnostics, super.key});

  /// Overridable for tests.
  final DiagnosticsService? diagnostics;

  @override
  State<AnitabiServiceSettingsSection> createState() =>
      _AnitabiServiceSettingsSectionState();
}

class _AnitabiServiceSettingsSectionState
    extends State<AnitabiServiceSettingsSection> {
  late final AnitabiConnectionTest _test = AnitabiConnectionTest(
    service: widget.diagnostics,
  );

  @override
  void dispose() {
    _test.dispose();
    super.dispose();
  }

  Future<void> _edit(AnitabiService service) async {
    final store = context.read<SettingsStore>();
    final value = await showUrlInputDialog(
      context,
      title: service.title,
      initialValue: service.valueIn(store.settings),
      helperText: '仅支持公开可访问的 HTTPS 基础地址，不要填写接口路径参数。',
      validator: validateAnitabiBaseUrl,
    );
    if (value == null || !mounted) return;
    _test.clear();
    await store.patch(
      (s) => service.apply(
        s,
        normalizeAnitabiBaseUrl(value, fallback: value.trim()),
      ),
    );
  }

  Future<void> _restoreDefaults() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '恢复默认地址',
      message: '将把全部 Anitabi 服务地址恢复为官方默认值。',
      confirmLabel: '恢复默认',
      notice: '当前自定义地址不会被保留',
      emphasizedValues: const ['全部 Anitabi 服务地址'],
    );
    if (!confirmed || !mounted) return;
    _test.clear();
    await context.read<SettingsStore>().patch(restoreDefaultAnitabiService);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>().settings;
    return ListenableBuilder(
      listenable: _test,
      builder: (context, _) => SettingsGroup(
        title: '服务地址',
        children: [
          for (final service in AnitabiService.values)
            _ServiceRow(
              key: ValueKey('anitabi-service-${service.name}'),
              service: service,
              url: service.valueIn(settings),
              status: _test.results[service],
              testing: _test.isPending(service),
              onTap: () => _edit(service),
            ),
          SettingsBlock(
            padding: const EdgeInsets.fromLTRB(
              Space.x4,
              Space.x3,
              Space.x4,
              Space.x1,
            ),
            child: MiriaButton(
              key: const ValueKey('anitabi-service-test-all'),
              label: _test.testing ? '正在测试连接' : '测试全部连接',
              icon: Symbols.wifi_rounded,
              loading: _test.testing,
              expand: true,
              onPressed: _test.testing
                  ? null
                  : () => unawaited(_test.run(settings.anitabiServiceConfig)),
            ),
          ),
          SettingsBlock(
            child: MiriaButton.secondary(
              key: const ValueKey('anitabi-service-restore-defaults'),
              label: '恢复默认地址',
              icon: Symbols.history_rounded,
              expand: true,
              onPressed: _test.testing ? null : _restoreDefaults,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.service,
    required this.url,
    required this.status,
    required this.testing,
    required this.onTap,
    super.key,
  });

  final AnitabiService service;
  final String url;
  final String? status;
  final bool testing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final succeeded = anitabiProbeSucceeded(status);
    Widget? statusWidget;
    if (testing) {
      statusWidget = const SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (status != null) {
      statusWidget = Tooltip(
        message: status!,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 108),
          child: Text(
            compactAnitabiProbeStatus(status!),
            key: ValueKey('anitabi-service-status-${service.title}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: context.text.labelMedium?.copyWith(
              color: succeeded ? c.success : c.danger,
            ),
          ),
        ),
      );
    }
    return ListRow(
      leading: Icon(_icon(service), color: c.primaryText),
      title: service.title,
      subtitle: url,
      subtitleMaxLines: 1,
      trailing: statusWidget,
      showChevron: true,
      semanticLabel: status == null
          ? '${service.title}，$url'
          : '${service.title}，$url，$status',
      onTap: onTap,
    );
  }

  static IconData _icon(AnitabiService service) => switch (service) {
    AnitabiService.site => Symbols.language_rounded,
    AnitabiService.staticData => Symbols.data_object_rounded,
    AnitabiService.api => Symbols.webhook_rounded,
    AnitabiService.officialImage => Symbols.image_rounded,
    AnitabiService.mirrorImage => Symbols.cloud_rounded,
  };
}
