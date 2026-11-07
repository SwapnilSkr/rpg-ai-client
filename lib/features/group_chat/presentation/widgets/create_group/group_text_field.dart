import 'package:flutter/material.dart';

import 'package:everlore/app/theme/nexus_theme.dart';

/// The standard text field for group creation and editing forms.
class GroupTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final String? errorText;
  final bool enabled;
  final int maxLines;
  final int minLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final bool useProseFont;
  final Widget? trailing;

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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label != null || widget.trailing != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.label != null)
                    Expanded(
                      child: Text(
                        widget.label!,
                        style: EverloreTheme.ui(
                          size: 13,
                          color: widget.enabled
                              ? EverloreTheme.parchment
                              : EverloreTheme.ash,
                          weight: FontWeight.w600,
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
            maxLines: widget.maxLines,
            minLines: widget.minLines,
            maxLength: widget.maxLength,
            keyboardType: widget.keyboardType,
            style: widget.useProseFont
                ? EverloreTheme.aiText.copyWith(
                    fontSize: 15,
                    color: widget.enabled
                        ? EverloreTheme.parchment
                        : EverloreTheme.ash,
                    height: 1.4,
                  )
                : EverloreTheme.ui(
                    size: 14,
                    color: widget.enabled
                        ? EverloreTheme.parchment
                        : EverloreTheme.ash,
                    height: 1.4,
                  ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: EverloreTheme.ui(
                size: 13,
                color: EverloreTheme.ash.withValues(alpha: 0.6),
              ),
              counterText: '',
              filled: true,
              fillColor: widget.enabled
                  ? EverloreTheme.void4.withValues(alpha: 0.6)
                  : EverloreTheme.void3.withValues(alpha: 0.3),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: hasError
                      ? EverloreTheme.crimson
                      : EverloreTheme.goldDim.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: hasError
                      ? EverloreTheme.crimson
                      : EverloreTheme.goldDim.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: hasError ? EverloreTheme.crimson : EverloreTheme.gold,
                  width: 1.5,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: EverloreTheme.goldDim.withValues(alpha: 0.1),
                ),
              ),
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: 4),
            Text(
              widget.errorText!,
              style: EverloreTheme.ui(size: 12, color: EverloreTheme.crimson),
            ),
          ],
        ],
      ),
    );
  }
}
