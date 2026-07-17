import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../app_theme.dart';
import '../data/bangumi_api_client.dart';
import '../data/anitabi_link_parser.dart';
import '../data/pilgrimage_repository.dart';
import '../data/user_reference_image_stub.dart'
    if (dart.library.io) '../data/user_reference_image_io.dart';
import '../map/map_tile_config.dart';
import '../widgets/snackbar_helper.dart';
import '../widgets/reference_thumbnail_stub.dart'
    if (dart.library.io) '../widgets/reference_thumbnail_io.dart';
import '../widgets/image_viewer_screen.dart';
import 'anitabi_map_import_screen.dart';
import 'coordinate_parser.dart';
import 'pilgrimage_work_dropdown.dart';
import 'pilgrimage_models.dart';
import 'reference_image_status.dart';
import 'work_manager_screen.dart';

InputDecoration stableInputDecoration({
  required String labelText,
  String? hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    helperText: ' ',
  );
}

InputDecoration _boxedFormDecoration({String? hintText}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(
      color: AppColors.textSecondary.withValues(alpha: 0.42),
      fontSize: 14,
      letterSpacing: 0,
    ),
    helperText: ' ',
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.accent, width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
    ),
  );
}

class AddPointsScreen extends StatefulWidget {
  AddPointsScreen({
    required this.plan,
    required this.repository,
    BangumiApiClient? bangumiApiClient,
    super.key,
  }) : bangumiApiClient = bangumiApiClient ?? BangumiApiClient();

  final PilgrimagePlan? plan;
  final PilgrimageRepository repository;
  final BangumiApiClient bangumiApiClient;

  @override
  State<AddPointsScreen> createState() => _AddPointsScreenState();
}

class _AddPointsScreenState extends State<AddPointsScreen> {
  late PilgrimagePlan? _plan = widget.plan;
  var _didUpdate = false;

  @override
  Widget build(BuildContext context) {
    final currentPlan = _plan;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }

        Navigator.of(context).pop(_didUpdate);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('添加内容')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (currentPlan != null) ...[
              Text(
                '加入到：${currentPlan.name}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 12),
            ],
            _WorkSummary(plan: currentPlan),
            const SizedBox(height: 12),
            _AddSourceCard(
              icon: Icons.movie_filter_outlined,
              title: '作品管理',
              body: '管理计划作品，支持 Bangumi 搜索、手动添加和删除作品。',
              enabled: currentPlan != null,
              actionLabel: currentPlan == null ? '不可用' : '管理',
              onTap: currentPlan == null
                  ? null
                  : () => _openWorkManager(context, currentPlan),
            ),
            const SizedBox(height: 8),
            _AddSourceCard(
              icon: Icons.map_outlined,
              title: '从作品地图导入点位',
              body: '在 Anitabi 地图上查看作品点位，点击缩略图详情后加入计划。',
              enabled: currentPlan != null,
              actionLabel: currentPlan == null ? '不可用' : '打开',
              onTap: currentPlan == null
                  ? null
                  : () => _openAnitabiMapImport(context, currentPlan),
            ),
            const SizedBox(height: 8),
            _AddSourceCard(
              icon: Icons.travel_explore_outlined,
              title: '从 Anitabi 链接导入',
              body: '粘贴 Anitabi 作品或点位链接，快速打开对应作品地图。',
              enabled: currentPlan != null,
              actionLabel: currentPlan == null ? '不可用' : '输入',
              onTap: currentPlan == null
                  ? null
                  : () => _openAnitabiLinkImport(context, currentPlan),
            ),
            const SizedBox(height: 8),
            _AddSourceCard(
              icon: Icons.add_location_alt_outlined,
              title: '手动添加点位',
              body: '选择已添加作品，再输入名称、坐标和场景信息。',
              enabled: currentPlan != null,
              actionLabel: currentPlan == null ? '不可用' : '添加',
              onTap: currentPlan == null
                  ? null
                  : () => _openManualPointForm(context, currentPlan),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWorkManager(
    BuildContext context,
    PilgrimagePlan plan,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => WorkManagerScreen(
          plan: plan,
          repository: widget.repository,
          bangumiApiClient: widget.bangumiApiClient,
        ),
      ),
    );
    if (!context.mounted) {
      return;
    }

    await _reloadPlan(plan.id);
  }

  Future<void> _openAnitabiMapImport(
    BuildContext context,
    PilgrimagePlan plan,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            AnitabiMapImportScreen(plan: plan, repository: widget.repository),
      ),
    );
    if (!context.mounted) {
      return;
    }

    final changed = await _reloadPlan(plan.id);
    if (!context.mounted || !changed) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _openAnitabiLinkImport(
    BuildContext context,
    PilgrimagePlan plan,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            _AnitabiLinkImportScreen(plan: plan, repository: widget.repository),
      ),
    );
    if (!context.mounted) {
      return;
    }

    final changed = await _reloadPlan(plan.id);
    if (!context.mounted || !changed) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _openManualPointForm(
    BuildContext context,
    PilgrimagePlan plan,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            _ManualPointFormScreen(plan: plan, repository: widget.repository),
      ),
    );
    if (!context.mounted) {
      return;
    }

    final changed = await _reloadPlan(plan.id);
    if (!context.mounted || !changed) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<bool> _reloadPlan(String planId) async {
    final oldPlan = _plan;
    final plans = await widget.repository.loadPlans();
    if (!mounted) {
      return false;
    }
    final updatedPlan = plans.firstWhere((plan) => plan.id == planId);
    final changed =
        oldPlan == null ||
        oldPlan.works.length != updatedPlan.works.length ||
        oldPlan.points.length != updatedPlan.points.length ||
        oldPlan.groups.length != updatedPlan.groups.length;

    setState(() {
      _plan = updatedPlan;
      _didUpdate = _didUpdate || changed;
    });
    return changed;
  }
}

