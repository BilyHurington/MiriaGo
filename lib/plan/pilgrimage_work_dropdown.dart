import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'pilgrimage_models.dart';

class PilgrimageWorkDropdown extends StatelessWidget {
  const PilgrimageWorkDropdown({
    required this.works,
    required this.value,
    required this.onChanged,
    this.validator,
    super.key,
  });

  final List<PilgrimageWork> works;
  final PilgrimageWork? value;
  final ValueChanged<PilgrimageWork?>? onChanged;
  final FormFieldValidator<PilgrimageWork>? validator;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: AppColors.accent.withValues(alpha: 0.075),
        splashColor: Colors.transparent,
      ),
      child: DropdownButtonFormField<PilgrimageWork>(
        key: ValueKey(value?.id),
        initialValue: value,
        decoration: _decoration(),
        isExpanded: true,
        elevation: 2,
        borderRadius: BorderRadius.circular(8),
        dropdownColor: AppColors.surface,
        menuMaxHeight: 360,
        icon: const Padding(
          padding: EdgeInsets.only(right: 8),
          child: Icon(Icons.keyboard_arrow_down_rounded, size: 20),
        ),
        selectedItemBuilder: (context) => [
          for (final work in works) _WorkDropdownItem(work: work),
        ],
        items: [
          for (final work in works)
            DropdownMenuItem<PilgrimageWork>(
              value: work,
              child: _WorkDropdownItem(
                work: work,
                selected: work.id == value?.id,
                menuItem: true,
              ),
            ),
        ],
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }

  InputDecoration _decoration() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: AppColors.surface,
      hoverColor: AppColors.accent.withValues(alpha: 0.035),
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
}

class _WorkDropdownItem extends StatefulWidget {
  const _WorkDropdownItem({
    required this.work,
    this.selected = false,
    this.menuItem = false,
  });

  final PilgrimageWork work;
  final bool selected;
  final bool menuItem;

  @override
  State<_WorkDropdownItem> createState() => _WorkDropdownItemState();
}

class _WorkDropdownItemState extends State<_WorkDropdownItem> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final work = widget.work;
    final selected = widget.selected;
    final highlighted = selected || _hovered;
    final badgeLabel =
        work.displayBangumiSubjectType?.label ??
        (work.source == WorkSource.manual ? '手动' : '作品');

    final item = AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: highlighted ? 12 : 0,
        vertical: widget.menuItem ? 7 : 0,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.42),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badgeLabel,
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.15,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              work.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                letterSpacing: 0,
              ),
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 8),
            Icon(Icons.check_circle, color: AppColors.accent, size: 18),
          ],
        ],
      ),
    );

    final content = highlighted
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -8,
                top: 0,
                right: -8,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(
                      alpha: selected ? 0.1 : 0.05,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              item,
            ],
          )
        : item;

    return MouseRegion(
      onEnter: widget.menuItem && !selected
          ? (_) => setState(() => _hovered = true)
          : null,
      onExit: widget.menuItem && !selected
          ? (_) => setState(() => _hovered = false)
          : null,
      child: content,
    );
  }
}
