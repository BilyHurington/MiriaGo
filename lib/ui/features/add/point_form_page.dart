import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/add/point_edit_service.dart';
import '../../../application/plan_session.dart';
import '../../../application/settings_store.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../../plan/reference_image_status.dart';
import '../../../widgets/reference_thumbnail_stub.dart'
    if (dart.library.io) '../../../widgets/reference_thumbnail_io.dart';
import '../../components/components.dart';
import '../organize/location_picker.dart';
import '../plan/plan_workspace.dart';
import '../viewer/image_viewer.dart';
import 'add_widgets.dart';
import 'anitabi_import_page.dart' show workBadgeLabel;
import 'manual_work_page.dart' show requiredFieldValidator;

/// 「点位填写指南」 (old `_ManualPointFillingGuideSheet`), with the badges
/// updated for the merged form (DESIGN Δ3: only 作品 and 名称 are required).
const _pointGuide = FillingGuide(
  key: ValueKey('point-form-guide'),
  title: '点位填写指南',
  intro: '重点记录现场可识别的信息，方便到达后快速确认位置、场景和拍摄条件。',
  tipIcon: Symbols.my_location_rounded,
  items: [
    FillingGuideItem(
      title: '所属作品',
      badge: '必填',
      body: '选择点位对应的作品。计划中还没有作品时，先填写作品名称、原名和主要地区。',
      example: '轻音少女',
    ),
    FillingGuideItem(
      title: '名称与位置说明',
      badge: '名称必填',
      body: '名称优先填写中文常用名；位置说明优先填写当地原语言的地标、建筑或店铺名称，方便现场核对。',
      example: '东京国际会展中心 / 東京ビッグサイト',
    ),
    FillingGuideItem(
      title: '场景标签与参考来源',
      badge: '选填',
      body: '场景标签只写集数、时间点或场景编号；参考来源填写该点位原来所在的平台，或原始上传者。',
      example: 'EP 1 / 12:32\n示例：小红书@BilyHurington / Bilibili@麦块晓天',
    ),
    FillingGuideItem(
      title: '备注',
      badge: '选填',
      body: '记录营业时间、闭店翻修、拍摄限制、推荐机位或其他到访前需要知道的信息。',
      example: '2025年完成翻修；最佳拍摄时间为上午；周末游客较多；',
    ),
    FillingGuideItem(
      title: '坐标与参考图',
      badge: '坐标成对填写',
      body: '优先从地图选择准确位置，也可粘贴纬度、经度。参考图建议使用能清楚辨认构图的原始画面。',
      example: '35.008900, 135.771100',
    ),
  ],
  tip: '保存前建议核对地图标记是否落在正确建筑或道路一侧；坐标偏差会直接影响导航和现场查找。',
);

/// The merged point form (DESIGN §8.11): create when [pointId] is null,
/// otherwise edit. Pops `true` after saving.
class PointFormPage extends StatelessWidget {
  const PointFormPage({this.pointId, super.key});

  /// Null → create a new point; otherwise edit this point.
  final String? pointId;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PlanSession>();
    if (!session.isReady) {
      return const MiriaPageScaffold(
        title: '添加点位',
        body: Center(child: ProgressRing()),
      );
    }
    final id = pointId;
    PilgrimagePoint? editing;
    if (id != null) {
      editing = session.plan.points.where((p) => p.id == id).firstOrNull;
      if (editing == null) {
        return const MiriaPageScaffold(
          title: '编辑点位',
          body: EmptyState(
            icon: Symbols.location_off_rounded,
            title: '找不到这个点位',
            message: '点位可能已被删除，请返回计划刷新后再试。',
          ),
        );
      }
    }
    return _PointForm(key: ValueKey(id), editing: editing);
  }
}

class _PointForm extends StatefulWidget {
  const _PointForm({required this.editing, super.key});

  final PilgrimagePoint? editing;

  @override
  State<_PointForm> createState() => _PointFormState();
}

class _PointFormState extends State<_PointForm> {
  final _formKey = GlobalKey<FormState>();
  final _workTitle = TextEditingController();
  final _workSubtitle = TextEditingController();
  final _workCity = TextEditingController();
  final _name = TextEditingController();
  final _subtitle = TextEditingController();
  final _episode = TextEditingController();
  final _reference = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _note = TextEditingController();
  late final PointEditSession _edit;
  PilgrimageWork? _work;
  late bool _pending;
  late bool _moreExpanded;
  PlanWorkspaceScope? _workspace;

