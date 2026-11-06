import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../core/notifications/on_screen.dart';
import '../../../../shared/widgets/everlore_network_image.dart';
import '../../../play/presentation/widgets/anchored_menu_popup.dart';
import '../../models/group_chat_models.dart';
import '../../state/chats_cubit.dart';
import '../../state/group_chat_cubit.dart';
import '../../state/group_chat_state.dart';
import '../widgets/bond_sheet.dart';
import '../widgets/group_chat_backdrop.dart';
import '../widgets/group_composer.dart';
import '../widgets/group_message_list.dart';
import '../widgets/group_rewind.dart';
import '../widgets/member_avatar.dart';
import '../widgets/push_ask_sheet.dart';

/// Full-screen drifting backdrop for an empty direct thread.
///
/// Drifts very slowly (scale 1.00 to 1.06 over 24 seconds, reversing) around
/// [Transform.scale] inside a [RepaintBoundary] so only the transform repaints,
/// not the tree. Relit with a warm gradient from below, fading to dark background
/// at the bottom third.
class DriftingPortraitBackdrop extends StatefulWidget {
  /// Off in widget tests, where an endless drift would never settle.
  @visibleForTesting
  static bool animateDrift = true;

  final String? portraitUrl;
  final String? fallbackImageUrl;

  const DriftingPortraitBackdrop({
    super.key,
    required this.portraitUrl,
    this.fallbackImageUrl,
  });

  @override
  State<DriftingPortraitBackdrop> createState() =>
      _DriftingPortraitBackdropState();
}

