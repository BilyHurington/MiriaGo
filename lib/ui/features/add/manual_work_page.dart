import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/add/work_service.dart';
import '../../../application/plan_session.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../components/components.dart';
import 'add_widgets.dart';

/// Validator of the old forms: 「请填写此项」.
String? requiredFieldValidator(String? value) =>
    (value?.trim().isEmpty ?? true) ? '请填写此项' : null;

/// 「作品填写指南」 (old `_ManualWorkFillingGuideSheet`).
const manualWorkGuide = FillingGuide(
  key: ValueKey('manual-work-guide'),
  title: '作品填写指南',
  intro: '填写作品本身的信息，点位名称、场景说明和具体地址请在添加点位时录入。',
  items: [
    FillingGuideItem(
      title: '作品名称',
      badge: '必填',
      body: '填写常用中文译名或最容易辨认的名称，不要填写集数或具体场景名。',
      example: '轻音少女',
    ),
    FillingGuideItem(
      title: '作品原名',
      badge: '选填',
      body: '可填写官方日文、英文或其他原始标题；没有可靠信息时可以留空。',
      example: 'けいおん！',
    ),
    FillingGuideItem(
      title: '作品类型',
      badge: '必填',
      body: '选择最接近作品发行形式的类型，方便在作品列表中辨认和筛选。',
      example: '动画',
    ),
    FillingGuideItem(
      title: '主要地区',
      badge: '选填',
      body: '填写主要发生地或取景城市，可使用“城市 / 区域”的简洁格式；留空时沿用当前计划地区。',
      example: '京都市 / 宇治市',
    ),
  ],
  tip: '保存作品后，表单会清空以便继续添加。作品不会自动生成点位，可随后使用“手动添加点位”录入巡礼地点。',
);

/// 「手动添加作品」 (old `ManualWorkFormScreen`). Stays on the page after
/// saving so several works can be added in a row.
class ManualWorkPage extends StatefulWidget {
  const ManualWorkPage({super.key});

  @override
  State<ManualWorkPage> createState() => _ManualWorkPageState();
}

class _ManualWorkPageState extends State<ManualWorkPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _subtitle = TextEditingController();
  final _city = TextEditingController();
  BangumiSubjectType _type = BangumiSubjectType.anime;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _saving) return;
    setState(() => _saving = true);
    final result = await WorkService(context.read<PlanSession>())
        .saveManualWork(
          title: _title.text,
          subtitle: _subtitle.text,
          city: _city.text,
          subjectType: _type,
        );
    if (!mounted) return;
    if (result.work != null) {
      _title.clear();
      _subtitle.clear();
      _city.clear();
      _formKey.currentState?.reset();
    }
    setState(() => _saving = false);
    showAddNotice(context, result.notice);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PlanSession>();
    return MiriaPageScaffold(
      title: '手动添加作品',
      subtitle: session.isReady ? '加入到：${session.plan.name}' : null,
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(top: Space.x2, bottom: Space.x8),
          children: [
            ContentColumn(
              maxWidth: 640,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AddFormSection(
                    children: [
                      MiriaTextField(
                        key: const ValueKey('manual-work-title'),
                        label: '作品名称',
                        required: true,
                        hint: '请输入作品的中文名称',
                        controller: _title,
                        enabled: !_saving,
                        textInputAction: TextInputAction.next,
                        validator: requiredFieldValidator,
                      ),
                      const SizedBox(height: Space.x3),
                      MiriaTextField(
                        key: const ValueKey('manual-work-subtitle'),
                        label: '作品原名',
                        hint: '请输入作品的原名（如日文/英文）',
                        controller: _subtitle,
                        enabled: !_saving,
                        locale: MiriaFonts.japanese,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: Space.x3),
                      const FieldLabel('作品类型', required: true),
                      SelectField<BangumiSubjectType>(
                        key: const ValueKey('manual-work-type'),
                        pickerTitle: '作品类型',
                        options: [
                          for (final type in kBangumiSubjectTypes)
                            SelectOption(value: type, label: type.label),
                        ],
                        value: _type,
                        onChanged: _saving
                            ? null
                            : (type) => setState(() => _type = type),
                      ),
                      const SizedBox(height: Space.x3),
                      MiriaTextField(
                        key: const ValueKey('manual-work-city'),
                        label: '主要地区',
                        hint: '输入作品主要发生或取景的地区',
                        controller: _city,
                        enabled: !_saving,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _save(),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.x4),
                  MiriaButton(
                    key: const ValueKey('manual-work-save'),
                    label: _saving ? '保存中' : '保存作品',
                    icon: Symbols.check_rounded,
                    loading: _saving,
                    expand: true,
                    size: MiriaButtonSize.lg,
                    onPressed: _saving ? null : _save,
                  ),
                  const SizedBox(height: Space.x4),
                  manualWorkGuide,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
