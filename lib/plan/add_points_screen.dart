import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../app_theme.dart';
import '../data/pilgrimage_repository.dart';
import 'pilgrimage_models.dart';

class AddPointsScreen extends StatelessWidget {
  const AddPointsScreen({
    required this.plan,
    required this.repository,
    super.key,
  });

  final PilgrimagePlan? plan;
  final PilgrimageRepository repository;

  @override
  Widget build(BuildContext context) {
    final currentPlan = plan;

    return Scaffold(
      appBar: AppBar(title: const Text('添加点位')),
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
          _AddSourceCard(
            icon: Icons.travel_explore,
            title: '从 Anitabi 添加',
            body: '输入 Bangumi / Anitabi ID，拉取作品点位后选择加入计划。',
            enabled: false,
            actionLabel: '待实现',
            onTap: null,
          ),
          const SizedBox(height: 8),
          _AddSourceCard(
            icon: Icons.add_location_alt_outlined,
            title: '手动添加点位',
            body: '输入名称和坐标，创建自定义巡礼点。',
            enabled: currentPlan != null,
            actionLabel: currentPlan == null ? '不可用' : '添加',
            onTap: currentPlan == null
                ? null
                : () => _openManualPointForm(context, currentPlan),
          ),
        ],
      ),
    );
  }

  Future<void> _openManualPointForm(
    BuildContext context,
    PilgrimagePlan plan,
  ) async {
    final didAdd = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            _ManualPointFormScreen(plan: plan, repository: repository),
      ),
    );

    if (!context.mounted || didAdd != true) {
      return;
    }

    Navigator.of(context).pop(true);
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
  final _nameController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _episodeController = TextEditingController();
  final _referenceController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
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
      final point = PilgrimagePoint(
        id: 'manual-${now.microsecondsSinceEpoch}',
        name: _nameController.text.trim(),
        subtitle: _subtitleController.text.trim(),
        position: LatLng(
          double.parse(_latitudeController.text.trim()),
          double.parse(_longitudeController.text.trim()),
        ),
        episodeLabel: _episodeController.text.trim(),
        referenceLabel: _referenceController.text.trim(),
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
      ).showSnackBar(const SnackBar(content: Text('点位保存失败，请稍后重试。')));
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
