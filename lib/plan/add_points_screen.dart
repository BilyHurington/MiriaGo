import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../app_theme.dart';
import '../widgets/snackbar_helper.dart';
import '../data/bangumi_api_client.dart';
import '../data/pilgrimage_repository.dart';
import '../data/user_reference_image_stub.dart'
    if (dart.library.io) '../data/user_reference_image_io.dart';
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
  Object? _error;
  bool _isSearching = false;
  bool _isAdding = false;

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
      final results = await widget.bangumiApiClient.searchAnime(query);
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

      Navigator.of(context).pop(true);
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
    return Scaffold(
      appBar: AppBar(title: const Text('搜索 Bangumi')),
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
    );
  }

  bool _hasWork(PilgrimagePlan plan, PilgrimageWork work) {
    return plan.works.any((candidate) => candidate.id == work.id);
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

      Navigator.of(context).pop(true);
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
    return Scaffold(
      appBar: AppBar(title: const Text('手动添加作品')),
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

  void _removeReferenceImage() {
    setState(() {
      _pickedReferenceImage = null;
    });
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
                          child: Text(work.title),
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

class _WorkResultCard extends StatelessWidget {
  const _WorkResultCard({
    required this.work,
    required this.disabled,
    required this.onAdd,
  });

  final PilgrimageWork work;
  final bool disabled;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
                const SizedBox(height: 3),
                Text(
                  '${work.subtitle} / Bangumi #${work.bangumiId}',
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
          const SizedBox(width: 12),
          TextButton(
            onPressed: disabled ? null : onAdd,
            child: Text(disabled ? '已添加' : '加入'),
          ),
        ],
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
