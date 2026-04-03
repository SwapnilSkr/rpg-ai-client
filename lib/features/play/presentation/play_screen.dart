import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../state/play_cubit.dart';
import 'widgets/narrative_bubble.dart';
import 'widgets/player_input.dart';
import 'widgets/world_state_bar.dart';
import '../../../shared/widgets/error_banner.dart';

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
  bool _worldStateExpanded = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PlayCubit, PlayState>(
      listenWhen: (prev, curr) => prev.events.length != curr.events.length,
      listener: (context, state) => _scrollToBottom(),
      builder: (context, state) {
        final title = state.template?.title ?? 'Loading...';

        return Scaffold(
          backgroundColor: const Color(0xFF0d0d1a),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0d0d1a),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white70),
              onPressed: () => context.pop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: state.isConnected
                            ? Colors.greenAccent
                            : Colors.redAccent,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      state.isConnected ? 'Connected' : 'Disconnected',
                      style: TextStyle(
                        color: state.isConnected
                            ? Colors.white38
                            : Colors.redAccent,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              if (state.instance != null)
                IconButton(
                  icon: const Icon(Icons.history, color: Colors.white70),
                  onPressed: () => context.push(
                    '/chronicle/${context.read<PlayCubit>().instanceId}',
                  ),
                  tooltip: 'Chronicle',
                ),
            ],
          ),
          body: Column(
            children: [
              // World state bar
              if (state.instance != null)
                WorldStateBar(
                  worldState: state.instance!.worldState,
                  expanded: _worldStateExpanded,
                  onToggle: () => setState(
                      () => _worldStateExpanded = !_worldStateExpanded),
                ),

              // Error banner
              if (state.error != null)
                ErrorBanner(
                  message: state.error!,
                  onRetry: () => context.read<PlayCubit>().clearError(),
                ),

              // Chat messages
              Expanded(
                child: state.isLoading && state.events.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.purpleAccent,
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        itemCount: state.events.length,
                        itemBuilder: (context, index) {
                          return NarrativeBubble(event: state.events[index]);
                        },
                      ),
              ),

              // Input bar
              PlayerInput(
                isGenerating: state.isGenerating,
                isConnected: state.isConnected,
                onSend: (msg) => context.read<PlayCubit>().sendMessage(msg),
              ),
            ],
          ),
        );
      },
    );
  }
}
