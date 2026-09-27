import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/add/add_dependencies.dart';
import '../../../application/add/work_service.dart';
import '../../../application/plan_session.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../app/router.dart';
import '../../components/components.dart';
import '../works/work_cover.dart';
import 'add_widgets.dart';

/// 「搜索 Bangumi」 (old `BangumiWorkSearchScreen`).
class BangumiSearchPage extends StatefulWidget {
  const BangumiSearchPage({this.continueToImport = false, super.key});

  /// After adding a work, continue into its Anitabi map import.
  final bool continueToImport;

  @override
  State<BangumiSearchPage> createState() => _BangumiSearchPageState();
}

class _BangumiSearchPageState extends State<BangumiSearchPage> {
  final _query = TextEditingController();
  late final BangumiSearchController _controller = BangumiSearchController(
    session: context.read<PlanSession>(),
  );

  @override
  void dispose() {
    _query.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    await _controller.search(_query.text);
  }

  Future<void> _add(PilgrimageWork work) async {
    final notice = await _controller.addWork(work);
    if (notice == null || !mounted) return;
    showAddNotice(context, notice);
    final bangumiId = work.bangumiId;
    if (widget.continueToImport &&
        notice.kind == AddNoticeKind.success &&
        bangumiId != null) {
      // Δ2: go straight into the chosen work's map.
      context.pushReplacement(Routes.anitabiImportFor(bangumiId: bangumiId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PlanSession>();
    final wide = !context.layout.isCompact;
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final controller = _controller;
        final results = controller.results;
        return MiriaPageScaffold(
          title: '搜索 Bangumi',
          subtitle: session.isReady ? '加入到：${session.plan.name}' : null,
          body: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(top: Space.x2, bottom: Space.x8),
            children: [
              ContentColumn(
                maxWidth: wide ? 960 : WindowLayout.readingWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AddFormSection(
                      children: [
                        Text('作品名称', style: context.text.titleSmall),
                        const SizedBox(height: Space.x2),
                        SearchField(
                          key: const ValueKey('bangumi-search-field'),
                          controller: _query,
                          hint: '例如：轻音少女',
                          onSubmitted: (_) => _search(),
                        ),
                        const SizedBox(height: Space.x4),
                        MiriaButton(
                          key: const ValueKey('bangumi-search-button'),
                          label: controller.isSearching ? '搜索中' : '搜索作品',
                          icon: Symbols.search_rounded,
                          loading: controller.isSearching,
                          expand: true,
                          onPressed: controller.isSearching ? null : _search,
                        ),
                        const SizedBox(height: Space.x3),
                        _TypeFilter(controller: controller),
                        if (results.isEmpty && controller.error == null) ...[
                          const SizedBox(height: Space.x4),
                          const _SearchHint(),
                        ],
                      ],
                    ),
                    const SizedBox(height: Space.x3),
                    if (controller.error != null)
                      const InfoBanner(
                        kind: InfoBannerKind.error,
                        message: 'Bangumi 搜索失败，请检查网络后重试。',
                      )
                    else if (results.isNotEmpty)
                      AdaptiveGrid(
                        minTileWidth: 340,
                        minColumns: 1,
                        spacing: Space.x2,
                        children: [
                          for (final work in results)
                            _WorkResultCard(
                              key: ValueKey('bangumi-result-${work.id}'),
                              work: work,
                              added: controller.hasWork(work),
                              disabled: controller.isAdding,
                              onAdd: () => _add(work),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TypeFilter extends StatelessWidget {
  const _TypeFilter({required this.controller});

  final BangumiSearchController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final expanded = controller.typeFilterExpanded;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: Radii.smAll,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MiriaPressable(
            key: const ValueKey('bangumi-type-filter-toggle'),
            onTap: controller.toggleTypeFilter,
            semanticLabel: '筛选作品类型',
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.x3,
                  vertical: Space.x2,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text('筛选作品类型', style: text.labelLarge)),
                    Text(
                      '已选 ${controller.selectedTypes.length} 项',
                      style: text.caption.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(width: Space.x1),
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
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.x3,
                      0,
                      Space.x3,
                      Space.x3,
                    ),
                    child: ChipGroup<BangumiSubjectType>(
                      semanticLabel: '作品类型',
                      options: [
                        for (final type in kBangumiSubjectTypes)
                          ChipOption(value: type, label: type.label),
                      ],
                      selected: controller.selectedTypes,
                      onChanged: controller.setTypes,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Symbols.help_rounded, size: 18, color: c.primary),
            const SizedBox(width: Space.x2),
            Expanded(child: Text('搜索说明', style: text.labelLarge)),
          ],
        ),
        const SizedBox(height: Space.x1),
        Padding(
          padding: const EdgeInsets.only(left: 26),
          child: Text(
            '输入作品名后搜索，选择结果即可加入当前计划。',
            style: text.bodySmall?.copyWith(color: c.textSecondary),
          ),
        ),
        const SizedBox(height: Space.x1),
        Padding(
          padding: const EdgeInsets.only(left: 26),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(Symbols.info_rounded, size: 16, color: c.warning),
              ),
              const SizedBox(width: Space.x1),
              Expanded(
                child: Text(
                  'Bangumi需要国际网络环境才能正常搜索。',
                  style: text.bodySmall?.copyWith(color: c.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WorkResultCard extends StatefulWidget {
  const _WorkResultCard({
    required this.work,
    required this.added,
    required this.disabled,
    required this.onAdd,
    super.key,
  });

  final PilgrimageWork work;
  final bool added;
  final bool disabled;
  final VoidCallback onAdd;

  @override
  State<_WorkResultCard> createState() => _WorkResultCardState();
}

class _WorkResultCardState extends State<_WorkResultCard> {
  bool _titleExpanded = false;
  bool _subtitleExpanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final work = widget.work;
    final showSubtitle = showsWorkSubtitle(work);
    final type = work.displayBangumiSubjectType;
    final button = widget.added
        ? MiriaButton(
            label: '已添加',
            icon: Symbols.check_rounded,
            variant: MiriaButtonVariant.tonal,
            size: MiriaButtonSize.sm,
            onPressed: null,
          )
        : MiriaButton.secondary(
            label: '加入',
            icon: Symbols.add_rounded,
            size: MiriaButtonSize.sm,
            onPressed: widget.disabled ? null : widget.onAdd,
          );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MiriaPressable(
          onTap: () => setState(() => _titleExpanded = !_titleExpanded),
          borderRadius: Radii.xsAll,
          child: Text(
            work.title,
            maxLines: _titleExpanded ? null : 1,
            overflow: _titleExpanded
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
            style: text.titleSmall,
          ),
        ),
        const SizedBox(height: 2),
        MiriaPressable(
          onTap: showSubtitle
              ? () => setState(() => _subtitleExpanded = !_subtitleExpanded)
              : null,
          borderRadius: Radii.xsAll,
          child: Text(
            showSubtitle ? work.subtitle.trim() : kNoWorkSubtitle,
            maxLines: showSubtitle && _subtitleExpanded ? null : 1,
            overflow: showSubtitle && _subtitleExpanded
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
            locale: MiriaFonts.japanese,
            style: text.bodySmall?.copyWith(
              color: showSubtitle ? c.textSecondary : c.textTertiary,
            ),
          ),
        ),
        if (type != null) ...[
          const SizedBox(height: Space.x1),
          Tag(label: type.label, tone: MiriaTone.primary),
        ],
      ],
    );
    return MiriaCard(
      padding: const EdgeInsets.all(Space.x3),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.4;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WorkCover(work: work, width: 52, height: 72),
              const SizedBox(width: Space.x3),
              Expanded(
                child: stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          details,
                          const SizedBox(height: Space.x2),
                          button,
                        ],
                      )
                    : details,
              ),
              if (!stacked) ...[const SizedBox(width: Space.x3), button],
            ],
          );
        },
      ),
    );
  }
}