class _DriftingPortraitBackdropState extends State<DriftingPortraitBackdrop>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    if (DriftingPortraitBackdrop.animateDrift) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 24),
      )..repeat(reverse: true);
      _scaleAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.easeInOut),
      );
    } else {
      _scaleAnimation = const AlwaysStoppedAnimation<double>(1.0);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final portrait = widget.portraitUrl?.trim();
    final hasPortrait = portrait != null && portrait.isNotEmpty;
    final url = hasPortrait ? portrait : widget.fallbackImageUrl?.trim();

    final Widget imageLayer;
    if (url != null && url.isNotEmpty) {
      imageLayer = EverloreNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        memCacheWidth: 1440,
        placeholder: const ColoredBox(color: EverloreTheme.void1),
        errorWidget: const ColoredBox(color: EverloreTheme.void1),
      );
    } else {
      imageLayer = const ColoredBox(color: EverloreTheme.void1);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: EverloreTheme.void1),
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  alignment: Alignment.topCenter,
                  child: child,
                );
              },
              child: imageLayer,
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.30, 0.58, 0.72, 1.0],
                colors: [
                  EverloreTheme.void0.withValues(alpha: 0.35),
                  Colors.transparent,
                  const Color(0xFF352010).withValues(alpha: 0.55),
                  EverloreTheme.void1.withValues(alpha: 0.92),
                  EverloreTheme.void1,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Direct thread screen with one character: same list and composer, no `@` and no action toggle.
class DirectThreadScreen extends StatefulWidget {
  final GroupChatCubit cubit;
  final GroupMember member;

  const DirectThreadScreen({
    super.key,
    required this.cubit,
    required this.member,
  });

  @override
  State<DirectThreadScreen> createState() => _DirectThreadScreenState();
}

class _DirectThreadScreenState extends State<DirectThreadScreen> {
  final GlobalKey _composerKey = GlobalKey();
  late final ChatsCubit _chats;
  StreamSubscription<void>? _pushAskSub;

  double? get _composerTop => globalRectOf(_composerKey.currentContext)?.top;

  @override
  void initState() {
    super.initState();
    // Kept in a field: a context can't be read once the State is going away.
    _chats = context.read<ChatsCubit>();
    OnScreen.instance.enter(
      this,
      Place.direct(widget.cubit.instanceId, widget.member.id),
    );
    widget.cubit.selectThread(widget.member.id);
    // The room below hears this too; the first to claim shows the sheet.
    _pushAskSub = widget.cubit.pushAskDue.listen((_) {
      if (mounted) unawaited(PushAskSheet.show(context));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        _chats.markOpened(
          widget.cubit.instanceId,
          memberId: widget.member.id,
        ),
      );
    });
  }

  @override
  void dispose() {
    OnScreen.instance.leave(this);
    unawaited(_pushAskSub?.cancel());
    widget.cubit.selectThread(kGroupThreadKey);
    unawaited(
      _chats.markOpened(widget.cubit.instanceId, memberId: widget.member.id),
    );
    unawaited(_chats.refresh());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GroupChatCubit, GroupChatState>(
      bloc: widget.cubit,
      listenWhen: (prev, curr) =>
          curr.rewindError != null && prev.rewindError != curr.rewindError,
      listener: (context, state) =>
          showGroupRewindError(context, state.rewindError!),
      builder: (context, state) {
        final thread = state.thread(widget.member.id);
        // Not until the thread has loaded: a thread with history must not flash the
        // empty screen on its way in.
        final isEmpty = thread.loaded && thread.lines.isEmpty;
        final currentMember = state.member(widget.member.id) ?? widget.member;

        final typingName = thread.typingId == widget.member.id
            ? currentMember.name
            : null;
        final failedSends = state.failedSends
            .where((f) => f.directWith == widget.member.id)
            .toList();

        final memberMap = {currentMember.id: currentMember};

        final rawPortrait = (currentMember.portraitUrl?.trim().isNotEmpty == true
                ? currentMember.portraitUrl
                : widget.member.portraitUrl)
            ?.trim();
        final portrait = rawPortrait?.isNotEmpty == true ? rawPortrait : null;
        final hasPortrait = portrait != null && portrait.isNotEmpty;
        final backdropUrl = hasPortrait ? portrait : state.imageUrl;
        final backdropAlignment = hasPortrait
            ? const Alignment(0, -0.6)
            : Alignment.center;

        final firstTexts = state.firstTextIdeas(widget.member.id);

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: AnimatedCrossFade(
                duration: const Duration(milliseconds: 400),
                crossFadeState: isEmpty
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: DriftingPortraitBackdrop(
                  portraitUrl: portrait,
                  fallbackImageUrl: state.imageUrl,
                ),
                secondChild: GroupChatBackdrop(
                  imageUrl: backdropUrl,
                  alignment: backdropAlignment,
                ),
                layoutBuilder: (topChild, topChildKey, bottomChild, bottomChildKey) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(key: bottomChildKey, child: bottomChild),
                      Positioned.fill(key: topChildKey, child: topChild),
                    ],
                  );
                },
              ),
            ),
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: isEmpty
                    ? Colors.transparent
                    : EverloreTheme.void0.withValues(alpha: kGroupChromeAlpha),
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: EverloreTheme.ash,
                    size: 18,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: isEmpty
                      ? const SizedBox.shrink(key: ValueKey('empty_header'))
                      : _buildHeaderTitle(
                          currentMember,
                          key: const ValueKey('normal_header'),
                        ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.favorite_outline_rounded,
                      color: EverloreTheme.gold,
                    ),
                    tooltip: 'Bond',
                    onPressed: () => BondSheet.show(
                      context,
                      cubit: widget.cubit,
                      member: currentMember,
                    ),
                  ),
                ],
              ),
              body: Column(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: isEmpty
                          ? _buildEmptyThreadBody(
                              currentMember,
                              firstTexts,
                              key: const ValueKey('empty_body'),
                            )
                          : GroupMessageList(
                              key: const ValueKey('normal_body'),
                              lines: thread.lines,
                              memberMap: memberMap,
                              composerTop: () => _composerTop,
                              onRewindLine: canRewindGroup(state) ? _rewindTo : null,
                              onRequestSelfie: !state.rewinding ? _requestSelfie : null,
                              onCharacterTap: (_) => BondSheet.show(
                                context,
                                cubit: widget.cubit,
                                member: currentMember,
                              ),
                            ),
                    ),
                  ),
                  GroupComposer(
                    key: _composerKey,
                    members: [currentMember],
                    typingName: typingName,
                    failedSends: failedSends,
                    replyIdeas: state.replyIdeasFor(widget.member.id),
                    onSendIdea: (idea) => widget.cubit.sendIdea(
                      idea,
                      directWith: widget.member.id,
                    ),
                    enableMentions: false, // No @ in direct threads
                    enableActionToggle: false, // No action toggle in direct threads
                    onSend: (text, _) {
                      widget.cubit.send(text, directWith: widget.member.id);
                    },
                    onRetryFailed: widget.cubit.retryFailed,
                    onDiscardFailed: widget.cubit.discardFailed,
                  ),
                ],
              ),
            ),
            GroupRewindVeil(active: state.rewinding),
          ],
        );
      },
    );
  }

  Widget _buildHeaderTitle(GroupMember member, {Key? key}) {
    final status = member.status?.trim();
    final hasStatus = status != null && status.isNotEmpty;

    return Row(
      key: key,
      children: [
        MemberAvatar(member: member, size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: hasStatus
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      member.name,
                      style: EverloreTheme.screenTitle.copyWith(
                        fontSize: 16,
                        color: EverloreTheme.parchment,
                      ),
                    ),
                    Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EverloreTheme.caption.copyWith(
                        fontSize: 11,
                        color: EverloreTheme.ash,
                      ),
                    ),
                  ],
                )
              : Text(
                  member.name,
                  style: EverloreTheme.screenTitle.copyWith(
                    fontSize: 16,
                    color: EverloreTheme.parchment,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyThreadBody(
    GroupMember member,
    List<String> firstTexts, {
    Key? key,
  }) {
    final status = member.status?.trim();
    final hasStatus = status != null && status.isNotEmpty;

    return SafeArea(
      key: key,
      top: false,
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            member.name,
                            textAlign: TextAlign.center,
                            style: EverloreTheme.screenTitle.copyWith(
                              fontSize: 24,
                              letterSpacing: 1.2,
                              color: EverloreTheme.parchment,
                            ),
                          ),
                          if (hasStatus) ...[
                            const SizedBox(height: 6),
                            Text(
                              status,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: EverloreTheme.caption.copyWith(
                                fontSize: 13,
                                color: EverloreTheme.ash,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (firstTexts.isNotEmpty) ...[
                      for (final idea in firstTexts.take(3))
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                widget.cubit.sendIdea(
                                  idea,
                                  directWith: widget.member.id,
                                );
                              },
                              child: Ink(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: EverloreTheme.void2.withValues(alpha: 0.82),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: EverloreTheme.goldDim.withValues(alpha: 0.35),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  idea,
                                  style: EverloreTheme.aiText.copyWith(
                                    fontSize: 15,
                                    height: 1.35,
                                    color: EverloreTheme.parchment,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                    ] else ...[
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _rewindTo(GroupLine line) {
    final sequence = line.sequence;
    if (sequence == null) return;
    // The Chats list must not keep a removed message as its last line.
    unawaited(widget.cubit.rewind(sequence).whenComplete(_chats.refresh));
  }

  void _requestSelfie(GroupLine line) {
    unawaited(widget.cubit.requestSelfie(line));
  }
}
