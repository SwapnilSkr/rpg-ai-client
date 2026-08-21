import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../state/chronicle_cubit.dart';
import 'widgets/memory_card.dart';
import 'widgets/edit_dialog.dart';
import 'widgets/almanac_view.dart';
import 'widgets/places_view.dart';
import 'widgets/bonds_view.dart';
import 'widgets/threads_view.dart';
import 'widgets/recap_view.dart';
import 'widgets/echoes_filter_bar.dart';
import '../../play/presentation/widgets/narrative_bubble.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/widgets/everlore_empty_state.dart';

class ChronicleScreen extends StatelessWidget {
  final String instanceId;
  final String? initialSection;

  const ChronicleScreen({
    super.key,
    required this.instanceId,
    this.initialSection,
  });

  ChronicleTab get _initialTab => switch (initialSection) {
    'story' => ChronicleTab.timeline,
    'people' => ChronicleTab.bonds,
    'world' => ChronicleTab.places,
    'archive' => ChronicleTab.memories,
    _ => ChronicleTab.recap,
  };

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          ChronicleCubit(instanceId: instanceId, initialTab: _initialTab)
            ..loadInitial(),
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
          body: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/art/chronicle-keeper.webp',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      EverloreTheme.void0.withValues(alpha: 0.18),
                      EverloreTheme.void0.withValues(alpha: 0.52),
                      EverloreTheme.void0.withValues(alpha: 0.78),
                    ],
                    stops: const [0, 0.44, 1],
                  ),
                ),
              ),
              Column(
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
                        : state.activeTab == ChronicleTab.recap
                        ? _buildRecap(context, state)
                        : state.activeTab == ChronicleTab.timeline
                        ? _buildTimeline(context, state)
                        : state.activeTab == ChronicleTab.memories
                        ? _buildEchoes(context, state)
                        : state.activeTab == ChronicleTab.bonds ||
                              state.activeTab == ChronicleTab.threads
                        ? _buildPeople(context, state)
                        : _buildWorld(context, state),
                  ),
                ],
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
    final filtersActive =
        state.memoryQuery.isNotEmpty ||
        state.memoryType.isNotEmpty ||
        state.memoryUnresolved ||
        state.memoryHighImportance;

    return Column(
      children: [
        const EchoesFilterBar(),
        Expanded(
          child: state.memories.isEmpty
              ? _EmptyState(
                  icon: filtersActive
                      ? Icons.search_off
                      : Icons.bookmark_border,
                  title: filtersActive ? 'No matching echoes' : 'No echoes yet',
                  subtitle: filtersActive
                      ? 'Try a different search or clear the filters.'
                      : 'Memories from your journey will appear here.',
                )
              : _echoesList(context, state),
        ),
      ],
    );
  }

  Widget _echoesList(BuildContext context, ChronicleState state) {
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

  Widget _buildAlmanac(BuildContext context, ChronicleState state) {
    final calendar = state.calendar;
    if (calendar == null) {
      return _EmptyState(
        icon: Icons.event_note,
        title: 'No almanac yet',
        subtitle: 'The days of your story will be charted here.',
      );
    }
    return AlmanacView(data: calendar);
  }

  Widget _buildPlaces(BuildContext context, ChronicleState state) {
    final locations = state.locations;
    if (locations == null) {
      return _EmptyState(
        icon: Icons.map_outlined,
        title: 'No places yet',
        subtitle: 'The places your story visits will be remembered here.',
      );
    }
    return PlacesView(
      instanceId: context.read<ChronicleCubit>().instanceId,
      data: locations,
    );
  }

  Widget _buildBonds(BuildContext context, ChronicleState state) {
    final bonds = state.bonds;
    if (bonds == null) {
      return _EmptyState(
        icon: Icons.favorite_border,
        title: 'No bonds yet',
        subtitle: 'Where others stand with you will be charted here.',
      );
    }
    return BondsView(
      instanceId: context.read<ChronicleCubit>().instanceId,
      ledger: bonds,
    );
  }

  Widget _buildRecap(BuildContext context, ChronicleState state) {
    final recap = state.recap;
    if (recap == null) {
      return _EmptyState(
        icon: Icons.auto_stories,
        title: 'No recap yet',
        subtitle: 'Your story so far will be gathered here.',
      );
    }
    return RecapView(data: recap);
  }

  Widget _buildThreads(BuildContext context, ChronicleState state) {
    final threads = state.threads;
    if (threads == null) {
      return _EmptyState(
        icon: Icons.flag_outlined,
        title: 'No threads yet',
        subtitle: 'Promises, debts, and open questions will gather here.',
      );
    }
    return ThreadsView(data: threads);
  }

  Widget _buildPeople(BuildContext context, ChronicleState state) {
    final showBonds = state.activeTab == ChronicleTab.bonds;
    return Column(
      children: [
        _CollectionSwitch(
          first: 'Bonds',
          second: 'Threads',
          firstActive: showBonds,
          onFirst: () =>
              context.read<ChronicleCubit>().switchTab(ChronicleTab.bonds),
          onSecond: () =>
              context.read<ChronicleCubit>().switchTab(ChronicleTab.threads),
        ),
        Expanded(
          child: showBonds
              ? _buildBonds(context, state)
              : _buildThreads(context, state),
        ),
      ],
    );
  }

  Widget _buildWorld(BuildContext context, ChronicleState state) {
    final showPlaces = state.activeTab == ChronicleTab.places;
    return Column(
      children: [
        _CollectionSwitch(
          first: 'Places',
          second: 'Almanac',
          firstActive: showPlaces,
          onFirst: () =>
              context.read<ChronicleCubit>().switchTab(ChronicleTab.places),
          onSecond: () =>
              context.read<ChronicleCubit>().switchTab(ChronicleTab.calendar),
        ),
        Expanded(
          child: showPlaces
              ? _buildPlaces(context, state)
              : _buildAlmanac(context, state),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, String memoryId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EverloreTheme.void2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: EverloreTheme.goldDim.withValues(alpha: 0.3)),
        ),
        title: const Text(
          'Erase This Echo?',
          style: TextStyle(color: EverloreTheme.parchment, fontSize: 18),
        ),
        content: const Text(
          'This memory will be permanently forgotten and lost from the world.',
          style: TextStyle(color: EverloreTheme.ash, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Keep',
              style: TextStyle(color: EverloreTheme.ash),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ChronicleCubit>().deleteMemory(memoryId);
            },
            child: const Text(
              'Erase',
              style: TextStyle(color: EverloreTheme.crimson),
            ),
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
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: Colors.transparent,
        border: Border(bottom: BorderSide(color: EverloreTheme.white10)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      EverloreTheme.void0.withValues(alpha: 0.58),
                      EverloreTheme.void0.withValues(alpha: 0.3),
                      EverloreTheme.void0.withValues(alpha: 0.02),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
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
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: EverloreTheme.ash,
                          size: 18,
                        ),
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
                      const Spacer(),
                      Material(
                        color: EverloreTheme.void0.withValues(alpha: 0.46),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).pop(),
                          child: const SizedBox(
                            width: 42,
                            height: 42,
                            child: Icon(
                              Icons.close_rounded,
                              color: EverloreTheme.parchment,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab bar
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      _TabButton(
                        label: 'Overview',
                        icon: Icons.auto_stories,
                        active: activeTab == ChronicleTab.recap,
                        onTap: () => context.read<ChronicleCubit>().switchTab(
                          ChronicleTab.recap,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _TabButton(
                        label: 'Story',
                        icon: Icons.timeline,
                        active: activeTab == ChronicleTab.timeline,
                        onTap: () => context.read<ChronicleCubit>().switchTab(
                          ChronicleTab.timeline,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _TabButton(
                        label: 'People',
                        icon: Icons.people_alt_outlined,
                        active:
                            activeTab == ChronicleTab.bonds ||
                            activeTab == ChronicleTab.threads,
                        onTap: () => context.read<ChronicleCubit>().switchTab(
                          ChronicleTab.bonds,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _TabButton(
                        label: 'World',
                        icon: Icons.public_outlined,
                        active:
                            activeTab == ChronicleTab.places ||
                            activeTab == ChronicleTab.calendar,
                        onTap: () => context.read<ChronicleCubit>().switchTab(
                          ChronicleTab.places,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _TabButton(
                        label: 'Archive',
                        icon: Icons.bookmark_outline,
                        active: activeTab == ChronicleTab.memories,
                        onTap: () => context.read<ChronicleCubit>().switchTab(
                          ChronicleTab.memories,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionSwitch extends StatelessWidget {
  final String first;
  final String second;
  final bool firstActive;
  final VoidCallback onFirst;
  final VoidCallback onSecond;

  const _CollectionSwitch({
    required this.first,
    required this.second,
    required this.firstActive,
    required this.onFirst,
    required this.onSecond,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Row(
      children: [
        Expanded(child: _switchButton(first, firstActive, onFirst)),
        const SizedBox(width: 8),
        Expanded(child: _switchButton(second, !firstActive, onSecond)),
      ],
    ),
  );

  Widget _switchButton(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? EverloreTheme.gold.withValues(alpha: 0.12)
                : EverloreTheme.void2,
            border: Border.all(
              color: selected ? EverloreTheme.goldDim : EverloreTheme.white10,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? EverloreTheme.gold : EverloreTheme.ash,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      );
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
    return EverloreEmptyState(
      icon: icon,
      eyebrow: 'CHRONICLE',
      title: title,
      message: subtitle,
      accent: EverloreTheme.gold,
      compact: true,
    );
  }
}
