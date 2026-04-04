import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../state/chronicle_cubit.dart';
import 'widgets/memory_card.dart';
import 'widgets/edit_dialog.dart';
import '../../play/presentation/widgets/narrative_bubble.dart';
import '../../../../app/theme/nexus_theme.dart';

class ChronicleScreen extends StatelessWidget {
  final String instanceId;

  const ChronicleScreen({super.key, required this.instanceId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ChronicleCubit(instanceId: instanceId)..loadEvents(),
      child: const _ChronicleView(),
    );
  }
}

class _ChronicleView extends StatelessWidget {
  const _ChronicleView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChronicleCubit, ChronicleState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: EverloreTheme.void1,
          body: Column(
            children: [
              _ChronicleHeader(activeTab: state.activeTab),
              Expanded(
                child: state.isLoading
                    ? const Center(
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
                            SizedBox(height: 14),
                            Text(
                              'Unrolling the scroll...',
                              style: TextStyle(
                                color: EverloreTheme.ash,
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      )
                    : state.activeTab == ChronicleTab.timeline
                        ? _buildTimeline(context, state)
                        : _buildEchoes(context, state),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeline(BuildContext context, ChronicleState state) {
    if (state.events.isEmpty) {
      return _EmptyState(
        icon: Icons.history_edu,
        title: 'No story yet',
        subtitle: 'Your adventures will be recorded here.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: state.events.length,
      itemBuilder: (context, index) {
        return NarrativeBubble(event: state.events[index]);
      },
    );
  }

  Widget _buildEchoes(BuildContext context, ChronicleState state) {
    if (state.memories.isEmpty) {
      return _EmptyState(
        icon: Icons.bookmark_border,
        title: 'No echoes yet',
        subtitle: 'Memories from your journey will appear here.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: state.memories.length,
      itemBuilder: (context, index) {
        final memory = state.memories[index];
        return MemoryCard(
          memory: memory,
          onEdit: () async {
            final result = await showDialog<Map<String, dynamic>>(
              context: context,
              builder: (_) => EditMemoryDialog(
                initialText: memory.text,
                initialType: memory.type,
                initialImportance: memory.importance,
              ),
            );
            if (result != null && context.mounted) {
              context.read<ChronicleCubit>().editMemory(
                    memory.id,
                    result['text'],
                    type: result['type'],
                    importance: result['importance'],
                  );
            }
          },
          onDelete: () => _confirmDelete(context, memory.id),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String memoryId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EverloreTheme.void2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: EverloreTheme.goldDim.withValues(alpha: 0.3)),
        ),
        title: const Text(
          'Erase This Echo?',
          style: TextStyle(color: EverloreTheme.parchment, fontSize: 18),
        ),
        content: const Text(
          'This memory will be permanently forgotten and lost from the world.',
          style: TextStyle(
              color: EverloreTheme.ash, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep',
                style: TextStyle(color: EverloreTheme.ash)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ChronicleCubit>().deleteMemory(memoryId);
            },
            child: const Text('Erase',
                style: TextStyle(color: EverloreTheme.crimson)),
          ),
        ],
      ),
    );
  }
}

class _ChronicleHeader extends StatelessWidget {
  final ChronicleTab activeTab;

  const _ChronicleHeader({required this.activeTab});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: EverloreTheme.void0,
        border: Border(bottom: BorderSide(color: EverloreTheme.white10)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title bar
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: EverloreTheme.ash, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Icon(
                    Icons.history_edu,
                    color: EverloreTheme.gold,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Lore Tome',
                    style: TextStyle(
                      color: EverloreTheme.parchment,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),

            // Tab bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  _TabButton(
                    label: 'Timeline',
                    icon: Icons.timeline,
                    active: activeTab == ChronicleTab.timeline,
                    onTap: () => context
                        .read<ChronicleCubit>()
                        .switchTab(ChronicleTab.timeline),
                  ),
                  const SizedBox(width: 10),
                  _TabButton(
                    label: 'Echoes',
                    icon: Icons.bookmark_outline,
                    active: activeTab == ChronicleTab.memories,
                    onTap: () => context
                        .read<ChronicleCubit>()
                        .switchTab(ChronicleTab.memories),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: active
              ? EverloreTheme.gold.withValues(alpha: 0.12)
              : EverloreTheme.void2,
          border: Border.all(
            color: active
                ? EverloreTheme.goldDim.withValues(alpha: 0.6)
                : EverloreTheme.goldDim.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? EverloreTheme.gold : EverloreTheme.ash,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? EverloreTheme.gold : EverloreTheme.ash,
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: EverloreTheme.goldDim.withValues(alpha: 0.3),
              size: 52,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: EverloreTheme.parchment,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: EverloreTheme.ash,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
