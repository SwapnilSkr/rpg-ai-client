import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:everlore/app/theme/nexus_theme.dart';

/// The standard text field for group creation and editing forms.
/// Restyled per create-flow design audit: no box, underline border,
/// demoted labels, readable hints, prose font for long writing,
/// visual wrapping for single-line fields, and countdown only when <= 20 chars left.
class GroupTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final String? errorText;
  final bool enabled;
  final int? maxLines;
  final int minLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final bool useProseFont;
  final Widget? trailing;
  final TextInputAction? textInputAction;
  final bool wrapSingleLine;
  final TextStyle? style;
  final TextStyle? hintStyle;

  const GroupTextField({
    super.key,
    this.label,
    this.hint,
    required this.initialValue,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines = 1,
    this.maxLength,
    this.keyboardType,
    this.useProseFont = false,
    this.trailing,
    this.textInputAction,
    this.wrapSingleLine = false,
    this.style,
    this.hintStyle,
  });

  @override
  State<GroupTextField> createState() => _GroupTextFieldState();
}

class _GroupTextFieldState extends State<GroupTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.addListener(_handleTextChanged);
  }

  void _handleTextChanged() {
    if (widget.maxLength != null) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant GroupTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final int? remaining = widget.maxLength != null
        ? widget.maxLength! - _controller.text.characters.length
        : null;
    final bool showCounter = remaining != null && remaining <= 20;

    // Remove maxLines caps on long writing (useProseFont) or wrapSingleLine so writing grows
    final effectiveMaxLines = (widget.useProseFont || widget.wrapSingleLine)
        ? null
        : widget.maxLines;

    final effectiveKeyboardType =
        widget.keyboardType ??
        (widget.wrapSingleLine
            ? TextInputType.text
            : (widget.useProseFont ? TextInputType.multiline : null));

    final effectiveTextInputAction =
        widget.textInputAction ??
        (widget.wrapSingleLine
            ? TextInputAction.done
            : (widget.useProseFont ? TextInputAction.newline : null));

    final textStyle =
        widget.style ??
        (widget.useProseFont
            ? EverloreTheme.aiText.copyWith(
                fontSize: 16,
                height: 1.45,
                color: widget.enabled
                    ? EverloreTheme.parchment
                    : EverloreTheme.ash,
              )
            : EverloreTheme.ui(
                size: 15,
                weight: FontWeight.w500,
                height: 1.4,
                color: widget.enabled
                    ? EverloreTheme.parchment
                    : EverloreTheme.ash,
              ));

    final hintStyle =
        widget.hintStyle ??
        (widget.useProseFont
            ? EverloreTheme.aiText.copyWith(
                fontSize: 16,
                height: 1.45,
                color: EverloreTheme.ash.withValues(alpha: 0.75),
              )
            : EverloreTheme.ui(
                size: 15,
                height: 1.4,
                color: EverloreTheme.ash.withValues(alpha: 0.75),
              ));

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label != null || widget.trailing != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.label != null)
                    Expanded(
                      child: Text(
                        widget.label!,
                        style: EverloreTheme.ui(
                          size: 12,
                          weight: FontWeight.w500,
                          color: widget.enabled
                              ? EverloreTheme.ash
                              : EverloreTheme.ash.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  if (widget.trailing != null) widget.trailing!,
                ],
              ),
            ),
          TextField(
            controller: _controller,
            onChanged: widget.onChanged,
            enabled: widget.enabled,
            maxLines: effectiveMaxLines,
            minLines: widget.minLines,
            maxLength: widget.maxLength,
            keyboardType: effectiveKeyboardType,
            textInputAction: effectiveTextInputAction,
            inputFormatters: widget.wrapSingleLine
                ? [FilteringTextInputFormatter.deny(RegExp(r'[\r\n]'))]
                : null,
            style: textStyle,
            cursorColor: EverloreTheme.gold,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: hintStyle,
              counterText: '',
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 0,
                vertical: 8,
              ),
              border: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: hasError
                      ? EverloreTheme.crimson
                      : EverloreTheme.white10,
                  width: 1.0,
                ),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: hasError
                      ? EverloreTheme.crimson
                      : EverloreTheme.white10,
                  width: 1.0,
                ),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: hasError ? EverloreTheme.crimson : EverloreTheme.gold,
                  width: 1.5,
                ),
              ),
              errorBorder: const UnderlineInputBorder(
                borderSide: BorderSide(
                  color: EverloreTheme.crimson,
                  width: 1.0,
                ),
              ),
              focusedErrorBorder: const UnderlineInputBorder(
                borderSide: BorderSide(
                  color: EverloreTheme.crimson,
                  width: 1.5,
                ),
              ),
              disabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: EverloreTheme.white10.withValues(alpha: 0.5),
                  width: 1.0,
                ),
              ),
            ),
          ),
          if (hasError || showCounter)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasError)
                    Expanded(
                      child: Text(
                        widget.errorText!,
                        style: EverloreTheme.ui(
                          size: 12,
                          color: EverloreTheme.crimson,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (showCounter) ...[
                    if (hasError) const SizedBox(width: 8),
                    Text(
                      '$remaining left',
                      style: EverloreTheme.ui(
                        size: 11,
                        color: EverloreTheme.ash,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
