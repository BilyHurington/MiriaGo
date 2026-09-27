import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/theme.dart';

/// Search input with a leading search icon and a clear button
/// (tooltip 「清空搜索」) while it has text. Esc clears the text first, then
/// lets the key bubble up (closing a sheet, leaving multi-select).
///
/// ```dart
/// SearchField(hint: '搜索点位', onChanged: (q) => setState(() => query = q))
/// ```
class SearchField extends StatefulWidget {
  const SearchField({
    this.controller,
    this.focusNode,
    this.hint = '搜索',
    this.onChanged,
    this.onSubmitted,
    this.onCleared,
    this.autofocus = false,
    this.enabled = true,
    this.textInputAction = TextInputAction.search,
    super.key,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Called after the clear button / Esc empties the field.
  final VoidCallback? onCleared;
  final bool autofocus;
  final bool enabled;
  final TextInputAction textInputAction;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  TextEditingController? _own;
  TextEditingController get _controller =>
      widget.controller ?? (_own ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _own)?.removeListener(_onText);
      _controller.addListener(_onText);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onText);
    _own?.dispose();
    super.dispose();
  }

  void _onText() => setState(() {});

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    widget.onCleared?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasText = _controller.text.isNotEmpty;
    return CallbackShortcuts(
      bindings: {
        if (hasText) const SingleActivator(LogicalKeyboardKey.escape): _clear,
      },
      child: TextField(
        controller: _controller,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        enabled: widget.enabled,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        textInputAction: widget.textInputAction,
        style: context.text.bodyLarge,
        decoration: InputDecoration(
          hintText: widget.hint,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Space.x3,
            vertical: 11,
          ),
          prefixIcon: Icon(
            Symbols.search_rounded,
            size: 20,
            color: c.textTertiary,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          suffixIcon: hasText
              ? IconButton(
                  tooltip: '清空搜索',
                  onPressed: _clear,
                  icon: Icon(
                    Symbols.cancel_rounded,
                    size: 18,
                    fill: 1,
                    color: c.textTertiary,
                  ),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: Radii.pillAll,
            borderSide: BorderSide(color: c.hairline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: Radii.pillAll,
            borderSide: BorderSide(color: c.hairline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: Radii.pillAll,
            borderSide: BorderSide(color: c.primary, width: 1.6),
          ),
        ),
      ),
    );
  }
}

/// Text field with the label above the box (old `AppDialogField` style):
/// label turns primary while focused, a red `*` marks [required] fields,
/// [helper] / [error] below.
///
/// Works inside a [Form] through [validator].
///
/// ```dart
/// MiriaTextField(
///   label: '点位名称',
///   required: true,
///   controller: nameController,
///   error: nameError,
/// )
/// ```
class MiriaTextField extends StatefulWidget {
  const MiriaTextField({
    this.label,
    this.hint,
    this.helper,
    this.error,
    this.required = false,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.prefixIcon,
    this.suffix,
    this.labelTrailing,
    this.locale,
    super.key,
  });

  final String? label;
  final String? hint;
  final String? helper;

  /// Error text (overrides [validator] output).
  final String? error;
  final bool required;
  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final IconData? prefixIcon;

  /// Widget inside the box at the end (unit text, icon button).
  final Widget? suffix;

  /// Widget at the end of the label line (e.g. a 「粘贴」 button).
  final Widget? labelTrailing;

  /// Input locale (Japanese names).
  final Locale? locale;

  @override
  State<MiriaTextField> createState() => _MiriaTextFieldState();
}

class _MiriaTextFieldState extends State<MiriaTextField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final label = widget.label;
    final hasError = widget.error != null;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (value) => setState(() => _focused = value),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null || widget.labelTrailing != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: ExcludeSemantics(
                      child: Text.rich(
                        TextSpan(
                          text: label ?? '',
                          children: [
                            if (widget.required)
                              TextSpan(
                                text: ' *',
                                style: TextStyle(color: c.danger),
                                semanticsLabel: '（必填）',
                              ),
                          ],
                        ),
                        style: text.labelMedium?.copyWith(
                          color: hasError
                              ? c.danger
                              : _focused
                              ? c.primaryText
                              : c.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  ?widget.labelTrailing,
                ],
              ),
            ),
          Semantics(
            label: label == null
                ? null
                : widget.required
                ? '$label（必填）'
                : label,
            child: TextFormField(
              controller: widget.controller,
              initialValue: widget.controller == null
                  ? widget.initialValue
                  : null,
              focusNode: widget.focusNode,
              onChanged: widget.onChanged,
              onFieldSubmitted: widget.onSubmitted,
              validator: widget.validator,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              inputFormatters: widget.inputFormatters,
              maxLines: widget.obscureText ? 1 : widget.maxLines,
              minLines: widget.minLines,
              maxLength: widget.maxLength,
              obscureText: widget.obscureText,
              enabled: widget.enabled,
              readOnly: widget.readOnly,
              autofocus: widget.autofocus,
              style: text.bodyLarge?.copyWith(
                color: widget.enabled ? c.textPrimary : c.textDisabled,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                helperText: widget.helper,
                helperMaxLines: 3,
                errorText: widget.error,
                errorMaxLines: 3,
                semanticCounterText: '',
                prefixIcon: widget.prefixIcon == null
                    ? null
                    : Icon(widget.prefixIcon, size: 20),
                suffixIcon: widget.suffix == null
                    ? null
                    : Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: widget.suffix,
                      ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 24,
                  minHeight: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