class BangumiWorkSearchScreen extends StatefulWidget {
  const BangumiWorkSearchScreen({
    required this.plan,
    required this.repository,
    required this.bangumiApiClient,
    super.key,
  });

  final PilgrimagePlan plan;
  final PilgrimageRepository repository;
  final BangumiApiClient bangumiApiClient;

  @override
  State<BangumiWorkSearchScreen> createState() =>
      BangumiWorkSearchScreenState();
}

class BangumiWorkSearchScreenState extends State<BangumiWorkSearchScreen> {
  final _queryController = TextEditingController();
  List<PilgrimageWork> _results = const [];
  Set<BangumiSubjectType> _selectedTypes = const {
    BangumiSubjectType.anime,
    BangumiSubjectType.game,
  };
  Object? _error;
  bool _isSearching = false;
  bool _isAdding = false;
  bool _didAdd = false;
  final Set<String> _addedWorkIds = {};

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty || _isSearching) {
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final results = await widget.bangumiApiClient.searchSubjects(
        query,
        types: _selectedTypes,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _results = results;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error;
        _results = const [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _addWork(PilgrimageWork work) async {
    if (_isAdding) {
      return;
    }

    setState(() {
      _isAdding = true;
    });

    try {
      await widget.repository.addWorkToPlan(planId: widget.plan.id, work: work);
      if (!mounted) {
        return;
      }

      setState(() {
        _didAdd = true;
        _addedWorkIds.add(work.id);
      });
      ScaffoldMessenger.of(
        context,
      ).showReplacingSnackBar(SnackBar(content: Text('已添加「${work.title}」。')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showReplacingSnackBar(const SnackBar(content: Text('作品添加失败，请稍后重试。')));
    } finally {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        Navigator.of(context).pop(_didAdd);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('搜索 Bangumi'),
          leading: BackButton(
            onPressed: () => Navigator.of(context).pop(_didAdd),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _FormSection(
              children: [
                TextField(
                  controller: _queryController,
                  decoration: const InputDecoration(
                    labelText: '作品名称',
                    hintText: '例如 轻音少女',
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                ),
                const SizedBox(height: 12),
                _BangumiTypeFilter(
                  selectedTypes: _selectedTypes,
                  onChanged: (types) {
                    setState(() {
                      _selectedTypes = types;
                    });
                  },
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isSearching ? null : _search,
                  icon: _isSearching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search, size: 18),
                  label: Text(_isSearching ? '搜索中' : '搜索作品'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null)
              const _MessageCard(
                icon: Icons.error_outline,
                text: 'Bangumi 搜索失败，请检查网络后重试。',
              )
            else if (_results.isEmpty)
              const _BangumiSearchHintCard()
            else
              for (final work in _results) ...[
                _WorkResultCard(
                  work: work,
                  disabled: _isAdding || _hasWork(widget.plan, work),
                  onAdd: () => _addWork(work),
                ),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }

  bool _hasWork(PilgrimagePlan plan, PilgrimageWork work) {
    return _addedWorkIds.contains(work.id) ||
        plan.works.any((candidate) => candidate.id == work.id);
  }
}

class _BangumiTypeFilter extends StatelessWidget {
  const _BangumiTypeFilter({
    required this.selectedTypes,
    required this.onChanged,
  });

  final Set<BangumiSubjectType> selectedTypes;
  final ValueChanged<Set<BangumiSubjectType>> onChanged;

  static const _types = [
    BangumiSubjectType.anime,
    BangumiSubjectType.game,
    BangumiSubjectType.book,
    BangumiSubjectType.music,
    BangumiSubjectType.real,
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final type in _types)
          FilterChip(
            label: Text(type.label),
            selected: selectedTypes.contains(type),
            onSelected: (selected) {
              final nextTypes = {...selectedTypes};
              if (selected) {
                nextTypes.add(type);
              } else if (nextTypes.length > 1) {
                nextTypes.remove(type);
              }
              onChanged(nextTypes);
            },
          ),
      ],
    );
  }
}

class _AnitabiLinkImportScreen extends StatefulWidget {
  const _AnitabiLinkImportScreen({
    required this.plan,
    required this.repository,
  });

  final PilgrimagePlan plan;
  final PilgrimageRepository repository;

  @override
  State<_AnitabiLinkImportScreen> createState() =>
      _AnitabiLinkImportScreenState();
}

class _AnitabiLinkImportScreenState extends State<_AnitabiLinkImportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _linkController = TextEditingController();

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _openImport() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      return;
    }

    final link = parseAnitabiImportLink(_linkController.text);
    if (link == null || link.bangumiId == null) {
      return;
    }
    final oldPointCount = widget.plan.points.length;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AnitabiMapImportScreen(
          plan: widget.plan,
          repository: widget.repository,
          initialBangumiId: link.bangumiId,
          initialPointId: link.pointId,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    final plans = await widget.repository.loadPlans();
    if (!mounted) {
      return;
    }
    final updatedPlan = plans.firstWhere((plan) => plan.id == widget.plan.id);
    if (updatedPlan.points.length == oldPointCount) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Anitabi 链接导入')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              '加入到：${widget.plan.name}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Anitabi 链接',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _linkController,
                    decoration: InputDecoration(
                      hintText: '粘贴 Anitabi 作品或点位链接',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.48),
                        fontSize: 14,
                        letterSpacing: 0,
                      ),
                      helperText: ' ',
                      suffixIcon: const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: IconButton(
                          onPressed: null,
                          tooltip: '粘贴',
                          icon: Icon(Icons.content_paste_outlined, size: 20),
                        ),
                      ),
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 46,
                        minHeight: 40,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppColors.accent,
                          width: 1.4,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Colors.redAccent,
                          width: 1.4,
                        ),
                      ),
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    validator: _validateLink,
                    onFieldSubmitted: (_) => _openImport(),
                  ),
                  const SizedBox(height: 8),
                  const _DashedDivider(),
                  const SizedBox(height: 16),
                  const _InfoHeading(),
                  const SizedBox(height: 8),
                  const Text(
                    '如果链接里包含作品 ID，会只加载对应作品；\n如果还包含点位 ID，会自动选中该点位。\n没有作品 ID 的链接需要先在 Anitabi 中进入对应作品后重新复制。',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _LinkExampleCard(),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openImport,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.center,
                ),
                icon: const Icon(Icons.add_location_alt_outlined, size: 21),
                label: const Text(
                  '打开 Anitabi 点位',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateLink(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return '请输入 Anitabi 链接';
    }
    final link = parseAnitabiImportLink(text);
    if (link == null) {
      return '请输入有效的 Anitabi 地图链接';
    }
    if (link.bangumiId == null) {
      return '链接缺少作品 ID，请先在 Anitabi 进入对应作品后复制链接';
    }
    return null;
  }
}

class _LinkExampleCard extends StatelessWidget {
  const _LinkExampleCard();

  static const _linkPrefix = 'https://www.anitabi.cn/map?';
  static const _bangumiId = 'bangumiId=186515';
  static const _middle = '&';
  static const _pointId = 'pid=95ff4037';
  static const _suffix = '&c=139.7226%2C35.7126&z=19.1';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '有效链接示例',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          const _ExampleLinkText(),
        ],
      ),
    );
  }
}

