import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../state/play_cubit.dart';
import 'widgets/narrative_bubble.dart';
import 'widgets/player_input.dart';
import 'widgets/world_state_bar.dart';
import '../../../../app/theme/nexus_theme.dart';

class PlayScreen extends StatelessWidget {
  final String instanceId;

  const PlayScreen({super.key, required this.instanceId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PlayCubit(instanceId: instanceId),
      child: const _PlayView(),
    );
  }
}

class _PlayView extends StatefulWidget {
  const _PlayView();

  @override
  State<_PlayView> createState() => _PlayViewState();
}

class _PlayViewState extends State<_PlayView> {
  final _scrollController = ScrollController();
  bool _statsExpanded = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 120), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PlayCubit, PlayState>(
      listenWhen: (prev, curr) => prev.events.length != curr.events.length,
      listener: (_, __) => _scrollToBottom(),
      builder: (context, state) {
        final title = state.template?.title ?? '';

        return Scaffold(
          backgroundColor: EverloreTheme.void1,
          body: Column(
            children: [
              // Custom header
              _PlayHeader(
                title: title,
                isConnected: state.isConnected,
                hasInstance: state.instance != null,
                onBack: () => context.pop(),
                onChronicle: () => context.push(
                  '/chronicle/${context.read<PlayCubit>().instanceId}',
                ),
              ),

              // World state / stats bar
              if (state.instance != null && state.instance!.worldState.isNotEmpty)
                WorldStateBar(
                  worldState: state.instance!.worldState,
                  expanded: _statsExpanded,
                  onToggle: () =>
                      setState(() => _statsExpanded = !_statsExpanded),
                ),

              // Error bar
              if (state.error != null)
                _ErrorBar(
                  message: state.error!,
                  onDismiss: () => context.read<PlayCubit>().clearError(),
                ),

              // Messages area
              Expanded(
                child: state.isLoading && state.events.isEmpty
                    ? const _LoadingNarrative()
                    : state.events.isEmpty
                        ? const _EmptyNarrative()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(
                                top: 12, bottom: 12),
                            itemCount: state.events.length,
                            itemBuilder: (context, index) {
                              return NarrativeBubble(
                                event: state.events[index],
                              );
                            },
                          ),
              ),

              // Input bar
              PlayerInput(
                isGenerating: state.isGenerating,
                isConnected: state.isConnected,
                onSend: (msg) =>
                    context.read<PlayCubit>().sendMessage(msg),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlayHeader extends StatelessWidget {
  final String title;
  final bool isConnected;
  final bool hasInstance;
  final VoidCallback onBack;
  final VoidCallback onChronicle;

  const _PlayHeader({
    required this.title,
    required this.isConnected,
    required this.hasInstance,
    required this.onBack,
    required this.onChronicle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: EverloreTheme.void0,
        border: Border(
          bottom: BorderSide(color: EverloreTheme.white10, width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: EverloreTheme.ash, size: 18),
                onPressed: onBack,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: const TextStyle(
                          color: EverloreTheme.parchment,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isConnected
                                ? EverloreTheme.verdant
                                : EverloreTheme.crimson,
                            boxShadow: isConnected
                                ? [
                                    BoxShadow(
                                      color: EverloreTheme.verdant
                                          .withValues(alpha: 0.5),
                                      blurRadius: 6,
                                    )
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isConnected ? 'Realm Active' : 'Reconnecting...',
                          style: TextStyle(
                            color: isConnected
                                ? EverloreTheme.ash.withValues(alpha: 0.7)
                                : EverloreTheme.crimson.withValues(alpha: 0.8),
                            fontSize: 11,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (hasInstance)
                Tooltip(
                  message: 'Lore Tome',
                  child: InkWell(
                    onTap: onChronicle,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: EverloreTheme.void2,
                        border: Border.all(
                            color: EverloreTheme.goldDim
                                .withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.history_edu,
                          color: EverloreTheme.gold, size: 18),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingNarrative extends StatelessWidget {
  const _LoadingNarrative();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: EverloreTheme.gold,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Opening the tome...',
            style: TextStyle(
              color: EverloreTheme.ash,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNarrative extends StatelessWidget {
  const _EmptyNarrative();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories,
              color: EverloreTheme.goldDim.withValues(alpha: 0.4),
              size: 52,
            ),
            const SizedBox(height: 16),
            const Text(
              'The story begins with your first words.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: EverloreTheme.ash,
                fontSize: 15,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBar extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBar({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: EverloreTheme.crimson.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: EverloreTheme.crimson.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: EverloreTheme.crimson, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: EverloreTheme.crimson, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close,
                color: EverloreTheme.crimson, size: 16),
            onPressed: onDismiss,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
          ),
        ],
      ),
    );
  }
}
