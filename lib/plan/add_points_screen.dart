import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../app_theme.dart';
import '../data/bangumi_api_client.dart';
import '../data/pilgrimage_repository.dart';
import '../data/user_reference_image_stub.dart'
    if (dart.library.io) '../data/user_reference_image_io.dart';
import '../map/map_tile_config.dart';
import '../widgets/snackbar_helper.dart';
import '../widgets/reference_thumbnail_stub.dart'
    if (dart.library.io) '../widgets/reference_thumbnail_io.dart';
import 'anitabi_map_import_screen.dart';
import 'pilgrimage_models.dart';
import 'work_manager_screen.dart';

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
      canPop: false,
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
              enabled: _hasBangumiWork(currentPlan),
              actionLabel: _hasBangumiWork(currentPlan) ? '打开' : '需作品',
              onTap: currentPlan == null
                  ? null
                  : () => _openAnitabiMapImport(context, currentPlan),
            ),
            const SizedBox(height: 8),
            _AddSourceCard(
              icon: Icons.travel_explore_outlined,
              title: '从 Anitabi 点位 ID 导入',
              body: '输入 Anitabi 地图里的点位 ID，自动补齐对应作品并显示点位。',
              enabled: currentPlan != null,
              actionLabel: currentPlan == null ? '不可用' : '输入',
              onTap: currentPlan == null
                  ? null
                  : () => _openAnitabiPointIdImport(context, currentPlan),
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
    final didUpdate = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => WorkManagerScreen(
          plan: plan,
          repository: widget.repository,
          bangumiApiClient: widget.bangumiApiClient,
        ),
      ),
    );
    if (!context.mounted || didUpdate != true) {
      return;
    }

    await _reloadPlan(plan.id);
  }

  Future<void> _openAnitabiMapImport(
    BuildContext context,
    PilgrimagePlan plan,
  ) async {
    final didAdd = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            AnitabiMapImportScreen(plan: plan, repository: widget.repository),
      ),
    );
    if (!context.mounted || didAdd != true) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  Future<void> _openAnitabiPointIdImport(
    BuildContext context,
    PilgrimagePlan plan,
  ) async {
    final didUpdate = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _AnitabiPointIdImportScreen(
          plan: plan,
          repository: widget.repository,
        ),
      ),
    );
    if (!context.mounted || didUpdate != true) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  Future<void> _openManualPointForm(
    BuildContext context,
    PilgrimagePlan plan,
  ) async {
    final didAdd = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            _ManualPointFormScreen(plan: plan, repository: widget.repository),
      ),
    );
    if (!context.mounted || didAdd != true) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  Future<void> _reloadPlan(String planId) async {
    final plans = await widget.repository.loadPlans();
    if (!mounted) {
      return;
    }

    setState(() {
      _plan = plans.firstWhere((plan) => plan.id == planId);
      _didUpdate = true;
    });
  }

  bool _hasBangumiWork(PilgrimagePlan? plan) {
    return plan?.works.any((work) => work.bangumiId != null) ?? false;
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
      canPop: false,
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
              const _MessageCard(
                icon: Icons.info_outline,
                text: '输入作品名后搜索，选择结果即可加入当前计划。',
              )
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

class _AnitabiPointIdImportScreen extends StatefulWidget {
  const _AnitabiPointIdImportScreen({
    required this.plan,
    required this.repository,
  });

  final PilgrimagePlan plan;
  final PilgrimageRepository repository;

  @override
  State<_AnitabiPointIdImportScreen> createState() =>
      _AnitabiPointIdImportScreenState();
}

class _AnitabiPointIdImportScreenState
    extends State<_AnitabiPointIdImportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pointIdController = TextEditingController();

  @override
  void dispose() {
    _pointIdController.dispose();
    super.dispose();
  }

  Future<void> _openImport() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      return;
    }

    final pointId = _pointIdController.text.trim();
    final didUpdate = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AnitabiMapImportScreen(
          plan: widget.plan,
          repository: widget.repository,
          initialPointId: pointId,
        ),
      ),
    );
    if (!mounted || didUpdate != true) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Anitabi 点位 ID 导入')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              '加入到：${widget.plan.name}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 12),
            _FormSection(
              children: [
                TextFormField(
                  controller: _pointIdController,
                  decoration: const InputDecoration(
                    labelText: 'Anitabi 点位 ID',
                    hintText: '例如 qdmnf6iqj',
                  ),
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  validator: _validatePointId,
                  onFieldSubmitted: (_) => _openImport(),
                ),
                const SizedBox(height: 10),
                const Text(
                  '会按点位 ID 查找所属作品；如果当前计划还没有该作品，会先自动导入作品，再显示这个点位供你加入计划。',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openImport,
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: const Text('查找点位'),
            ),
          ],
        ),
      ),
    );
  }

  String? _validatePointId(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return '请输入点位 ID';
    }
    if (!RegExp(r'^[a-zA-Z0-9_-]{3,32}$').hasMatch(text)) {
      return '请输入有效点位 ID';
    }
    return null;
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
      canPop: false,
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
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: '作品名称'),
                    textInputAction: TextInputAction.next,
                    validator: _requiredText,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _subtitleController,
                    decoration: const InputDecoration(
                      labelText: '作品原名',
                      hintText: '可选',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cityController,
                    decoration: InputDecoration(
                      labelText: '主要地区',
                      hintText: '可选，默认 ${widget.plan.area}',
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _saveWork(),
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

class _ManualPointFormScreen extends StatefulWidget {
  const _ManualPointFormScreen({required this.plan, required this.repository});

  final PilgrimagePlan plan;
  final PilgrimageRepository repository;

  @override
  State<_ManualPointFormScreen> createState() => _ManualPointFormScreenState();
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
  PilgrimageWork? _selectedWork;
  XFile? _pickedReferenceImage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedWork = widget.plan.works.firstOrNull;
  }

  @override
  void dispose() {
    _fallbackWorkTitleController.dispose();
    _fallbackWorkSubtitleController.dispose();
    _fallbackWorkCityController.dispose();
    _nameController.dispose();
    _subtitleController.dispose();
    _episodeController.dispose();
    _referenceController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
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
      final work = _selectedWork ?? _fallbackWork(now);
      final pointId = 'manual-${now.microsecondsSinceEpoch}';
      final storedReference = _pickedReferenceImage == null
          ? null
          : await storeUserReferenceImage(
              sourcePath: _pickedReferenceImage!.path,
              pointId: pointId,
            );
      final point = PilgrimagePoint(
        id: pointId,
        work: work,
        name: _nameController.text.trim(),
        subtitle: _subtitleController.text.trim(),
        position: LatLng(
          double.parse(_latitudeController.text.trim()),
          double.parse(_longitudeController.text.trim()),
        ),
        episodeLabel: _episodeController.text.trim(),
        referenceLabel: _referenceController.text.trim(),
        referenceThumbnailPath: storedReference?.thumbnailPath,
        referenceFullImagePath: storedReference?.fullImagePath,
      );

      await widget.repository.addPointToPlan(
        planId: widget.plan.id,
        point: point,
      );
      if (!mounted) {
        return;
      }

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

    setState(() {
      _pickedReferenceImage = picked;
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

  void _removeReferenceImage() {
    setState(() {
      _pickedReferenceImage = null;
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
    final hasPlanWorks = widget.plan.works.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('手动添加点位')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              '加入到：${widget.plan.name}',
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
                  DropdownButtonFormField<PilgrimageWork>(
                    initialValue: _selectedWork,
                    decoration: const InputDecoration(labelText: '所属作品'),
                    items: [
                      for (final work in widget.plan.works)
                        DropdownMenuItem<PilgrimageWork>(
                          value: work,
                          child: Text(
                            work.displayBangumiSubjectType == null
                                ? work.title
                                : '${work.title} · ${work.displayBangumiSubjectType!.label}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (work) {
                      setState(() {
                        _selectedWork = work;
                      });
                    },
                    validator: (work) => work == null ? '请选择作品' : null,
                  )
                else ...[
                  TextFormField(
                    controller: _fallbackWorkTitleController,
                    decoration: const InputDecoration(labelText: '动画/作品名称'),
                    textInputAction: TextInputAction.next,
                    validator: _requiredText,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fallbackWorkSubtitleController,
                    decoration: const InputDecoration(
                      labelText: '作品原名',
                      hintText: '可选',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fallbackWorkCityController,
                    decoration: InputDecoration(
                      labelText: '作品主要地区',
                      hintText: '可选，默认 ${widget.plan.area}',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            _FormSection(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '点位名称'),
                  textInputAction: TextInputAction.next,
                  validator: _requiredText,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _subtitleController,
                  decoration: const InputDecoration(labelText: '位置说明'),
                  textInputAction: TextInputAction.next,
                  validator: _requiredText,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _episodeController,
                  decoration: const InputDecoration(labelText: '集数/场景标签'),
                  textInputAction: TextInputAction.next,
                  validator: _requiredText,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _referenceController,
                  decoration: const InputDecoration(labelText: '参考来源'),
                  textInputAction: TextInputAction.next,
                  validator: _requiredText,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _FormSection(
              children: [
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickCoordinateFromMap,
                  icon: const Icon(Icons.ads_click_outlined, size: 18),
                  label: const Text('从地图选择坐标'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _latitudeController,
                  decoration: const InputDecoration(
                    labelText: '纬度',
                    hintText: '例如 34.8917',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  textInputAction: TextInputAction.next,
                  validator: _validateLatitude,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _longitudeController,
                  decoration: const InputDecoration(
                    labelText: '经度',
                    hintText: '例如 135.8077',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  textInputAction: TextInputAction.done,
                  validator: _validateLongitude,
                  onFieldSubmitted: (_) => _savePoint(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ManualReferenceImagePicker(
              imagePath: _pickedReferenceImage?.path,
              onPick: _isSaving ? null : _pickReferenceImage,
              onRemove: _isSaving || _pickedReferenceImage == null
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
              label: Text(_isSaving ? '保存中' : '保存点位'),
            ),
          ],
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
              maxZoom: 19,
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
    required this.imagePath,
    required this.onPick,
    required this.onRemove,
  });

  final String? imagePath;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 72,
              height: 72,
              color: AppColors.surfaceMuted,
              child: ReferenceThumbnail(
                localPath: path,
                imageUrl: null,
                fit: BoxFit.cover,
                placeholder: const Icon(
                  Icons.image_outlined,
                  color: AppColors.textSecondary,
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
                  path == null ? '可选，保存时会复制到 App 本地目录。' : '已选择本地图片',
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
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: Text(path == null ? '上传参考图' : '重新选择'),
                    ),
                    if (path != null)
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
