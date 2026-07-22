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
import '../widgets/app_scaled_route.dart';
import 'anitabi_map_import_screen.dart';
import 'coordinate_parser.dart';
import 'pilgrimage_work_dropdown.dart';
import 'pilgrimage_models.dart';
import 'pilgrimage_work_cover.dart';
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

InputDecoration _boxedFormDecoration({
  String? hintText,
  bool reserveHelperSpace = true,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(
      color: AppColors.textSecondary.withValues(alpha: 0.42),
      fontSize: 14,
      letterSpacing: 0,
    ),
    helperText: reserveHelperSpace ? ' ' : null,
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

InputDecoration _workTypeDropdownDecoration() {
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: AppColors.surface,
    hoverColor: AppColors.accent.withValues(alpha: 0.035),
    helperText: ' ',
    contentPadding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.border, width: 1.4),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.accent, width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
    ),
  );
}

const _manualWorkSubjectTypes = [
  BangumiSubjectType.anime,
  BangumiSubjectType.game,
  BangumiSubjectType.book,
  BangumiSubjectType.music,
  BangumiSubjectType.real,
];

class AddPointsScreen extends StatefulWidget {
  AddPointsScreen({
    required this.plan,
    required this.repository,
    required this.settings,
    BangumiApiClient? bangumiApiClient,
    super.key,
  }) : bangumiApiClient = bangumiApiClient ?? BangumiApiClient();

  final PilgrimagePlan? plan;
  final PilgrimageRepository repository;
  final AppSettings settings;
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
    final hasBangumiWork =
        currentPlan?.works.any((work) => work.bangumiId != null) ?? false;

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
            _LinkedWorksPanel(
              plan: currentPlan,
              onManage: currentPlan == null
                  ? null
                  : () => _openWorkManager(context, currentPlan),
              onBangumi: currentPlan == null
                  ? null
                  : () => _openBangumiSearch(context, currentPlan),
              onManual: currentPlan == null
                  ? null
                  : () => _openManualWorkForm(context, currentPlan),
            ),
            const SizedBox(height: 12),
            _QuickImportPanel(
              enabled: currentPlan != null,
              onTap: currentPlan == null
                  ? null
                  : () => _openAnitabiLinkImport(context, currentPlan),
            ),
            const SizedBox(height: 12),
            _AddPointPanel(
              mapEnabled:
                  currentPlan != null &&
                  (currentPlan.points.isNotEmpty || hasBangumiWork),
              manualEnabled: currentPlan != null,
              onMap:
                  currentPlan == null ||
                      (currentPlan.points.isEmpty && !hasBangumiWork)
                  ? null
                  : () => _openAnitabiMapImport(context, currentPlan),
              onManual: currentPlan == null
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
      appScaledMaterialPageRoute<bool>(
        settings: widget.settings,
        builder: (_) => WorkManagerScreen(
          plan: plan,
          repository: widget.repository,
          settings: widget.settings,
          bangumiApiClient: widget.bangumiApiClient,
        ),
      ),
    );
    if (!context.mounted) {
      return;
    }

