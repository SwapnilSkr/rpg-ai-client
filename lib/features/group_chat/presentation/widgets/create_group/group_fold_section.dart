import 'package:flutter/material.dart';

import 'package:everlore/app/theme/nexus_theme.dart';

/// An expandable section fold for group story and editor details.
/// Title ui(15, w600), one-line summary in aiText 14 ash, chevron; 60 dp closed.
/// Opens with AnimatedSize. Stacked inside one cardDecoration card with white10 hairlines.
/// Any error inside opens it and shows a crimson 6 dp dot.
class GroupFoldSection extends StatefulWidget {
  final String title;
  final String? summary;
  final Widget child;
  final bool hasError;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;
  final EdgeInsetsGeometry? contentPadding;

  const GroupFoldSection({
    super.key,
    required this.title,
    this.summary,
    required this.child,
    this.hasError = false,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
    this.contentPadding,
  });

  @override
  State<GroupFoldSection> createState() => _GroupFoldSectionState();
}

class _GroupFoldSectionState extends State<GroupFoldSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.hasError || widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant GroupFoldSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasError && !oldWidget.hasError) {
      _isExpanded = true;
    }
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    widget.onExpansionChanged?.call(_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggle,
            child: SizedBox(
              height: 60,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (widget.hasError) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: EverloreTheme.crimson,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: EverloreTheme.ui(
                                size: 15,
                                weight: FontWeight.w600,
                                color: EverloreTheme.parchment,
                              ),
                            ),
                          ),
                          if (widget.summary != null &&
                              widget.summary!.isNotEmpty &&
                              !_isExpanded) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                widget.summary!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: EverloreTheme.aiText.copyWith(
                                  fontSize: 14,
                                  color: EverloreTheme.ash,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.25 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: EverloreTheme.ash,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _isExpanded
              ? Padding(
                  padding:
                      widget.contentPadding ??
                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: widget.child,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// A container card styling stacked [GroupFoldSection]s with EverloreTheme.cardDecoration
/// and white10 hairlines between sections.
class GroupFoldCard extends StatelessWidget {
  final List<Widget> sections;

  const GroupFoldCard({super.key, required this.sections});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: EverloreTheme.cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                color: EverloreTheme.white10,
              ),
            sections[i],
          ],
        ],
      ),
    );
  }
}
