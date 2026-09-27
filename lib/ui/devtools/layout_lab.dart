import 'package:flutter/material.dart';

import '../../data/pilgrimage_repository.dart';
import '../../plan/pilgrimage_models.dart';
import '../app/app.dart';
import '../design/theme.dart';
import 'preview_seeds.dart';

/// Dev tool: renders several independent app instances side by side at
/// fixed "device" sizes so adaptive layouts can be reviewed on one screen.
///
/// Open the web preview with `?lab=1` (optionally `&seed=stress`,
/// `&route=/records`).
class LayoutLab extends StatefulWidget {
  const LayoutLab({this.seed, this.route = '/go', super.key});

  final String? seed;
  final String route;

  @override
  State<LayoutLab> createState() => _LayoutLabState();
}

class _Frame {
  const _Frame(this.label, this.size);
  final String label;
  final Size size;
}

const _presets = [
  _Frame('手机 390×844', Size(390, 844)),
  _Frame('手机横屏 844×390', Size(844, 390)),
  _Frame('小屏 320×568', Size(320, 568)),
  _Frame('折叠屏 673×841', Size(673, 841)),
  _Frame('平板 820×1180', Size(820, 1180)),
  _Frame('平板横屏 1180×820', Size(1180, 820)),
  _Frame('桌面 1440×900', Size(1440, 900)),
];

class _LayoutLabState extends State<LayoutLab> {
  final Set<int> _selected = {0, 4, 6};
  bool _dark = false;
  double _textScale = 1;
  late String _route = widget.route;
  int _generation = 0;
  final _routeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _routeController.text = _route;
  }

  @override
  void dispose() {
    _routeController.dispose();
    super.dispose();
  }

  Future<PilgrimageRepository> _loader() async {
    final repository = await PreviewSeeds.build(widget.seed);
    final settings = await repository.loadAppSettings();
    await repository.saveAppSettings(
      settings.copyWith(
        themeMode: _dark ? AppThemeMode.dark : AppThemeMode.light,
      ),
    );
    return repository;
  }

  @override
  Widget build(BuildContext context) {
    final colors = _dark ? MiriaColors.dark : MiriaColors.light;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildMiriaTheme(colors),
      home: Scaffold(
        backgroundColor: _dark
            ? const Color(0xFF050708)
            : const Color(0xFFE6E2D9),
        appBar: AppBar(
          title: const Text('布局实验室'),
          actions: [
            SizedBox(
              width: 220,
              child: TextField(
                controller: _routeController,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '/go',
                ),
                onSubmitted: (value) => setState(() {
                  _route = value.trim().isEmpty ? '/go' : value.trim();
                  _generation++;
                }),
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('深色'),
              selected: _dark,
              onSelected: (value) => setState(() {
                _dark = value;
                _generation++;
              }),
            ),
            const SizedBox(width: 8),
            DropdownButton<double>(
              value: _textScale,
              items: const [
                DropdownMenuItem(value: 1, child: Text('字号 1.0')),
                DropdownMenuItem(value: 1.5, child: Text('字号 1.5')),
                DropdownMenuItem(value: 2, child: Text('字号 2.0')),
              ],
              onChanged: (value) => setState(() => _textScale = value ?? 1),
            ),
            IconButton(
              tooltip: '重新加载',
              onPressed: () => setState(() => _generation++),
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  for (var i = 0; i < _presets.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(_presets[i].label),
                        selected: _selected.contains(i),
                        onSelected: (value) => setState(() {
                          value ? _selected.add(i) : _selected.remove(i);
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final frames = [
              for (final i in _selected.toList()..sort()) _presets[i],
            ];
            if (frames.isEmpty) return const SizedBox.shrink();
            final availableHeight = constraints.maxHeight - 64;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final frame in frames)
                    Padding(
                      padding: const EdgeInsets.only(right: 24),
                      child: _DeviceFrame(
                        key: ValueKey('${frame.label}-$_generation'),
                        frame: frame,
                        maxHeight: availableHeight,
                        textScale: _textScale,
                        child: MiriaGoBootstrap(
                          repositoryLoader: _loader,
                          initialLocation: _route,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DeviceFrame extends StatelessWidget {
  const _DeviceFrame({
    required this.frame,
    required this.maxHeight,
    required this.textScale,
    required this.child,
    super.key,
  });

  final _Frame frame;
  final double maxHeight;
  final double textScale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scale = (maxHeight / frame.size.height).clamp(0.25, 1.0);
    final media = MediaQuery.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(frame.label, style: context.text.labelMedium),
        const SizedBox(height: 8),
        Container(
          width: frame.size.width * scale,
          height: frame.size.height * scale,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18 * scale + 4),
            boxShadow: Elevations.level3(MiriaColors.light),
          ),
          clipBehavior: Clip.antiAlias,
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: frame.size,
              child: MediaQuery(
                data: media.copyWith(
                  size: frame.size,
                  padding: EdgeInsets.zero,
                  viewPadding: EdgeInsets.zero,
                  viewInsets: EdgeInsets.zero,
                  textScaler: TextScaler.linear(textScale),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