class _ExampleLinkText extends StatelessWidget {
  const _ExampleLinkText();

  @override
  Widget build(BuildContext context) {
    const normalStyle = TextStyle(
      color: AppColors.textSecondary,
      fontSize: 13,
      fontFamily: 'monospace',
      height: 1.25,
      letterSpacing: 0,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.start,
          runSpacing: 4,
          children: [
            const _ExamplePlainText(
              text: _LinkExampleCard._linkPrefix,
              style: normalStyle,
            ),
            _highlight(_LinkExampleCard._bangumiId),
            const _ExamplePlainText(
              text: _LinkExampleCard._middle,
              style: normalStyle,
            ),
          ],
        ),
        const SizedBox(height: 6),
        _ExampleNoteRow(normalStyle: normalStyle),
        const SizedBox(height: 6),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.start,
          runSpacing: 4,
          children: [
            _highlight(_LinkExampleCard._pointId),
            const _ExamplePlainText(
              text: _LinkExampleCard._suffix,
              style: normalStyle,
            ),
          ],
        ),
      ],
    );
  }

  static Widget _highlight(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        softWrap: false,
        style: TextStyle(
          color: AppColors.accentDark,
          fontSize: 13,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w800,
          height: 1.25,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _ExampleNoteRow extends StatelessWidget {
  const _ExampleNoteRow({required this.normalStyle});

  final TextStyle normalStyle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textDirection = Directionality.of(context);
        final bangumiLeft = _measureTextWidth(
          _LinkExampleCard._linkPrefix,
          normalStyle,
          textDirection,
        );
        final bangumiNoteWidth =
            _measureTextWidth(
              'Bangumi 作品 ID（必须）',
              _ExampleNote.textStyle,
              textDirection,
            ) +
            _ExampleNote.horizontalPadding;
        final resolvedBangumiLeft = bangumiLeft.clamp(
          0,
          (constraints.maxWidth - bangumiNoteWidth).clamp(0, double.infinity),
        );

        return SizedBox(
          height: 18,
          child: Stack(
            children: [
              const Positioned(
                left: 0,
                top: 0,
                child: _ExampleNote(text: 'Anitabi 点位 ID（可选）'),
              ),
              Positioned(
                left: resolvedBangumiLeft.toDouble(),
                top: 0,
                child: const _ExampleNote(text: 'Bangumi 作品 ID（必须）'),
              ),
            ],
          ),
        );
      },
    );
  }

  double _measureTextWidth(
    String text,
    TextStyle style,
    TextDirection textDirection,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      maxLines: 1,
    )..layout();
    return painter.width;
  }
}

class _ExamplePlainText extends StatelessWidget {
  const _ExamplePlainText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(text, softWrap: false, style: style),
    );
  }
}

class _ExampleNote extends StatelessWidget {
  const _ExampleNote({required this.text});