  PilgrimagePoint? get _editing => widget.editing;

  @override
  void initState() {
    super.initState();
    _edit = PointEditSession(
      session: context.read<PlanSession>(),
      editingPoint: _editing,
    );
    _work = _edit.initialWork();
    final editing = _editing;
    _moreExpanded = editing != null;
    _pending = editing != null && !editing.hasCoordinate;
    if (editing != null) {
      _name.text = editing.name;
      _subtitle.text = editing.subtitle;
      _episode.text = editing.episodeLabel;
      _reference.text = editing.referenceLabel;
      if (editing.hasCoordinate) {
        _latitude.text = formatCoordinateComponent(editing.position.latitude);
        _longitude.text = formatCoordinateComponent(editing.position.longitude);
      }
      _note.text = editing.note ?? '';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final workspace = PlanWorkspaceScope.maybeOf(context);
    if (!identical(workspace, _workspace)) {
      _workspace?.removeLeaveGuard(_canLeave);
      _workspace = workspace?..addLeaveGuard(_canLeave);
    }
  }

  /// The plan secondary navigation is blocked like back while picking a
  /// reference image or saving (old `PopScope(canPop: !_isBusy)`).
  Future<bool> _canLeave() async => !_edit.isBusy;

  @override
  void dispose() {
    _workspace?.removeLeaveGuard(_canLeave);
    _edit.dispose();
    for (final controller in [
      _workTitle,
      _workSubtitle,
      _workCity,
      _name,
      _subtitle,
      _episode,
      _reference,
      _latitude,
      _longitude,
      _note,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  PointFormValues get _values => PointFormValues(
    work: _work,
    newWorkTitle: _workTitle.text,
    newWorkSubtitle: _workSubtitle.text,
    newWorkCity: _workCity.text,
    name: _name.text,
    latitude: _latitude.text,
    longitude: _longitude.text,
    coordinatesPending: _pending,
    subtitle: _subtitle.text,
    episodeLabel: _episode.text,
    referenceLabel: _reference.text,
    note: _note.text,
  );

  Future<void> _save() async {
    if (_edit.isBusy || _edit.isSaveLocked || !mounted) return;
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    FocusScope.of(context).unfocus();
    final result = await _edit.save(_values);
    if (!mounted) return;
    switch (result.status) {
      case PointSaveStatus.saved:
        context.pop(true);
      case PointSaveStatus.failed:
      case PointSaveStatus.uncertain:
        final notice = result.notice;
        if (notice != null) showAddNotice(context, notice);
      case PointSaveStatus.ignored:
        break;
    }
  }

  Future<void> _pickFromMap() async {
    if (_edit.isBusy) return;
    final session = context.read<PlanSession>();
    final initial =
        parseCoordinateInput(_latitude.text, _longitude.text) ??
        planCenterFor(session.plan);
    final picked = await pickLocation(
      context,
      initial: initial,
      title: '选择点位坐标',
    );
    if (picked == null || !mounted || _edit.isBusy) return;
    setState(() {
      _pending = false;
      _latitude.text = formatCoordinateComponent(picked.latitude);
      _longitude.text = formatCoordinateComponent(picked.longitude);
    });
  }

  Future<void> _paste() async {
    if (_edit.isBusy) return;
    final result = await readClipboardCoordinate();
    if (!mounted || _edit.isBusy) return;
    final position = result.position;
    if (position != null) {
      setState(() {
        _pending = false;
        _latitude.text = formatCoordinateComponent(position.latitude);
        _longitude.text = formatCoordinateComponent(position.longitude);
      });
    }
    showAddNotice(context, result.notice);
  }

  Future<void> _pickImage() async {
    if (_edit.isBusy) return;
    FocusScope.of(context).unfocus();
    final notice = await _edit.pickReferenceImage();
    if (notice != null && mounted) showAddNotice(context, notice);
  }

  void _openPreview({String? path, String? url}) {
    if (_edit.isBusy) return;
    unawaited(
      openImageViewer(
        context,
        images: [
          path != null
              ? ViewerImage(path: path, label: '参考图')
              : ViewerImage(url: url, label: '参考图'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PlanSession>();
    return ListenableBuilder(
      listenable: _edit,
      builder: (context, _) {
        final editing = _editing;
        final busy = _edit.isBusy;
        final works = _edit.workOptions();
        return PopScope(
          canPop: !busy,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) _edit.markExiting();
          },
          child: MiriaPageScaffold(
            title: editing == null ? '添加点位' : '编辑点位',
            subtitle: editing == null
                ? '加入到：${session.plan.name}'
                : '修改：${editing.name}',
            body: Form(
              key: _formKey,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(top: Space.x2, bottom: Space.x8),
                children: [
                  ContentColumn(
                    maxWidth: 640,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AddFormSection(
                          children: [
                            if (works.isNotEmpty)
                              _WorkSelect(
                                works: works,
                                value: _work,
                                enabled: !busy,
                                onChanged: (work) =>
                                    setState(() => _work = work),
                              )
                            else
                              _NewWorkFields(
                                title: _workTitle,
                                subtitle: _workSubtitle,
                                city: _workCity,
                                enabled: !busy,
                              ),
                            const SizedBox(height: Space.x4),
                            MiriaTextField(
                              key: const ValueKey('point-form-name'),
                              label: '点位名称',
                              required: true,
                              hint: '例如：东京国际会展中心',
                              controller: _name,
                              enabled: !busy,
                              locale: MiriaFonts.japanese,
                              textInputAction: TextInputAction.next,
                              validator: requiredFieldValidator,
                            ),
                            const SizedBox(height: Space.x4),
                            _CoordinateSection(
                              latitude: _latitude,
                              longitude: _longitude,
                              pending: _pending,
                              enabled: !busy,
                              onPendingChanged: (value) =>
                                  setState(() => _pending = value),
                              onPickFromMap: _pickFromMap,
                              onPaste: _paste,
                            ),
                          ],
                        ),
                        const SizedBox(height: Space.x3),
                        _MoreInfo(
                          expanded: _moreExpanded,
                          onToggle: () =>
                              setState(() => _moreExpanded = !_moreExpanded),
                          children: [
                            MiriaTextField(
                              key: const ValueKey('point-form-subtitle'),
                              label: '位置说明',
                              hint: '例如：東京ビッグサイト',
                              controller: _subtitle,
                              enabled: !busy,
                              locale: MiriaFonts.japanese,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: Space.x3),
                            MiriaTextField(
                              key: const ValueKey('point-form-episode'),
                              label: '集数/场景标签',
                              hint: '例如：EP 1 / 12:32',
                              controller: _episode,
                              enabled: !busy,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: Space.x3),
                            MiriaTextField(
                              key: const ValueKey('point-form-reference'),
                              label: '参考来源',
                              hint: '例如：小红书@BilyHurington / Bilibili@麦块晓天',
                              controller: _reference,
                              enabled: !busy,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: Space.x3),
                            MiriaTextField(
                              key: const ValueKey('point-form-note'),
                              label: '备注',
                              hint: '例如：2025年完成翻修；最佳拍摄时间为上午；周末游客较多',
                              controller: _note,
                              enabled: !busy,
                              minLines: 3,
                              maxLines: 8,
                              keyboardType: TextInputType.multiline,
                            ),
                          ],
                        ),
                        const SizedBox(height: Space.x3),
                        _ReferenceImagePicker(
                          edit: _edit,
                          editing: editing,
                          onPick: _pickImage,
                          onRemove: _edit.removeReferenceImage,
                          onPreview: _openPreview,
                        ),
                        const SizedBox(height: Space.x4),
                        MiriaButton(
                          key: const ValueKey('point-form-save'),
                          label: _edit.isSaving
                              ? '保存中'
                              : editing == null
                              ? '保存点位'
                              : '保存修改',
                          icon: Symbols.check_rounded,
                          loading: _edit.isSaving,
                          size: MiriaButtonSize.lg,
                          expand: true,
                          onPressed: busy || _edit.isSaveLocked ? null : _save,
                        ),
                        const SizedBox(height: Space.x4),
                        _pointGuide,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WorkSelect extends StatelessWidget {
  const _WorkSelect({
    required this.works,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final List<PilgrimageWork> works;
  final PilgrimageWork? value;
  final bool enabled;
  final ValueChanged<PilgrimageWork> onChanged;

  @override
  Widget build(BuildContext context) {
    return FormField<PilgrimageWork>(
      initialValue: value,
      validator: (_) => value == null ? '请选择作品' : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('所属作品', required: true),
          SelectField<PilgrimageWork>(
            key: const ValueKey('point-form-work'),
            pickerTitle: '所属作品',
            options: [
              for (final work in works)
                SelectOption(
                  value: work,
                  label: work.title,
                  subtitle: workBadgeLabel(work),
                ),
            ],
            value: value,
            error: field.errorText,
            onChanged: enabled
                ? (work) {
                    field.didChange(work);
                    onChanged(work);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _NewWorkFields extends StatelessWidget {
  const _NewWorkFields({
    required this.title,
    required this.subtitle,
    required this.city,
    required this.enabled,
  });

  final TextEditingController title;
  final TextEditingController subtitle;
  final TextEditingController city;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('point-form-new-work'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InfoBanner(message: '计划中还没有作品时，先填写作品名称、原名和主要地区。'),
        const SizedBox(height: Space.x3),
        MiriaTextField(
          key: const ValueKey('point-form-work-title'),
          label: '作品名称',
          required: true,
          hint: '请输入作品的中文名称',
          controller: title,
          enabled: enabled,
          textInputAction: TextInputAction.next,
          validator: requiredFieldValidator,
        ),
        const SizedBox(height: Space.x3),
        MiriaTextField(
          key: const ValueKey('point-form-work-subtitle'),
          label: '作品原名',
          hint: '请输入作品的原名（如日文/英文）',
          controller: subtitle,
          enabled: enabled,
          locale: MiriaFonts.japanese,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: Space.x3),
        MiriaTextField(
          key: const ValueKey('point-form-work-city'),
          label: '主要地区',
          hint: '输入作品主要发生或取景的地区',
          controller: city,
          enabled: enabled,
          textInputAction: TextInputAction.next,
        ),
      ],
    );
  }
}

class _CoordinateSection extends StatelessWidget {
  const _CoordinateSection({
    required this.latitude,
    required this.longitude,
    required this.pending,
    required this.enabled,
    required this.onPendingChanged,
    required this.onPickFromMap,
    required this.onPaste,
  });

  final TextEditingController latitude;
  final TextEditingController longitude;
  final bool pending;
  final bool enabled;
  final ValueChanged<bool> onPendingChanged;
  final VoidCallback onPickFromMap;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fieldsEnabled = enabled && !pending;
    final latField = MiriaTextField(
      key: const ValueKey('point-form-latitude'),
      label: '纬度',
      hint: '例如：35.712576',
      controller: latitude,
      enabled: fieldsEnabled,
      keyboardType: const TextInputType.numberWithOptions(
        signed: true,
        decimal: true,
      ),
      textInputAction: TextInputAction.next,
      validator: (value) => validateCoordinateField(
        value ?? '',
        other: longitude.text,
        latitude: true,
        pending: pending,
      ),
    );
    final lngField = MiriaTextField(
      key: const ValueKey('point-form-longitude'),
      label: '经度',
      hint: '例如：139.722166',
      controller: longitude,
      enabled: fieldsEnabled,
      keyboardType: const TextInputType.numberWithOptions(
        signed: true,
        decimal: true,
      ),
      textInputAction: TextInputAction.next,
      validator: (value) => validateCoordinateField(
        value ?? '',
        other: latitude.text,
        latitude: false,
        pending: pending,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('坐标位置'),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 360 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.4;
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  latField,
                  const SizedBox(height: Space.x3),
                  lngField,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: latField),
                const SizedBox(width: Space.x3),
                Expanded(child: lngField),
              ],
            );
          },
        ),
        const SizedBox(height: Space.x3),
        Row(
          children: [
            Expanded(
              child: MiriaButton.secondary(
                key: const ValueKey('point-form-map-picker'),
                label: '从地图选择',
                shortLabel: '地图选择',
                semanticLabel: '从地图选择坐标',
                icon: Symbols.map_rounded,
                expand: true,
                onPressed: enabled ? onPickFromMap : null,
              ),
            ),
            const SizedBox(width: Space.x2),
            MiriaIconButton(
              key: const ValueKey('point-form-paste-coordinate'),
              icon: Symbols.content_paste_rounded,
              tooltip: '粘贴剪贴板坐标',
              variant: MiriaIconButtonVariant.filled,
              onPressed: enabled ? onPaste : null,
            ),
          ],
        ),
        const SizedBox(height: Space.x2),
        MiriaPressable(
          key: const ValueKey('point-form-pending'),
          onTap: enabled ? () => onPendingChanged(!pending) : null,
          enabled: enabled,
          borderRadius: Radii.smAll,
          semanticLabel: '坐标待补充',
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Checkbox(
                  value: pending,
                  onChanged: enabled
                      ? (value) => onPendingChanged(value ?? false)
                      : null,
                ),
                Expanded(
                  child: Text(
                    '坐标待补充',
                    style: context.text.bodyMedium?.copyWith(
                      color: enabled ? c.textPrimary : c.textDisabled,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MoreInfo extends StatelessWidget {
  const _MoreInfo({
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Radii.mdAll,
        border: Border.all(color: c.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MiriaPressable(
            key: const ValueKey('point-form-more'),
            onTap: onToggle,
            semanticLabel: '更多信息',
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.x4,
                  vertical: Space.x3,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('更多信息', style: text.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                            '位置说明、集数 / 场景、参考来源、备注',
                            style: text.bodySmall?.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: Motion.of(context, Motion.standard),
                      child: Icon(
                        Symbols.expand_more_rounded,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: Motion.of(context, Motion.standard),
            curve: Motion.emphasized,
            alignment: Alignment.topCenter,
            // Keep the fields mounted so collapsed values still save.
            child: Offstage(
              offstage: !expanded,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.x4,
                  0,
                  Space.x4,
                  Space.x4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceImagePicker extends StatelessWidget {
  const _ReferenceImagePicker({
    required this.edit,
    required this.editing,
    required this.onPick,
    required this.onRemove,
    required this.onPreview,
  });

  final PointEditSession edit;
  final PilgrimagePoint? editing;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final void Function({String? path, String? url}) onPreview;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final busy = edit.isBusy;
    final pending = edit.pendingImage;
    final editing = this.editing;
    final existingUrl = editing != null && hasRemoteReferenceImage(editing)
        ? editing.referenceImageUrl
        : null;
    final hasPending = pending != null;
    final hasExisting =
        editing?.referenceThumbnailPath != null ||
        editing?.referenceFullImagePath != null ||
        existingUrl != null;
    final hasImage = hasPending || hasExisting;
    final localPath =
        pending?.stored.thumbnailPath ??
        editing?.referenceThumbnailPath ??
        editing?.referenceFullImagePath;
    final fullPath =
        pending?.stored.fullImagePath ?? editing?.referenceFullImagePath;
    final imageUrl = pending == null ? existingUrl : null;
    final previewPath = fullPath ?? (imageUrl == null ? localPath : null);
    final canPreview = !busy && (previewPath != null || imageUrl != null);
    final placeholder = Icon(Symbols.image_rounded, color: c.textTertiary);
    final imageSource = context.select<SettingsStore, AnitabiImageSource>(
      (s) => s.settings.anitabiImageSource,
    );

    final preview = Tooltip(
      message: canPreview ? '查看大图' : '暂无参考图',
      child: ClipRRect(
        borderRadius: Radii.smAll,
        child: Container(
          width: 104,
          height: 78,
          color: c.surfaceMuted,
          child: MiriaPressable(
            onTap: canPreview
                ? () => onPreview(path: previewPath, url: imageUrl)
                : null,
            semanticLabel: canPreview ? '查看大图' : '暂无参考图',
            child: pending != null
                ? Image.memory(
                    pending.thumbnailBytes,
                    key: const ValueKey('manual-reference-preview'),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => placeholder,
                  )
                : ReferenceThumbnail(
                    localPath: localPath,
                    imageUrl: imageUrl,
                    imageSource: imageSource,
                    placeholder: placeholder,
                  ),
          ),
        ),
      ),
    );

    return AddFormSection(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            preview,
            const SizedBox(width: Space.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('参考图片', style: text.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    hasPending
                        ? '已选择新图片，保存后生效。'
                        : hasExisting
                        ? '当前参考图，重新选择后需保存才会生效。'
                        : '可选，保存时会复制到 App 本地目录。',
                    key: const ValueKey('point-form-reference-status'),
                    style: text.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.x3),
        Wrap(
          spacing: Space.x2,
          runSpacing: Space.x2,
          children: [
            MiriaButton.secondary(
              key: const ValueKey('point-form-pick-image'),
              label: hasImage ? '重新选择' : '上传参考图',
              icon: Symbols.photo_library_rounded,
              size: MiriaButtonSize.sm,
              loading: edit.isPicking,
              onPressed: busy ? null : onPick,
            ),
            if (hasPending)
              MiriaButton.ghost(
                key: const ValueKey('point-form-remove-image'),
                label: '移除',
                icon: Symbols.close_rounded,
                size: MiriaButtonSize.sm,
                onPressed: busy ? null : onRemove,
              ),
          ],
        ),
      ],
    );
  }
}