    await _reloadPlan(plan.id);
  }

  Future<void> _openBangumiSearch(
    BuildContext context,
    PilgrimagePlan plan,
  ) async {
    await Navigator.of(context).push<bool>(
      appScaledMaterialPageRoute<bool>(
        settings: widget.settings,
        builder: (_) => BangumiWorkSearchScreen(
          plan: plan,
          repository: widget.repository,
          bangumiApiClient: widget.bangumiApiClient,
        ),
      ),
    );
    if (context.mounted) {
      await _reloadPlan(plan.id);
    }
  }

  Future<void> _openManualWorkForm(
    BuildContext context,
    PilgrimagePlan plan,
  ) async {
    await Navigator.of(context).push<bool>(
      appScaledMaterialPageRoute<bool>(
        settings: widget.settings,
        builder: (_) => ManualWorkFormScreen(
          plan: plan,
          repository: widget.repository,
          settings: widget.settings,
        ),
      ),
    );
    if (context.mounted) {
      await _reloadPlan(plan.id);
    }
  }

  Future<void> _openAnitabiMapImport(
    BuildContext context,
    PilgrimagePlan plan,
  ) async {
    await Navigator.of(context).push<bool>(
      appScaledMaterialPageRoute<bool>(
        settings: widget.settings,
        builder: (_) => AnitabiMapImportScreen(
          plan: plan,
          repository: widget.repository,
          initialSettings: widget.settings,
        ),
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
      appScaledMaterialPageRoute<bool>(
        settings: widget.settings,
        builder: (_) => _AnitabiLinkImportScreen(
          plan: plan,
          repository: widget.repository,
          settings: widget.settings,
        ),
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
      appScaledMaterialPageRoute<bool>(
        settings: widget.settings,
        builder: (_) => _ManualPointFormScreen(
          plan: plan,
          repository: widget.repository,
          settings: widget.settings,
        ),
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
  bool _isTypeFilterExpanded = true;
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
      _isTypeFilterExpanded = false;
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
                _ManualWorkLabeledField(
                  label: '作品名称',
                  prominent: true,
                  child: TextField(
                    controller: _queryController,
                    decoration: _boxedFormDecoration(
                      hintText: '例如：轻音少女',
                      reserveHelperSpace: false,
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSearching ? null : _search,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    icon: _isSearching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search, size: 18),
                    label: Text(_isSearching ? '搜索中' : '搜索作品'),
                  ),
                ),
                const SizedBox(height: 12),
                _BangumiTypeFilterDisclosure(
                  expanded: _isTypeFilterExpanded,
                  selectedTypes: _selectedTypes,
                  onToggle: () {
                    setState(() {
                      _isTypeFilterExpanded = !_isTypeFilterExpanded;
                    });
                  },
                  onChanged: (types) {
                    setState(() {
                      _selectedTypes = types;
                    });
                  },
                ),
                if (_results.isEmpty && _error == null) ...[
                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    color: AppColors.border.withValues(alpha: 0.65),
                  ),
                  const SizedBox(height: 12),
                  const _BangumiSearchHintContent(),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null)
              const _MessageCard(
                icon: Icons.error_outline,
                text: 'Bangumi 搜索失败，请检查网络后重试。',
              )
            else if (_results.isNotEmpty)
              for (final work in _results) ...[
                _WorkResultCard(
                  work: work,
                  added: _hasWork(widget.plan, work),
                  disabled: _isAdding,
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
    return Container(
      width: double.infinity,
      height: 40,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < _types.length; index++) ...[
            Expanded(child: _buildTypeItem(_types[index])),
            if (index < _types.length - 1)
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.border,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeItem(BangumiSubjectType type) {
    final selected = selectedTypes.contains(type);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleType(type, selected),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                color: selected
                    ? AppColors.accent.withValues(alpha: 0.08)
                    : Colors.transparent,
                alignment: Alignment.center,
                child: Text(
                  type.label,
                  maxLines: 1,
                  style: TextStyle(
                    color: selected
                        ? AppColors.accentDark
                        : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 0,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleType(BangumiSubjectType type, bool selected) {
    final nextTypes = {...selectedTypes};
    if (selected) {
      if (nextTypes.length == 1) {
        return;
      }
      nextTypes.remove(type);
    } else {
      nextTypes.add(type);
    }
    onChanged(nextTypes);
  }
}

class _BangumiTypeFilterDisclosure extends StatelessWidget {
  const _BangumiTypeFilterDisclosure({
    required this.expanded,
    required this.selectedTypes,
    required this.onToggle,
    required this.onChanged,
  });

  final bool expanded;
  final Set<BangumiSubjectType> selectedTypes;
  final VoidCallback onToggle;
  final ValueChanged<Set<BangumiSubjectType>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              child: SizedBox(
                height: 42,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '筛选作品类型',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      Text(
                        '已选 ${selectedTypes.length} 项',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 160),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: _BangumiTypeFilter(
                      selectedTypes: selectedTypes,
                      onChanged: onChanged,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _AnitabiLinkImportScreen extends StatefulWidget {
  const _AnitabiLinkImportScreen({
    required this.plan,
    required this.repository,
    required this.settings,
  });

  final PilgrimagePlan plan;
  final PilgrimageRepository repository;
  final AppSettings settings;

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
      appScaledMaterialPageRoute<bool>(
        settings: widget.settings,
        builder: (_) => AnitabiMapImportScreen(
          plan: widget.plan,
          repository: widget.repository,
          initialSettings: widget.settings,
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

  Future<void> _pasteLinkFromClipboard() async {
    ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showReplacingSnackBar(
          const SnackBar(content: Text('无法读取剪贴板，请手动粘贴 Anitabi 链接。')),
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showReplacingSnackBar(
        const SnackBar(content: Text('剪贴板中没有可用的 Anitabi 链接。')),
      );
      return;
    }
    _linkController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _formKey.currentState?.validate();
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
                      suffixIcon: Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: IconButton(
                          onPressed: _pasteLinkFromClipboard,
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
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _openImport,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        alignment: Alignment.center,
                      ),
                      icon: const Icon(
                        Icons.add_location_alt_outlined,
                        size: 21,
                      ),
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
            const SizedBox(height: 18),
            const _LinkExampleCard(),
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
          const SizedBox(height: 12),
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

class ManualWorkFormScreen extends StatefulWidget {
  const ManualWorkFormScreen({
    required this.plan,
    required this.repository,
    required this.settings,
    super.key,
  });

  final PilgrimagePlan plan;
  final PilgrimageRepository repository;
  final AppSettings settings;

  @override
  State<ManualWorkFormScreen> createState() => ManualWorkFormScreenState();
}

class ManualWorkFormScreenState extends State<ManualWorkFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _cityController = TextEditingController();
  BangumiSubjectType _selectedSubjectType = BangumiSubjectType.anime;
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
        subtitle: subtitle.isEmpty ? '暂无作品原名' : subtitle,
        city: city.isEmpty ? widget.plan.area : city,
        source: WorkSource.manual,
        bangumiSubjectType: _selectedSubjectType,
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
      _cityController.clear();
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

  Future<void> _showFillingGuide() {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: AppScaledOverlayContent(
          settings: widget.settings,
          child: const _ManualWorkFillingGuideSheet(),
        ),
      ),
    );
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
          actions: [
            TextButton.icon(
              key: const ValueKey('manual-work-filling-guide'),
              onPressed: _showFillingGuide,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentDark,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              icon: const Icon(Icons.menu_book_outlined, size: 17),
              label: const Text(
                '填写指南',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
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
                    label: '作品类型',
                    required: true,
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        focusColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        highlightColor: AppColors.accent.withValues(
                          alpha: 0.075,
                        ),
                        splashColor: Colors.transparent,
                      ),
                      child: DropdownButtonFormField<BangumiSubjectType>(
                        key: ValueKey(_selectedSubjectType),
                        initialValue: _selectedSubjectType,
                        decoration: _workTypeDropdownDecoration(),
                        isExpanded: true,
                        elevation: 2,
                        borderRadius: BorderRadius.circular(8),
                        dropdownColor: AppColors.surface,
                        itemHeight: null,
                        menuMaxHeight: appScaledOverlayExtent(
                          widget.settings,
                          360,
                        ),
                        icon: const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                          ),
                        ),
                        selectedItemBuilder: (context) => [
                          for (final type in _manualWorkSubjectTypes)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(type.label),
                            ),
                        ],
                        items: [
                          for (final type in _manualWorkSubjectTypes)
                            DropdownMenuItem<BangumiSubjectType>(
                              value: type,
                              child: SizedBox(
                                height: appScaledOverlayExtent(
                                  widget.settings,
                                  48,
                                ),
                                child: AppScaledOverlayContent(
                                  settings: widget.settings,
                                  child: _ManualWorkTypeDropdownItem(
                                    type: type,
                                    selected: type == _selectedSubjectType,
                                  ),
                                ),
                              ),
                            ),
                        ],
                        onChanged: _isSaving
                            ? null
                            : (type) {
                                if (type == null) {
                                  return;
                                }
                                setState(() {
                                  _selectedSubjectType = type;
                                });
                              },
                      ),
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

class _ManualPointFillingGuideSheet extends StatelessWidget {
  const _ManualPointFillingGuideSheet();

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;

    return ConstrainedBox(
      key: const ValueKey('manual-point-guide-panel'),
      constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.add_location_alt_outlined,
                  color: AppColors.accentDark,
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '点位填写指南',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '重点记录现场可识别的信息，方便到达后快速确认位置、场景和拍摄条件。',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 18),
            const _FillingGuideItem(
              index: 1,
              title: '所属作品',
              badge: '必填',
              body: '选择点位对应的作品。计划中还没有作品时，先填写作品名称、原名和主要地区。',
              example: '轻音少女',
            ),
            const _FillingGuideItem(
              index: 2,
              title: '名称与位置说明',
              badge: '必填',
              body: '名称优先填写中文常用名；位置说明优先填写当地原语言的地标、建筑或店铺名称，方便现场核对。',
              example: '东京国际会展中心 / 東京ビッグサイト',
            ),
            const _FillingGuideItem(
              index: 3,
              title: '场景标签与参考来源',
              badge: '必填',
              body: '场景标签只写集数、时间点或场景编号；参考来源填写该点位原来所在的平台，或原始上传者。',
              example: 'EP 1 / 12:32\n示例：小红书@BilyHurington / Bilibili@麦块晓天',
            ),
            const _FillingGuideItem(
              index: 4,
              title: '备注',
              badge: '选填',
              body: '记录营业时间、闭店翻修、拍摄限制、推荐机位或其他到访前需要知道的信息。',
              example: '2025年完成翻修；最佳拍摄时间为上午；周末游客较多；',
            ),
            const _FillingGuideItem(
              index: 5,
              title: '坐标与参考图',
              badge: '坐标必填',
              body: '优先从地图选择准确位置，也可粘贴纬度、经度。参考图建议使用能清楚辨认构图的原始画面。',
              example: '35.008900, 135.771100',
              isLast: true,
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_searching_outlined,
                    size: 19,
                    color: AppColors.accentDark,
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      '保存前建议核对地图标记是否落在正确建筑或道路一侧；坐标偏差会直接影响导航和现场查找。',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        height: 1.45,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('知道了'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualWorkFillingGuideSheet extends StatelessWidget {
  const _ManualWorkFillingGuideSheet();

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;

    return ConstrainedBox(
      key: const ValueKey('manual-work-guide-panel'),
      constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  color: AppColors.accentDark,
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '作品填写指南',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '填写作品本身的信息，点位名称、场景说明和具体地址请在添加点位时录入。',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 18),
            const _FillingGuideItem(
              index: 1,
              title: '作品名称',
              badge: '必填',
              body: '填写常用中文译名或最容易辨认的名称，不要填写集数或具体场景名。',
              example: '轻音少女',
            ),
            const _FillingGuideItem(
              index: 2,
              title: '作品原名',
              badge: '选填',
              body: '可填写官方日文、英文或其他原始标题；没有可靠信息时可以留空。',
              example: 'けいおん！',
            ),
            const _FillingGuideItem(
              index: 3,
              title: '作品类型',
              badge: '必填',
              body: '选择最接近作品发行形式的类型，方便在作品列表中辨认和筛选。',
              example: '动画',
            ),
            const _FillingGuideItem(
              index: 4,
              title: '主要地区',
              badge: '选填',
              body: '填写主要发生地或取景城市，可使用“城市 / 区域”的简洁格式；留空时沿用当前计划地区。',
              example: '京都市 / 宇治市',
              isLast: true,
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 19,
                    color: AppColors.accentDark,
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      '保存作品后，表单会清空以便继续添加。作品不会自动生成点位，可随后使用“手动添加点位”录入巡礼地点。',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        height: 1.45,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('知道了'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FillingGuideItem extends StatelessWidget {
  const _FillingGuideItem({
    required this.index,
    required this.title,
    required this.badge,
    required this.body,
    required this.example,
    this.isLast = false,
  });

  final int index;
  final String title;
  final String badge;
  final String body;
  final String example;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (!isLast)
                  Positioned(
                    top: 28,
                    bottom: 0,
                    child: Container(width: 2, color: AppColors.border),
                  ),
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$index',
                    style: TextStyle(
                      color: AppColors.onAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badge == '必填'
                              ? AppColors.accent.withValues(alpha: 0.1)
                              : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            color: badge == '必填'
                                ? AppColors.accentDark
                                : AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    body,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '示例：$example',
                    style: TextStyle(
                      color: AppColors.accentDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualWorkTypeDropdownItem extends StatefulWidget {
  const _ManualWorkTypeDropdownItem({
    required this.type,
    required this.selected,
  });

  final BangumiSubjectType type;
  final bool selected;

  @override
  State<_ManualWorkTypeDropdownItem> createState() =>
      _ManualWorkTypeDropdownItemState();
}

class _ManualWorkTypeDropdownItemState
    extends State<_ManualWorkTypeDropdownItem> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hovered = _hovered && !widget.selected;

    return MouseRegion(
      onEnter: widget.selected ? null : (_) => setState(() => _hovered = true),
      onExit: widget.selected ? null : (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.fromLTRB(hovered ? 14 : 8, 0, 8, 0),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(
            alpha: widget.selected ? 0.10 : (hovered ? 0.05 : 0),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: Text(widget.type.label)),
            if (widget.selected)
              Icon(Icons.check_circle, color: AppColors.accent, size: 18),
          ],
        ),
      ),
    );
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
    this.settings,
    this.editingPoint,
  });

  final PilgrimagePlan plan;
  final PilgrimageRepository repository;
  final AppSettings? settings;
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
      subtitle: subtitle.isEmpty ? '暂无作品原名' : subtitle,
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
      appScaledMaterialPageRoute<LatLng>(
        settings: settings,
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

  Future<void> _showPointFillingGuide() {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: AppScaledOverlayContent(
          settings: widget.settings ?? const AppSettings(),
          child: const _ManualPointFillingGuideSheet(),
        ),
      ),
    );
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
          actions: [
            TextButton.icon(
              key: const ValueKey('manual-point-filling-guide'),
              onPressed: _showPointFillingGuide,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentDark,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              icon: const Icon(Icons.menu_book_outlined, size: 17),
              label: const Text(
                '填写指南',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
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
                        settings: widget.settings ?? const AppSettings(),
                        omitScrollbarInsetWhenUnscrollable: true,
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
                      key: const ValueKey('point-form-name'),
                      controller: _nameController,
                      decoration: _boxedFormDecoration(hintText: '例如：东京国际会展中心'),
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
                      decoration: _boxedFormDecoration(hintText: '例如：東京ビッグサイト'),
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
                      decoration: _boxedFormDecoration(
                        hintText: '例如：EP 1 / 12:32',
                      ),
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
                      decoration: _boxedFormDecoration(
                        hintText: '例如：小红书@BilyHurington / Bilibili@麦块晓天',
                      ),
                      textInputAction: TextInputAction.next,
                      validator: _requiredText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ManualWorkLabeledField(
                    label: '备注',
                    prominent: true,
                    child: TextFormField(
                      key: const ValueKey('point-form-note'),
                      controller: _noteController,
                      decoration: _boxedFormDecoration(
                        hintText: '例如：2025年完成翻修；最佳拍摄时间为上午；周末游客较多',
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
                            key: const ValueKey('point-form-latitude'),
                            controller: _latitudeController,
                            focusNode: _latitudeFocusNode,
                            decoration: _coordinateInputDecoration(
                              hintText: '例如：35.712576',
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
                            key: const ValueKey('point-form-longitude'),
                            controller: _longitudeController,
                            focusNode: _longitudeFocusNode,
                            decoration: _coordinateInputDecoration(
                              hintText: '例如：139.722166',
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
                          key: const ValueKey('point-form-map-picker'),
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
                key: const ValueKey('point-form-save'),
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

class _LinkedWorksPanel extends StatelessWidget {
  const _LinkedWorksPanel({
    required this.plan,
    required this.onManage,
    required this.onBangumi,
    required this.onManual,
  });

  final PilgrimagePlan? plan;
  final VoidCallback? onManage;
  final VoidCallback? onBangumi;
  final VoidCallback? onManual;

  @override
  Widget build(BuildContext context) {
    final works = plan?.works ?? const <PilgrimageWork>[];
    final pointCount = plan?.points.length ?? 0;
    final visibleWorks = works.take(5).toList(growable: false);
    final remainingCount = works.length - visibleWorks.length;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('add-points-work-manager'),
              onTap: onManage,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '已关联作品',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '共 ${works.length} 部作品，$pointCount 个点位',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '管理作品',
                              style: TextStyle(
                                color: AppColors.accentDark,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.accent,
                              size: 20,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (works.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '还没有关联作品，可从 Bangumi 搜索或手动添加。',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 94,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
                        scrollDirection: Axis.horizontal,
                        itemCount:
                            visibleWorks.length + (remainingCount > 0 ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          if (index == visibleWorks.length) {
                            return _MoreWorksIndicator(count: remainingCount);
                          }
                          return _LinkedWorkPreview(work: visibleWorks[index]);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.55)),
          Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              height: 60,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _WorkCreationAction(
                      key: const ValueKey('add-points-bangumi-work'),
                      icon: Icons.search_rounded,
                      title: '从Bangumi添加',
                      subtitle: '自动获取信息',
                      onTap: onBangumi,
                    ),
                  ),
                  VerticalDivider(
                    width: 9,
                    indent: 8,
                    endIndent: 8,
                    thickness: 1,
                    color: AppColors.border.withValues(alpha: 0.55),
                  ),
                  Expanded(
                    child: _WorkCreationAction(
                      key: const ValueKey('add-points-manual-work'),
                      icon: Icons.add_rounded,
                      title: '手动添加作品',
                      subtitle: '未收录时使用',
                      onTap: onManual,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkedWorkPreview extends StatelessWidget {
  const _LinkedWorkPreview({required this.work});

  final PilgrimageWork work;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PilgrimageWorkCover(work: work, width: 56, height: 60),
          const SizedBox(height: 4),
          Text(
            work.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreWorksIndicator extends StatelessWidget {
  const _MoreWorksIndicator({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: 40,
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.only(top: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Text(
            '+$count',
            style: TextStyle(
              color: AppColors.accentDark,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkCreationAction extends StatelessWidget {
  const _WorkCreationAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(icon, color: AppColors.accent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
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
            ],
          ),
        ),
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
    required this.added,
    required this.disabled,
    required this.onAdd,
  });

  final PilgrimageWork work;
  final bool added;
  final bool disabled;
  final VoidCallback onAdd;

  @override
  State<_WorkResultCard> createState() => _WorkResultCardState();
}

class _WorkResultCardState extends State<_WorkResultCard> {
  var _expanded = false;
  var _titleExpanded = false;

  @override
  Widget build(BuildContext context) {
    final work = widget.work;
    final subtitle = work.subtitle.trim();
    final showSubtitle =
        subtitle.isNotEmpty &&
        subtitle != work.title.trim() &&
        !subtitle.startsWith('Bangumi #');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          PilgrimageWorkCover(work: work),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _titleExpanded = !_titleExpanded;
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: Text(
                      work.title,
                      maxLines: _titleExpanded ? null : 1,
                      overflow: _titleExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: showSubtitle
                      ? () {
                          setState(() {
                            _expanded = !_expanded;
                          });
                        }
                      : null,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      showSubtitle ? subtitle : '暂无作品原名',
                      maxLines: showSubtitle && _expanded ? null : 1,
                      overflow: showSubtitle && _expanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: TextStyle(
                        color: showSubtitle
                            ? AppColors.textSecondary
                            : AppColors.textSecondary.withValues(alpha: 0.55),
                        fontSize: 12,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
                if (work.displayBangumiSubjectType != null) ...[
                  const SizedBox(height: 6),
                  _SubjectTypePill(type: work.displayBangumiSubjectType!),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (widget.added)
            FilledButton(
              onPressed: null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(88, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                disabledBackgroundColor: AppColors.accent.withValues(
                  alpha: 0.10,
                ),
                disabledForegroundColor: AppColors.accentDark,
              ),
              child: const Text('已添加'),
            )
          else
            OutlinedButton(
              onPressed: widget.disabled ? null : widget.onAdd,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(88, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: const Text('加入'),
            ),
        ],
      ),
    );
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

class _BangumiSearchHintContent extends StatelessWidget {
  const _BangumiSearchHintContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.manage_search_rounded,
              color: AppColors.accent,
              size: 17,
            ),
            const SizedBox(width: 8),
            const Text(
              '搜索说明',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.only(left: 25),
          child: Text(
            '输入作品名后搜索，选择结果即可加入当前计划。',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.35,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 25),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.accent,
                  size: 16,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Bangumi需要国际网络环境才能正常搜索。',
                  style: TextStyle(
                    color: AppColors.accentDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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

class _QuickImportPanel extends StatelessWidget {
  const _QuickImportPanel({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: const ValueKey('add-points-anitabi-link'),
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.32)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.link_rounded,
                            color: AppColors.accent,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    '快速导入',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withValues(
                                        alpha: 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '推荐',
                                      style: TextStyle(
                                        color: AppColors.accentDark,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                '在导入Anitabi点位的同时自动导入作品',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: enabled
                              ? AppColors.accent
                              : AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddPointPanel extends StatelessWidget {
  const _AddPointPanel({
    required this.mapEnabled,
    required this.manualEnabled,
    required this.onMap,
    required this.onManual,
  });

  final bool mapEnabled;
  final bool manualEnabled;
  final VoidCallback? onMap;
  final VoidCallback? onManual;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 9),
                const Text(
                  '添加点位',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          _PointCreationAction(
            key: const ValueKey('add-points-anitabi-map'),
            icon: Icons.map_outlined,
            title: '从作品地图导入点位',
            subtitle: '在作品地图上选择并导入点位',
            recommended: true,
            enabled: mapEnabled,
            onTap: onMap,
          ),
          Divider(
            height: 1,
            indent: 12,
            endIndent: 12,
            color: AppColors.border.withValues(alpha: 0.60),
          ),
          _PointCreationAction(
            key: const ValueKey('add-points-manual-point'),
            icon: Icons.edit_location_alt_outlined,
            title: '手动添加点位',
            subtitle: '手动输入点位信息，逐个添加',
            enabled: manualEnabled,
            onTap: onManual,
          ),
        ],
      ),
    );
  }
}

class _PointCreationAction extends StatelessWidget {
  const _PointCreationAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
    this.recommended = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: enabled ? Colors.transparent : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(7),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(7),
          child: SizedBox(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: enabled
                          ? AppColors.accent.withValues(alpha: 0.08)
                          : AppColors.border.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: enabled
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: enabled
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                            if (recommended) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: enabled
                                      ? AppColors.accent.withValues(alpha: 0.10)
                                      : AppColors.border.withValues(
                                          alpha: 0.30,
                                        ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '推荐',
                                  style: TextStyle(
                                    color: enabled
                                        ? AppColors.accentDark
                                        : AppColors.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(
                              alpha: enabled ? 1 : 0.65,
                            ),
                            fontSize: 13,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: enabled ? AppColors.accent : AppColors.textSecondary,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
