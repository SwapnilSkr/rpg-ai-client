import 'package:flutter/material.dart';
import '../../../app/theme/nexus_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/widgets/everlore_notice.dart';
import '../data/moderation_repository.dart';

/// Opens the report flow for a world.
///
/// Returns true when a report was filed, so the caller can also drop the world
/// out of the list the player is looking at.
Future<bool> showReportWorldSheet(
  BuildContext context, {
  required String worldId,
  required String worldTitle,
}) async {
  final filed = await showModalBottomSheet<bool>(
      useRootNavigator: true,
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ReportSheet(
      targetType: 'world',
      targetId: worldId,
      targetTitle: worldTitle,
    ),
  );
  return filed ?? false;
}

/// Opens the report flow for a creator.
Future<bool> showReportCreatorSheet(
  BuildContext context, {
  required String creatorId,
  required String creatorLabel,
}) async {
  final filed = await showModalBottomSheet<bool>(
      useRootNavigator: true,
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ReportSheet(
      targetType: 'user',
      targetId: creatorId,
      targetTitle: creatorLabel,
    ),
  );
  return filed ?? false;
}

class _ReportSheet extends StatefulWidget {
  final String targetType;
  final String targetId;
  final String targetTitle;

  const _ReportSheet({
    required this.targetType,
    required this.targetId,
    required this.targetTitle,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason? _reason;
  final _detailsController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_reason == null) return false;
    // "Something else" is only actionable with the player's own words.
    if (_reason == ReportReason.other) {
      return _detailsController.text.trim().isNotEmpty;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ModerationRepository.report(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reason: _reason!,
        details: _detailsController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      showEverloreNotice(
        context,
        'Report sent. Our team will review it.',
        tone: NoticeTone.success,
        icon: Icons.shield_outlined,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not send the report. Check your connection and retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // The sheet has to stay usable with the keyboard up while the details field
    // is focused, so it is sized against the visible viewport rather than the
    // full screen.
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: const BoxDecoration(
            color: EverloreTheme.void2,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetGrabber(),
              _header(),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  children: [
                    for (final reason in ReportReason.values)
                      _ReasonTile(
                        reason: reason,
                        selected: _reason == reason,
                        onTap: () => setState(() => _reason = reason),
                      ),
                    const SizedBox(height: 16),
                    _detailsField(),
                  ],
                ),
              ),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Report this ${widget.targetType == 'user' ? 'creator' : 'world'}',
                  style: EverloreTheme.serifDisplay(
                    size: 21,
                    color: EverloreTheme.parchment,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(false),
                icon: const Icon(
                  Icons.close_rounded,
                  color: EverloreTheme.ash,
                  size: 20,
                ),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            widget.targetTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EverloreTheme.ui(
              size: 13,
              color: EverloreTheme.gold,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Reports are private — the creator is never told who reported them. '
            'Anything that breaks our rules is removed.',
            style: EverloreTheme.ui(
              size: 12.5,
              color: EverloreTheme.ash,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsField() {
    final required = _reason == ReportReason.other;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          required ? 'WHAT IS WRONG?' : 'ANYTHING TO ADD? (OPTIONAL)',
          style: EverloreTheme.sectionHeader,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _detailsController,
          maxLines: 4,
          minLines: 3,
          maxLength: 1000,
          onChanged: (_) => setState(() {}),
          style: EverloreTheme.ui(size: 14, color: EverloreTheme.parchment),
          decoration: InputDecoration(
            hintText: required
                ? 'Describe the problem so we can act on it.'
                : 'Add detail that would help us review this.',
            hintStyle: EverloreTheme.ui(size: 13, color: EverloreTheme.ash),
            counterStyle: EverloreTheme.ui(size: 10, color: EverloreTheme.ash),
            filled: true,
            fillColor: EverloreTheme.void4,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: EverloreTheme.goldDim.withValues(alpha: 0.24),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: EverloreTheme.goldDim.withValues(alpha: 0.24),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: EverloreTheme.gold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorNotice(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: EverloreTheme.crimson.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: EverloreTheme.crimson.withValues(alpha: 0.42),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: EverloreTheme.crimson,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: EverloreTheme.ui(
                size: 12.5,
                color: EverloreTheme.parchment,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: EverloreTheme.void4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The failure has to appear beside the button that caused it. At the
          // end of the scrolling list it rendered below the fold, so a failed
          // send looked like nothing had happened at all.
          if (_error != null) ...[
            _errorNotice(_error!),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canSubmit && !_submitting ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: EverloreTheme.gold,
                foregroundColor: EverloreTheme.void0,
                disabledBackgroundColor: EverloreTheme.void4,
                disabledForegroundColor: EverloreTheme.ash,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: EverloreTheme.void0,
                      ),
                    )
                  : Text(
                      'SEND REPORT',
                      style: EverloreTheme.ui(
                        size: 14,
                        weight: FontWeight.w800,
                        spacing: 1.3,
                        color: _canSubmit
                            ? EverloreTheme.void0
                            : EverloreTheme.ash,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  final ReportReason reason;
  final bool selected;
  final VoidCallback onTap;

  const _ReasonTile({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: selected
              ? EverloreTheme.gold.withValues(alpha: 0.11)
              : EverloreTheme.void3,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(13),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: selected
                      ? EverloreTheme.gold.withValues(alpha: 0.6)
                      : EverloreTheme.goldDim.withValues(alpha: 0.16),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: selected
                          ? EverloreTheme.gold
                          : EverloreTheme.ash.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reason.label,
                          style: EverloreTheme.ui(
                            size: 14,
                            color: EverloreTheme.parchment,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          reason.blurb,
                          style: EverloreTheme.ui(
                            size: 12,
                            color: EverloreTheme.ash,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetGrabber extends StatelessWidget {
  const _SheetGrabber();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 4,
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      decoration: BoxDecoration(
        color: EverloreTheme.ash.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
