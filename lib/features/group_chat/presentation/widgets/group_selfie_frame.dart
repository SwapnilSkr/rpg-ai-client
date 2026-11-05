import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/widgets/everlore_network_image.dart';
import '../../../media/models/turn_media.dart';
import '../../../media/presentation/media_viewer_sheet.dart';
import '../../../moderation/presentation/report_sheet.dart';
import '../../../play/presentation/widgets/anchored_menu_popup.dart';
import '../../models/group_chat_models.dart';

/// Portrait frame displaying a character's selfie under their spoken line.
///
/// Has fixed dimensions (200x356, 9:16 portrait) across all states to prevent
/// list jumps when the image loads.
class GroupSelfieFrame extends StatelessWidget {
  static const double frameWidth = 200.0;
  static const double frameHeight = 356.0;

  /// Words alone: only a picture on its way needs the full height held for it.
  static const double messageHeight = 132.0;

  /// Widget tests turn this off: an endless pulse never lets `pumpAndSettle`
  /// finish.
  @visibleForTesting
  static bool animatePending = true;

  final GroupLine line;
  final GroupMember? member;
  final VoidCallback? onRequestSelfie;
  final void Function(GroupLine line, String mediaId, String speakerName)?
      onReportSelfie;
  final double? Function()? composerTop;
  final DateTime? now;

  const GroupSelfieFrame({
    super.key,
    required this.line,
    this.member,
    this.onRequestSelfie,
    this.onReportSelfie,
    this.composerTop,
    this.now,
  });

  String get _displayName => line.name.isNotEmpty
      ? line.name
      : (member?.name ?? 'Someone');

  void _openViewer(BuildContext context, GroupSelfie selfie) {
    if (selfie.url == null || selfie.url!.isEmpty) return;
    MediaViewerSheet.show(
      context,
      TurnMedia(
        mediaId: selfie.mediaId ?? '',
        kind: MediaKind.picture,
        status: MediaStatus.ready,
        url: selfie.url,
      ),
    );
  }

  void _openMenu(BuildContext frameContext, GroupSelfie selfie) {
    final mediaId = selfie.mediaId;
    if (mediaId == null || mediaId.isEmpty) return;

    HapticFeedback.lightImpact();
    final rect = globalRectOf(frameContext);

    showAnchoredMenu<void>(
      context: frameContext,
      anchorRect: rect,
      composerTop: composerTop?.call(),
      items: [
        AnchoredMenuItem(
          icon: const Icon(
            Icons.flag_outlined,
            color: EverloreTheme.crimson,
            size: 16,
          ),
          label: 'Report',
          onTap: () {
            if (!frameContext.mounted) return;
            if (onReportSelfie != null) {
              onReportSelfie!(line, mediaId, _displayName);
            } else {
              showReportSelfieSheet(
                frameContext,
                mediaId: mediaId,
                speakerName: _displayName,
              );
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selfie = line.selfie;
    if (selfie == null) return const SizedBox.shrink();

    final currentTime = now ?? DateTime.now();

    return switch (selfie.status) {
      SelfieStatus.queued || SelfieStatus.processing => const _ShimmerFrame(),
      SelfieStatus.ready => _buildReadyFrame(context, selfie),
      SelfieStatus.failed || SelfieStatus.unseen => _buildFailedFrame(),
      SelfieStatus.resting =>
        selfie.isRestingAt(currentTime)
            ? _buildRestingActiveFrame(context, selfie, currentTime)
            : _buildRestingExpiredFrame(),
    };
  }

  Widget _buildReadyFrame(BuildContext context, GroupSelfie selfie) {
    final url = selfie.url ?? '';
    return Builder(
      builder: (frameContext) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openViewer(frameContext, selfie),
        onLongPress: () => _openMenu(frameContext, selfie),
        child: Container(
          width: frameWidth,
          height: frameHeight,
          decoration: BoxDecoration(
            color: EverloreTheme.void2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: EverloreTheme.white10,
              width: 0.9,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: EverloreNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildFailedFrame() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onRequestSelfie,
      child: Container(
        width: frameWidth,
        height: messageHeight,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: EverloreTheme.void2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: EverloreTheme.white10,
            width: 0.9,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "This picture didn't come through.",
                textAlign: TextAlign.center,
                style: EverloreTheme.aiText.copyWith(
                  fontSize: 14,
                  color: EverloreTheme.ash,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Tap to try again',
                textAlign: TextAlign.center,
                style: EverloreTheme.caption.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: EverloreTheme.goldDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestingActiveFrame(
    BuildContext context,
    GroupSelfie selfie,
    DateTime currentTime,
  ) {
    final resetsAtLocal = selfie.resetsAtLocal;
    final timeStr = resetsAtLocal != null
        ? TimeOfDay.fromDateTime(resetsAtLocal).format(context)
        : '';
    final localNow = currentTime.toLocal();
    final isDifferentDay = resetsAtLocal != null &&
        (resetsAtLocal.year != localNow.year ||
            resetsAtLocal.month != localNow.month ||
            resetsAtLocal.day != localNow.day);

    final restingText = isDifferentDay
        ? 'More pictures tomorrow at $timeStr'
        : 'More pictures at $timeStr';

    return Container(
      width: frameWidth,
      height: messageHeight,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: EverloreTheme.void2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: EverloreTheme.white10,
          width: 0.9,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              restingText,
              textAlign: TextAlign.center,
              style: EverloreTheme.aiText.copyWith(
                fontSize: 14,
                color: EverloreTheme.ash,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestingExpiredFrame() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onRequestSelfie,
      child: Container(
        width: frameWidth,
        height: messageHeight,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: EverloreTheme.void2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: EverloreTheme.white10,
            width: 0.9,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tap for the picture',
                textAlign: TextAlign.center,
                style: EverloreTheme.aiText.copyWith(
                  fontSize: 14,
                  color: EverloreTheme.parchment,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quiet shimmer placeholder while a selfie is being generated.
class _ShimmerFrame extends StatefulWidget {
  const _ShimmerFrame();

  @override
  State<_ShimmerFrame> createState() => _ShimmerFrameState();
}

class _ShimmerFrameState extends State<_ShimmerFrame>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (GroupSelfieFrame.animatePending) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1600),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return Container(
        width: GroupSelfieFrame.frameWidth,
        height: GroupSelfieFrame.frameHeight,
        decoration: BoxDecoration(
          color: EverloreTheme.void3,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: EverloreTheme.white10,
            width: 0.9,
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, _) {
        final t = _controller!.value;
        return Container(
          width: GroupSelfieFrame.frameWidth,
          height: GroupSelfieFrame.frameHeight,
          decoration: BoxDecoration(
            color: Color.lerp(EverloreTheme.void3, EverloreTheme.void2, t),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Color.lerp(
                EverloreTheme.white10,
                EverloreTheme.goldDim.withValues(alpha: 0.22),
                t,
              )!,
              width: 0.9,
            ),
          ),
        );
      },
    );
  }
}