  static const horizontalPadding = 16.0;
  static const textStyle = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1,
    letterSpacing: 0,
  );

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: textStyle),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 6.0;
        const gapWidth = 4.0;
        final dashCount = (constraints.maxWidth / (dashWidth + gapWidth))
            .floor()
            .clamp(1, 1000);
        return Row(
          children: List.generate(
            dashCount,
            (index) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index == dashCount - 1 ? 0 : gapWidth,
                ),
                child: Container(height: 1, color: AppColors.border),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InfoHeading extends StatelessWidget {
  const _InfoHeading();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.info_outline, color: AppColors.accent, size: 15),
        const SizedBox(width: 6),
        const Text(
          '使用说明',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class ManualWorkFormScreen extends StatefulWidget {
  const ManualWorkFormScreen({
    required this.plan,
    required this.repository,
    super.key,
  });

  final PilgrimagePlan plan;
  final PilgrimageRepository repository;

  @override
  State<ManualWorkFormScreen> createState() => ManualWorkFormScreenState();
}

class ManualWorkFormScreenState extends State<ManualWorkFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _cityController = TextEditingController();
  bool _isSaving = false;
  bool _didAdd = false;

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _saveWork() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final now = DateTime.now();
      final title = _titleController.text.trim();
      final subtitle = _subtitleController.text.trim();
      final city = _cityController.text.trim();
      final work = PilgrimageWork(
        id: 'manual-work-${now.microsecondsSinceEpoch}',
        title: title,
        subtitle: subtitle.isEmpty ? 'Manual Work' : subtitle,
        city: city.isEmpty ? widget.plan.area : city,
        source: WorkSource.manual,
      );

      await widget.repository.addWorkToPlan(planId: widget.plan.id, work: work);
      if (!mounted) {
        return;
      }

      setState(() {
        _didAdd = true;
      });
      _titleController.clear();
      _subtitleController.clear();
      ScaffoldMessenger.of(
        context,
      ).showReplacingSnackBar(SnackBar(content: Text('已添加「$title」。')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showReplacingSnackBar(const SnackBar(content: Text('作品保存失败，请稍后重试。')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        Navigator.of(context).pop(_didAdd);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('手动添加作品'),
          leading: BackButton(
            onPressed: () => Navigator.of(context).pop(_didAdd),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _FormSection(
                children: [
                  _ManualWorkLabeledField(
                    label: '作品名称',
                    required: true,
                    child: TextFormField(
                      controller: _titleController,
                      decoration: _boxedFormDecoration(hintText: '请输入作品的中文名称'),
                      textInputAction: TextInputAction.next,
                      validator: _requiredText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ManualWorkLabeledField(
                    label: '作品原名',
                    child: TextFormField(
                      controller: _subtitleController,
                      decoration: _boxedFormDecoration(
                        hintText: '请输入作品的原名（如日文/英文）',
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ManualWorkLabeledField(
                    label: '主要地区',
                    child: TextFormField(
                      controller: _cityController,
                      decoration: _boxedFormDecoration(
                        hintText: '输入作品主要发生或取景的地区',
                      ),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _saveWork(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isSaving ? null : _saveWork,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_outlined, size: 18),
                label: Text(_isSaving ? '保存中' : '保存作品'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _requiredText(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return '请填写此项';
    }

    return null;
  }
}

class _ManualWorkLabeledField extends StatelessWidget {
  const _ManualWorkLabeledField({
    required this.label,
    required this.child,
    this.required = false,
    this.prominent = false,
  });

  final String label;
  final Widget child;
  final bool required;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: label),
              if (required)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.redAccent),
                ),
            ],
          ),
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: prominent ? 15 : 13,
            fontWeight: prominent ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _ManualPointFormScreen extends StatefulWidget {
  const _ManualPointFormScreen({
    required this.plan,
    required this.repository,
    this.editingPoint,
  });

  final PilgrimagePlan plan;
  final PilgrimageRepository repository;
  final PilgrimagePoint? editingPoint;

  @override
  State<_ManualPointFormScreen> createState() => _ManualPointFormScreenState();
}

class EditPointScreen {
  const EditPointScreen._();

  static Future<bool?> open(
    BuildContext context, {
    required PilgrimagePlan plan,
    required PilgrimageRepository repository,
    required PilgrimagePoint point,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _ManualPointFormScreen(
          plan: plan,
          repository: repository,
          editingPoint: point,
        ),
      ),
    );
  }
}

class _ManualPointFormScreenState extends State<_ManualPointFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  final _fallbackWorkTitleController = TextEditingController();
  final _fallbackWorkSubtitleController = TextEditingController();
  final _fallbackWorkCityController = TextEditingController();
  final _nameController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _episodeController = TextEditingController();
  final _referenceController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _latitudeFocusNode = FocusNode();
  final _longitudeFocusNode = FocusNode();
  final _noteController = TextEditingController();
  PilgrimageWork? _selectedWork;
  StoredUserReferenceImage? _pendingReferenceImage;
  bool _isSaving = false;
  bool _didCommitPendingReference = false;

  PilgrimagePoint? get _editingPoint => widget.editingPoint;

  bool get _isEditing => _editingPoint != null;

  List<PilgrimageWork> get _workOptions {
    final works = [...widget.plan.works];
    final selectedWork = _selectedWork;
    if (selectedWork != null &&
        !works.any((work) => work.id == selectedWork.id)) {
      works.add(selectedWork);
    }
    return works;
  }

  @override
  void initState() {
    super.initState();
    final editingPoint = _editingPoint;
    _selectedWork = editingPoint == null
        ? widget.plan.works.firstOrNull
        : widget.plan.works.firstWhere(
            (work) => work.id == editingPoint.work.id,
            orElse: () => editingPoint.work,
          );
    if (editingPoint != null) {
      _nameController.text = editingPoint.name;
      _subtitleController.text = editingPoint.subtitle;
      _episodeController.text = editingPoint.episodeLabel;
      _referenceController.text = editingPoint.referenceLabel;
      _latitudeController.text = editingPoint.position.latitude.toStringAsFixed(
        6,
      );
      _longitudeController.text = editingPoint.position.longitude
          .toStringAsFixed(6);
      _noteController.text = editingPoint.note ?? '';
    }
  }

  @override
  void dispose() {
    if (!_didCommitPendingReference) {
      unawaited(deleteStoredUserReferenceImage(_pendingReferenceImage));
    }
    _fallbackWorkTitleController.dispose();
    _fallbackWorkSubtitleController.dispose();
    _fallbackWorkCityController.dispose();
    _nameController.dispose();
    _subtitleController.dispose();
    _episodeController.dispose();
    _referenceController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _latitudeFocusNode.dispose();
    _longitudeFocusNode.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _savePoint() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final now = DateTime.now();
      final editingPoint = _editingPoint;
      final work = _selectedWork ?? _fallbackWork(now);
      final pointId =
          editingPoint?.id ?? 'manual-${now.microsecondsSinceEpoch}';
      final storedReference = _pendingReferenceImage;
      final position = LatLng(
        double.parse(_latitudeController.text.trim()),
        double.parse(_longitudeController.text.trim()),
      );
      final noteText = _noteController.text.trim();
      final point = editingPoint == null
          ? PilgrimagePoint(
              id: pointId,
              work: work,
              name: _nameController.text.trim(),
              subtitle: _subtitleController.text.trim(),
              position: position,
              episodeLabel: _episodeController.text.trim(),
              referenceLabel: _referenceController.text.trim(),
              referenceThumbnailPath: storedReference?.thumbnailPath,
              referenceFullImagePath: storedReference?.fullImagePath,
              note: noteText.isEmpty ? null : noteText,
            )
          : editingPoint.copyWith(
              work: work,
              name: _nameController.text.trim(),
              subtitle: _subtitleController.text.trim(),
              position: position,
              episodeLabel: _episodeController.text.trim(),
              referenceLabel: _referenceController.text.trim(),
              referenceThumbnailPath:
                  storedReference?.thumbnailPath ??
                  editingPoint.referenceThumbnailPath,
              referenceFullImagePath:
                  storedReference?.fullImagePath ??
                  editingPoint.referenceFullImagePath,
              referenceImageUrl: storedReference == null
                  ? editingPoint.referenceImageUrl
                  : null,
              note: noteText.isEmpty ? null : noteText,
            );

      if (editingPoint == null) {
        await widget.repository.addPointToPlan(
          planId: widget.plan.id,
          point: point,
        );
      } else {
        await widget.repository.updatePointInPlan(
          planId: widget.plan.id,
          point: point,
        );
      }
      if (!mounted) {
        return;
      }

      _didCommitPendingReference = true;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showReplacingSnackBar(const SnackBar(content: Text('点位保存失败，请稍后重试。')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  PilgrimageWork _fallbackWork(DateTime now) {
    final title = _fallbackWorkTitleController.text.trim();
    final subtitle = _fallbackWorkSubtitleController.text.trim();
    final city = _fallbackWorkCityController.text.trim();
    return PilgrimageWork(
      id: 'manual-work-${now.microsecondsSinceEpoch}',
      title: title,
      subtitle: subtitle.isEmpty ? 'Manual Work' : subtitle,
      city: city.isEmpty ? widget.plan.area : city,
      source: WorkSource.manual,
    );
  }

  Future<void> _pickReferenceImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) {
      return;
    }

    final editingPoint = _editingPoint;
    final pointId =
        editingPoint?.id ?? 'manual-${DateTime.now().microsecondsSinceEpoch}';
    final stored = await storeUserReferenceImage(
      sourcePath: picked.path,
      pointId: pointId,
    );
    if (stored == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showReplacingSnackBar(const SnackBar(content: Text('参考图读取失败，请重新选择。')));
      return;
    }

    await deleteStoredUserReferenceImage(_pendingReferenceImage);
    if (!mounted) {
      await deleteStoredUserReferenceImage(stored);
      return;
    }

    setState(() {
      _pendingReferenceImage = stored;
      _didCommitPendingReference = false;
    });
  }

  Future<void> _pickCoordinateFromMap() async {
    final settings = await widget.repository.loadAppSettings();
    if (!mounted) {
      return;
    }

    final initialPosition = _currentPositionInput() ?? _planCenter;
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute<LatLng>(
        builder: (_) => _ManualPointMapPickerScreen(
          initialPosition: initialPosition,
          settings: settings,
        ),
      ),
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _latitudeController.text = picked.latitude.toStringAsFixed(6);
      _longitudeController.text = picked.longitude.toStringAsFixed(6);
    });
  }

  Future<void> _pasteCoordinateFromClipboard() async {
    String clipboardText = '';
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      clipboardText = data?.text ?? '';
    } on Object {
      clipboardText = '';
    }

    var coordinate = parseCoordinateText(clipboardText);
    if (coordinate == null && mounted) {
      final manualText = await _showCoordinatePasteDialog();
      if (!mounted || manualText == null) {
        return;
      }
      coordinate = parseCoordinateText(manualText);
    }

    if (!mounted) {
      return;
    }
    if (coordinate == null) {
      ScaffoldMessenger.of(
        context,
      ).showReplacingSnackBar(const SnackBar(content: Text('剪切板中没有可识别的坐标。')));
      return;
    }
    final parsedCoordinate = coordinate;

    setState(() {
      _latitudeController.text = parsedCoordinate.latitude.toStringAsFixed(6);
      _longitudeController.text = parsedCoordinate.longitude.toStringAsFixed(6);
    });
    ScaffoldMessenger.of(
      context,
    ).showReplacingSnackBar(const SnackBar(content: Text('已填入坐标。')));
  }

  Future<String?> _showCoordinatePasteDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('粘贴坐标'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              minLines: 2,
              maxLines: 3,
              decoration: stableInputDecoration(
                labelText: '坐标文本',
                hintText: '例如 35.712576, 139.722166',
              ),
              validator: (value) {
                if (parseCoordinateText(value ?? '') == null) {
                  return '请输入可识别的坐标';
                }
                return null;
              },
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogContext).pop(controller.text);
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogContext).pop(controller.text);
                }
              },
              child: const Text('填入'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  void _removeReferenceImage() {
    unawaited(deleteStoredUserReferenceImage(_pendingReferenceImage));
    setState(() {
      _pendingReferenceImage = null;
      _didCommitPendingReference = false;
    });
  }

  LatLng? _currentPositionInput() {
    final latitude = double.tryParse(_latitudeController.text.trim());
    final longitude = double.tryParse(_longitudeController.text.trim());
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    return LatLng(latitude, longitude);
  }

  LatLng get _planCenter {
    if (widget.plan.points.isEmpty) {
      return const LatLng(35, 135);
    }
    final latitude =
        widget.plan.points
            .map((point) => point.position.latitude)
            .reduce((a, b) => a + b) /
        widget.plan.points.length;
    final longitude =
        widget.plan.points
            .map((point) => point.position.longitude)
            .reduce((a, b) => a + b) /
        widget.plan.points.length;
    return LatLng(latitude, longitude);
  }

  @override
  Widget build(BuildContext context) {
    final workOptions = _workOptions;
    final hasPlanWorks = workOptions.isNotEmpty;
    final editingPoint = _editingPoint;
    final existingReferenceImageUrl =
        editingPoint != null && hasRemoteReferenceImage(editingPoint)
        ? editingPoint.referenceImageUrl
        : null;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_didCommitPendingReference) {
          unawaited(deleteStoredUserReferenceImage(_pendingReferenceImage));
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? '编辑点位' : '手动添加点位'),
          leading: BackButton(
            onPressed: () {
              if (!_didCommitPendingReference) {
                unawaited(
                  deleteStoredUserReferenceImage(_pendingReferenceImage),
                );
              }
              Navigator.of(context).pop(false);
            },
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                _isEditing
                    ? '修改：${editingPoint!.name}'
                    : '加入到：${widget.plan.name}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 12),
              _FormSection(
                children: [
                  if (hasPlanWorks)
                    _ManualWorkLabeledField(
                      label: '所属作品',
                      required: true,
                      prominent: true,
                      child: PilgrimageWorkDropdown(
                        works: workOptions,
                        value: _selectedWork,
                        onChanged: (work) {
                          setState(() {
                            _selectedWork = work;
                          });
                        },
                        validator: (work) => work == null ? '请选择作品' : null,
                      ),
                    )
                  else ...[
                    _ManualWorkLabeledField(
                      label: '作品名称',
                      required: true,
                      prominent: true,
                      child: TextFormField(
                        controller: _fallbackWorkTitleController,
                        decoration: _boxedFormDecoration(
                          hintText: '请输入作品的中文名称',
                        ),
                        textInputAction: TextInputAction.next,
                        validator: _requiredText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ManualWorkLabeledField(
                      label: '作品原名',
                      prominent: true,
                      child: TextFormField(
                        controller: _fallbackWorkSubtitleController,
                        decoration: _boxedFormDecoration(
                          hintText: '请输入作品的原名（如日文/英文）',
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ManualWorkLabeledField(
                      label: '主要地区',
                      prominent: true,
                      child: TextFormField(
                        controller: _fallbackWorkCityController,
                        decoration: _boxedFormDecoration(
                          hintText: '输入作品主要发生或取景的地区',
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              _FormSection(
                children: [
                  _ManualWorkLabeledField(
                    label: '点位名称',
                    required: true,
                    prominent: true,
                    child: TextFormField(
                      controller: _nameController,
                      decoration: _boxedFormDecoration(hintText: '请输入点位名称'),
                      textInputAction: TextInputAction.next,
                      validator: _requiredText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ManualWorkLabeledField(
                    label: '位置说明',
                    required: true,
                    prominent: true,
                    child: TextFormField(
                      controller: _subtitleController,
                      decoration: _boxedFormDecoration(hintText: '请输入位置说明'),
                      textInputAction: TextInputAction.next,
                      validator: _requiredText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ManualWorkLabeledField(
                    label: '集数/场景标签',
                    required: true,
                    prominent: true,
                    child: TextFormField(
                      controller: _episodeController,
                      decoration: _boxedFormDecoration(hintText: '请输入集数或场景标签'),
                      textInputAction: TextInputAction.next,
                      validator: _requiredText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ManualWorkLabeledField(
                    label: '参考来源',
                    required: true,
                    prominent: true,
                    child: TextFormField(
                      controller: _referenceController,
                      decoration: _boxedFormDecoration(hintText: '请输入参考来源'),
                      textInputAction: TextInputAction.next,
                      validator: _requiredText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ManualWorkLabeledField(
                    label: '备注',
                    prominent: true,
                    child: TextFormField(
                      controller: _noteController,
                      decoration: _boxedFormDecoration(
                        hintText: '可选，填写闭店、翻修或拍摄建议等补充信息',
                      ),
                      minLines: 4,
                      maxLines: 8,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      textAlignVertical: TextAlignVertical.top,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _FormSection(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '坐标位置',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _CoordinateLabeledField(
                          label: '纬度',
                          focusNode: _latitudeFocusNode,
                          child: TextFormField(
                            controller: _latitudeController,
                            focusNode: _latitudeFocusNode,
                            decoration: _coordinateInputDecoration(
                              hintText: '例如 34.8917',
                            ),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            textInputAction: TextInputAction.next,
                            validator: _validateLatitude,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CoordinateLabeledField(
                          label: '经度',
                          focusNode: _longitudeFocusNode,
                          child: TextFormField(
                            controller: _longitudeController,
                            focusNode: _longitudeFocusNode,
                            decoration: _coordinateInputDecoration(
                              hintText: '例如 135.8077',
                            ),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            textInputAction: TextInputAction.done,
                            validator: _validateLongitude,
                            onFieldSubmitted: (_) => _savePoint(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSaving ? null : _pickCoordinateFromMap,
                          style: OutlinedButton.styleFrom(
                            fixedSize: const Size.fromHeight(40),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            foregroundColor: AppColors.accent,
                            backgroundColor: AppColors.accent.withValues(
                              alpha: 0.06,
                            ),
                            side: BorderSide(
                              color: AppColors.accent.withValues(alpha: 0.35),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.location_on, size: 19),
                          label: const Text(
                            '从地图选择',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 44,
                        height: 40,
                        child: IconButton.outlined(
                          tooltip: '粘贴剪切板坐标',
                          onPressed: _isSaving
                              ? null
                              : _pasteCoordinateFromClipboard,
                          style: IconButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.content_paste_outlined),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ManualReferenceImagePicker(
                localPath:
                    _pendingReferenceImage?.thumbnailPath ??
                    editingPoint?.referenceThumbnailPath ??
                    editingPoint?.referenceFullImagePath,
                fullImagePath:
                    _pendingReferenceImage?.fullImagePath ??
                    editingPoint?.referenceFullImagePath,
                imageUrl: _pendingReferenceImage == null
                    ? existingReferenceImageUrl
                    : null,
                hasPendingSelection: _pendingReferenceImage != null,
                hasExistingImage:
                    editingPoint?.referenceThumbnailPath != null ||
                    editingPoint?.referenceFullImagePath != null ||
                    existingReferenceImageUrl != null,
                onPick: _isSaving ? null : _pickReferenceImage,
                onRemove: _isSaving || _pendingReferenceImage == null
                    ? null
                    : _removeReferenceImage,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isSaving ? null : _savePoint,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_outlined, size: 18),
                label: Text(_isSaving ? '保存中' : (_isEditing ? '保存修改' : '保存点位')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _requiredText(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return '请填写此项';
    }

    return null;
  }

  InputDecoration _coordinateInputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: AppColors.textSecondary.withValues(alpha: 0.42),
        fontSize: 13,
        letterSpacing: 0,
      ),
      isDense: true,
      contentPadding: EdgeInsets.zero,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      errorStyle: const TextStyle(fontSize: 11, height: 0.9),
    );
  }

  String? _validateLatitude(String? value) {
    return _validateCoordinate(value, min: -90, max: 90, emptyMessage: '请填写纬度');
  }

  String? _validateLongitude(String? value) {
    return _validateCoordinate(
      value,
      min: -180,
      max: 180,
      emptyMessage: '请填写经度',
    );
  }

  String? _validateCoordinate(
    String? value, {
    required double min,
    required double max,
    required String emptyMessage,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return emptyMessage;
    }

    final coordinate = double.tryParse(text);
    if (coordinate == null || coordinate < min || coordinate > max) {
      return '请输入有效坐标';
    }

    return null;
  }
}

class _CoordinateLabeledField extends StatelessWidget {
  const _CoordinateLabeledField({
    required this.label,
    required this.focusNode,
    required this.child,
  });

  final String label;
  final FocusNode focusNode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, child) {
        final focused = focusNode.hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(
              color: focused ? AppColors.accent : AppColors.border,
              width: 1.4,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: label),
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              child!,
            ],
          ),
        );
      },
      child: child,
    );
  }
}

class _ManualPointMapPickerScreen extends StatefulWidget {
  const _ManualPointMapPickerScreen({
    required this.initialPosition,
    required this.settings,
  });

  final LatLng initialPosition;
  final AppSettings settings;

  @override
  State<_ManualPointMapPickerScreen> createState() =>
      _ManualPointMapPickerScreenState();
}

class _ManualPointMapPickerScreenState
    extends State<_ManualPointMapPickerScreen> {
  final MapController _mapController = MapController();
  LatLng? _selectedPosition;
  var _isPickMode = false;

  @override
  Widget build(BuildContext context) {
    final selectedPosition = _selectedPosition;

    return Scaffold(
      appBar: AppBar(title: const Text('选择点位坐标')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialPosition,
              initialZoom: 15,
              minZoom: 4,
              maxZoom: 24,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (_, latLng) {
                if (!_isPickMode) {
                  return;
                }
                setState(() {
                  _selectedPosition = latLng;
                });
              },
            ),
            children: [
              configuredMapTileLayer(widget.settings),
              MarkerLayer(
                markers: [
                  if (selectedPosition != null)
                    Marker(
                      point: selectedPosition,
                      width: 48,
                      height: 48,
                      child: const _ManualPointPositionMarker(),
                    ),
                ],
              ),
              configuredMapAttribution(widget.settings),
            ],
          ),
          if (_isPickMode)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (details) {
                  setState(() {
                    _selectedPosition = _mapController.camera.offsetToCrs(
                      details.localPosition,
                    );
                  });
                },
              ),
            ),
          Positioned(
            right: 12,
            top: 12,
            child: SafeArea(
              bottom: false,
              child: _MapToolButton(
                tooltip: _isPickMode ? '关闭地图选点' : '在地图上选点',
                icon: Icons.ads_click_outlined,
                selected: _isPickMode,
                onTap: () {
                  setState(() {
                    _isPickMode = !_isPickMode;
                  });
                },
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _ManualPointSelectionCard(
              position: selectedPosition,
              pickMode: _isPickMode,
              onSave: selectedPosition == null
                  ? null
                  : () => Navigator.of(context).pop(selectedPosition),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualPointPositionMarker extends StatelessWidget {
  const _ManualPointPositionMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: const Icon(Icons.add_location_alt, color: Colors.white),
    );
  }
}

class _MapToolButton extends StatelessWidget {
  const _MapToolButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    required this.selected,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accent : AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon),
        color: selected ? Colors.white : AppColors.textPrimary,
      ),
    );
  }
}

class _ManualPointSelectionCard extends StatelessWidget {
  const _ManualPointSelectionCard({
    required this.position,
    required this.pickMode,
    required this.onSave,
  });

  final LatLng? position;
  final bool pickMode;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final position = this.position;
    final subtitle = position == null
        ? (pickMode ? '点击地图任意位置设置点位坐标' : '先点击右上角选点按钮，再点击地图设置坐标')
        : '点击地图可继续调整位置\n${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.add_location_alt_outlined, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '地图选点',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: onSave, child: const Text('使用')),
        ],
      ),
    );
  }
}

class _WorkSummary extends StatelessWidget {
  const _WorkSummary({required this.plan});

  final PilgrimagePlan? plan;

  @override
  Widget build(BuildContext context) {
    final works = plan?.works ?? const <PilgrimageWork>[];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.movie_filter_outlined, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              works.isEmpty
                  ? '当前计划还没有作品。先添加作品，后续可按作品导入点位。'
                  : '当前计划已有 ${works.length} 部作品：${works.map((work) => work.title).join('、')}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualReferenceImagePicker extends StatelessWidget {
  const _ManualReferenceImagePicker({
    required this.localPath,
    required this.fullImagePath,
    required this.imageUrl,
    required this.hasPendingSelection,
    required this.hasExistingImage,
    required this.onPick,
    required this.onRemove,
  });

  final String? localPath;
  final String? fullImagePath;
  final String? imageUrl;
  final bool hasPendingSelection;
  final bool hasExistingImage;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final hasImage = hasPendingSelection || hasExistingImage;
    final previewPath = fullImagePath ?? (imageUrl == null ? localPath : null);
    final canPreview = previewPath != null || imageUrl != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Tooltip(
              message: canPreview ? '查看大图' : '暂无参考图',
              child: GestureDetector(
                onTap: canPreview
                    ? () => ImageViewerScreen.show(
                        context,
                        filePath: previewPath,
                        imageUrl: imageUrl,
                      )
                    : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 104,
                    color: AppColors.surfaceMuted,
                    child: ReferenceThumbnail(
                      localPath: localPath,
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: const Icon(
                        Icons.image_outlined,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '参考图片',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasPendingSelection
                        ? '已选择新图片，保存后生效。'
                        : hasExistingImage
                        ? '当前参考图，重新选择后需保存才会生效。'
                        : '可选，保存时会复制到 App 本地目录。',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onPick,
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          size: 18,
                        ),
                        label: Text(hasImage ? '重新选择' : '上传参考图'),
                      ),
                      if (hasPendingSelection)
                        TextButton.icon(
                          onPressed: onRemove,
                          icon: const Icon(Icons.close_outlined, size: 18),
                          label: const Text('移除'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkResultCard extends StatefulWidget {
  const _WorkResultCard({
    required this.work,
    required this.disabled,
    required this.onAdd,
  });

  final PilgrimageWork work;
  final bool disabled;
  final VoidCallback onAdd;

  @override
  State<_WorkResultCard> createState() => _WorkResultCardState();
}

class _WorkResultCardState extends State<_WorkResultCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final work = widget.work;
    final bangumiId = work.bangumiId;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            _iconForType(work.displayBangumiSubjectType),
            color: AppColors.accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  work.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (work.displayBangumiSubjectType != null)
                      _SubjectTypePill(type: work.displayBangumiSubjectType!),
                    if (bangumiId != null)
                      _InfoPill(label: 'Bangumi #$bangumiId'),
                  ],
                ),
                const SizedBox(height: 5),
                InkWell(
                  onTap: () {
                    setState(() {
                      _expanded = !_expanded;
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      work.subtitle,
                      maxLines: _expanded ? null : 1,
                      overflow: _expanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: widget.disabled ? null : widget.onAdd,
            child: Text(widget.disabled ? '已添加' : '加入'),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(BangumiSubjectType? type) {
    return switch (type) {
      BangumiSubjectType.book => Icons.menu_book_outlined,
      BangumiSubjectType.anime => Icons.movie_filter_outlined,
      BangumiSubjectType.music => Icons.music_note_outlined,
      BangumiSubjectType.game => Icons.sports_esports_outlined,
      BangumiSubjectType.real => Icons.live_tv_outlined,
      null => Icons.movie_filter_outlined,
    };
  }
}

class _SubjectTypePill extends StatelessWidget {
  const _SubjectTypePill({required this.type});

  final BangumiSubjectType type;

  @override
  Widget build(BuildContext context) {
    return _InfoPill(label: type.label);
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BangumiSearchHintCard extends StatelessWidget {
  const _BangumiSearchHintCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, color: AppColors.accent, size: 16),
              const SizedBox(width: 8),
              const Text(
                '温馨提示',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '输入作品名后搜索，选择结果即可加入当前计划。',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.35,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Bangumi需要国际网络环境才能正常搜索。',
              style: TextStyle(
                color: AppColors.accentDark,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.25,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _AddSourceCard extends StatelessWidget {
  const _AddSourceCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.enabled,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool enabled;
  final String actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: enabled ? AppColors.accent : AppColors.textSecondary,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                actionLabel,
                style: TextStyle(
                  color: enabled
                      ? AppColors.accentDark
                      : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
