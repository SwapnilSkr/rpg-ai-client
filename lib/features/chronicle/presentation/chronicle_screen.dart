import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../state/chronicle_cubit.dart';
import 'widgets/memory_card.dart';
import 'widgets/edit_dialog.dart';
import '../../play/presentation/widgets/narrative_bubble.dart';

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
          backgroundColor: const Color(0xFF0d0d1a),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0d0d1a),
            title: const Text(
              'Chronicle',
              style: TextStyle(color: Colors.white),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Row(
                children: [
                  _tabButton(context, 'Timeline', ChronicleTab.timeline,
                      state.activeTab == ChronicleTab.timeline),
                  _tabButton(context, 'Memories', ChronicleTab.memories,
                      state.activeTab == ChronicleTab.memories),
                ],
              ),
            ),
          ),
          body: state.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.purpleAccent))
              : state.activeTab == ChronicleTab.timeline
                  ? _buildTimeline(context, state)
                  : _buildMemories(context, state),
        );
      },
    );
  }

  Widget _tabButton(
      BuildContext context, String label, ChronicleTab tab, bool active) {
    return Expanded(
      child: InkWell(
        onTap: () => context.read<ChronicleCubit>().switchTab(tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? Colors.purpleAccent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.purpleAccent : Colors.white54,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline(BuildContext context, ChronicleState state) {
    if (state.events.isEmpty) {
      return const Center(
        child: Text('No events yet', style: TextStyle(color: Colors.white38)),
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

  Widget _buildMemories(BuildContext context, ChronicleState state) {
    if (state.memories.isEmpty) {
      return const Center(
        child: Text('No memories yet', style: TextStyle(color: Colors.white38)),
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
          onDelete: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF1a1a2e),
                title: const Text('Delete Memory?',
                    style: TextStyle(color: Colors.white)),
                content: const Text(
                  'This memory will be permanently forgotten.',
                  style: TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.white54)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context
                          .read<ChronicleCubit>()
                          .deleteMemory(memory.id);
                    },
                    child: const Text('Delete',
                        style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
