import 'package:flutter/material.dart';
import '../../../../core/telemetry/telemetry.dart';
import '../../../../../app/theme/nexus_theme.dart';
import '../../../../../shared/models/world_template.dart';
import '../../../../../shared/widgets/everlore_sheet.dart';

/// Modal sheet for publishing a world as private or public.
///
/// Under the Oct 15 2026 contract:
/// - "Just for you": private, playable at once, visible only to creator.
/// - "For every traveller": public, reviewed by admin first before Discover.
class PublishWorldSheet extends StatefulWidget {
  final WorldTemplate template;
  final String initialVisibility;
  final Future<bool> Function(String visibility)? onPublish;
  final String noun;
  final bool allowPublic;
  final String? publicDisabledReason;
  final bool choiceButtonLabels;

  const PublishWorldSheet({
    super.key,
    required this.template,
    this.initialVisibility = 'private',
    this.onPublish,
    this.noun = 'world',
    this.allowPublic = true,
    this.publicDisabledReason,
    this.choiceButtonLabels = false,
  });

  static Future<bool?> show(
    BuildContext context,
    WorldTemplate template, {
    String initialVisibility = 'private',
    Future<bool> Function(String visibility)? onPublish,
    String noun = 'world',
    bool allowPublic = true,
    String? publicDisabledReason,
    bool choiceButtonLabels = false,
  }) {
    Telemetry.instance.sheet('publish');
    return showEverloreSheet<bool>(
      context: context,
      builder: (_) => PublishWorldSheet(
        template: template,
        initialVisibility: initialVisibility,
        onPublish: onPublish,
        noun: noun,
        allowPublic: allowPublic,
        publicDisabledReason: publicDisabledReason,
        choiceButtonLabels: choiceButtonLabels,
      ),
    );
  }

  @override
  State<PublishWorldSheet> createState() => PublishWorldSheetState();
}

class PublishWorldSheetState extends State<PublishWorldSheet> {
  late String _selectedVisibility;
  bool _isSubmitting = false;
  String? _error;

  String get selectedVisibility => _selectedVisibility;

  @override
  void initState() {
    super.initState();
    _selectedVisibility =
        (!widget.allowPublic && widget.initialVisibility == 'public')
        ? 'private'
        : widget.initialVisibility;
  }

  Future<void> _handlePublish() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      if (widget.onPublish != null) {
        final success = await widget.onPublish!(_selectedVisibility);
        if (!mounted) return;
        if (success) {
          Navigator.of(context).pop(true);
          return;
        } else {
          setState(() {
            _isSubmitting = false;
            _error = 'Could not publish right now. Please try again.';
          });
          return;
        }
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _error = 'Could not publish right now. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGroup = widget.noun == 'group';
    final sheetTitle = isGroup
        ? 'Who can join this group?'
        : 'Who can enter this world?';
    final privateDesc = isGroup
        ? 'Ready to chat now. Only you will see it.'
        : 'Ready to play now. Only you will see it.';
    final publicTitle = isGroup ? 'For everyone' : 'For every traveller';
    final publicDesc = isGroup
        ? 'We read every shared group first, usually within a day. You can chat in it while you wait.'
        : 'We read every shared world first, usually within a day. You can play it while you wait.';

    final String actionText;
    if (widget.choiceButtonLabels) {
      actionText = _selectedVisibility == 'public'
          ? 'Share with everyone'
          : 'Keep it just for me';
    } else {
      actionText = 'Publish';
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetGrabHandle(),
            const SizedBox(height: 12),
            Text(
              sheetTitle,
              style: EverloreTheme.serifDisplay(
                size: 20,
                color: EverloreTheme.parchment,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You can change this later.',
              style: EverloreTheme.ui(size: 13, color: EverloreTheme.ash),
            ),
            const SizedBox(height: 20),
            _VisibilityOption(
              value: 'private',
              groupValue: _selectedVisibility,
              title: 'Just for you',
              description: privateDesc,
              onTap: _isSubmitting
                  ? null
                  : () => setState(() => _selectedVisibility = 'private'),
            ),
            const SizedBox(height: 12),
            _VisibilityOption(
              value: 'public',
              groupValue: _selectedVisibility,
              title: publicTitle,
              description: publicDesc,
              enabled: widget.allowPublic,
              disabledNote: widget.allowPublic
                  ? null
                  : (widget.publicDisabledReason ??
                        'Every person needs a face first.'),
              onTap: (_isSubmitting || !widget.allowPublic)
                  ? null
                  : () => setState(() => _selectedVisibility = 'public'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: const TextStyle(
                  color: EverloreTheme.crimson,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _handlePublish,
                style: FilledButton.styleFrom(
                  backgroundColor: EverloreTheme.gold,
                  foregroundColor: EverloreTheme.void0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: EverloreTheme.void0,
                        ),
                      )
                    : Text(
                        actionText,
                        style: EverloreTheme.ui(
                          size: 15,
                          weight: FontWeight.w700,
                          color: EverloreTheme.void0,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisibilityOption extends StatelessWidget {
  final String value;
  final String groupValue;
  final String title;
  final String description;
  final bool enabled;
  final String? disabledNote;
  final VoidCallback? onTap;

  const _VisibilityOption({
    required this.value,
    required this.groupValue,
    required this.title,
    required this.description,
    this.enabled = true,
    this.disabledNote,
    this.onTap,
  });

  bool get isSelected => value == groupValue;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isSelected
        ? EverloreTheme.gold.withValues(alpha: 0.08)
        : (enabled
              ? EverloreTheme.void1.withValues(alpha: 0.6)
              : EverloreTheme.void1.withValues(alpha: 0.3));

    final effectiveBorderColor = isSelected
        ? EverloreTheme.gold
        : (enabled
              ? EverloreTheme.void3.withValues(alpha: 0.8)
              : EverloreTheme.void3.withValues(alpha: 0.4));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: effectiveColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: effectiveBorderColor,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? EverloreTheme.gold
                        : (enabled
                              ? EverloreTheme.ash.withValues(alpha: 0.6)
                              : EverloreTheme.ash.withValues(alpha: 0.25)),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: EverloreTheme.gold,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: EverloreTheme.ui(
                        size: 15,
                        color: enabled
                            ? EverloreTheme.parchment
                            : EverloreTheme.ash,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: EverloreTheme.aiText.copyWith(
                        fontSize: 13,
                        color: enabled
                            ? EverloreTheme.ash
                            : EverloreTheme.ash.withValues(alpha: 0.6),
                        height: 1.4,
                      ),
                    ),
                    if (disabledNote != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        disabledNote!,
                        style: EverloreTheme.ui(
                          size: 12,
                          color: EverloreTheme.ash.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
