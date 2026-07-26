import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/nexus_theme.dart';
import '../../../shared/models/character_profile.dart';
import '../../../shared/models/world_instance.dart';
import '../../../shared/models/world_template.dart';
import '../../../shared/widgets/everlore_network_image.dart';

/// Snapshot passed from Play. This is deliberately presentation-only: the Realm
/// is a calm map of an already-open playthrough, not a second game state owner.
class RealmScreenArgs {
  final WorldInstance instance;
  final WorldTemplate template;
  final List<CharacterProfile> characters;
  final VoidCallback? onReset;
  final VoidCallback? onDelete;

  const RealmScreenArgs({
    required this.instance,
    required this.template,
    required this.characters,
    this.onReset,
    this.onDelete,
  });
}

class RealmScreen extends StatelessWidget {
  final String instanceId;
  final RealmScreenArgs? args;

  const RealmScreen({super.key, required this.instanceId, this.args});

  @override
  Widget build(BuildContext context) {
    final realm = args;
    if (realm == null) {
      return Scaffold(
        backgroundColor: EverloreTheme.void1,
        appBar: AppBar(backgroundColor: EverloreTheme.void1),
        body: const Center(
          child: Text(
            'Open this realm from its story to view its details.',
            style: TextStyle(color: EverloreTheme.ash),
          ),
        ),
      );
    }
    final template = realm.template;
    final instance = realm.instance;
    final characters = realm.characters.where((c) => !c.isProtagonist).toList();
    final sceneLabel = instance.currentScene.tag.replaceAll('_', ' ');

    return Scaffold(
      backgroundColor: EverloreTheme.void1,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: EverloreTheme.void1,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: EverloreTheme.parchment,
              ),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (template.imageUrl.isNotEmpty)
                    EverloreNetworkImage(
                      imageUrl: template.imageUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 1080,
                      errorWidget: const _RealmFallbackArt(),
                      semanticLabel: template.title,
                    )
                  else
                    const _RealmFallbackArt(),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x22000000), EverloreTheme.void1],
                        stops: [0, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 22,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.title,
                          style: EverloreTheme.serifDisplay(
                            size: 30,
                            color: EverloreTheme.parchment,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'YOUR REALM · ${sceneLabel.toUpperCase()}',
                          style: EverloreTheme.ui(
                            size: 11,
                            color: EverloreTheme.gold,
                            weight: FontWeight.w700,
                            spacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (template.description.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Text(
                      template.description,
                      style: EverloreTheme.ui(
                        size: 14,
                        color: EverloreTheme.ash,
                        height: 1.5,
                      ),
                    ),
                  ),
                _RealmStatus(
                  turns: instance.meta.totalEvents,
                  memories: instance.meta.totalMemories,
                  characters: characters.length,
                ),
                const SizedBox(height: 24),
                _SectionLabel('ENTER THE TOMES'),
                const SizedBox(height: 10),
                _RealmAction(
                  icon: Icons.auto_stories_outlined,
                  title: 'Chronicle overview',
                  subtitle:
                      'Your story so far, current place, and what matters now.',
                  onTap: () => context.push('/chronicle/$instanceId'),
                ),
                _RealmAction(
                  icon: Icons.timeline_outlined,
                  title: 'Story timeline',
                  subtitle:
                      'Read, revisit, and manage the turns that led here.',
                  onTap: () =>
                      context.push('/chronicle/$instanceId?section=story'),
                ),
                _RealmAction(
                  icon: Icons.people_alt_outlined,
                  title: 'People & bonds',
                  subtitle: characters.isEmpty
                      ? 'The cast will gather here as the story unfolds.'
                      : '${characters.length} known character${characters.length == 1 ? '' : 's'} and their evolving bonds.',
                  onTap: () =>
                      context.push('/chronicle/$instanceId?section=people'),
                ),
                _RealmAction(
                  icon: Icons.public_outlined,
                  title: 'World atlas',
                  subtitle:
                      'Places, time, and the shape of the world you have discovered.',
                  onTap: () =>
                      context.push('/chronicle/$instanceId?section=world'),
                ),
                const SizedBox(height: 22),
                _SectionLabel('THIS PLAYTHROUGH'),
                const SizedBox(height: 10),
                _RealmInfo(
                  icon: Icons.visibility_outlined,
                  label: 'Narration',
                  value: instance.narrationPov == 'first'
                      ? 'First person'
                      : 'Third person',
                ),
                _RealmInfo(
                  icon: Icons.forum_outlined,
                  label: 'Reply length',
                  value:
                      instance.messageLength[0].toUpperCase() +
                      instance.messageLength.substring(1),
                ),
                _RealmInfo(
                  icon: Icons.theater_comedy_outlined,
                  label: 'Mode',
                  value: instance.mode.replaceAll('_', ' '),
                ),
                if (realm.onReset != null || realm.onDelete != null) ...[
                  const SizedBox(height: 22),
                  _SectionLabel('MANAGE THIS PLAYTHROUGH'),
                  const SizedBox(height: 6),
                  if (realm.onReset != null)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: const Icon(
                        Icons.restart_alt_rounded,
                        color: EverloreTheme.gold,
                      ),
                      title: Text(
                        'Reset this chat',
                        style: EverloreTheme.ui(
                          size: 14,
                          color: EverloreTheme.parchment,
                        ),
                      ),
                      subtitle: Text(
                        'Return to the opening line while keeping the world.',
                        style: EverloreTheme.ui(
                          size: 12,
                          color: EverloreTheme.ash,
                        ),
                      ),
                      onTap: () {
                        context.pop();
                        realm.onReset!.call();
                      },
                    ),
                  if (realm.onDelete != null)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: const Icon(
                        Icons.delete_outline,
                        color: EverloreTheme.crimson,
                      ),
                      title: Text(
                        'Delete this chat',
                        style: EverloreTheme.ui(
                          size: 14,
                          color: EverloreTheme.crimson,
                        ),
                      ),
                      onTap: () {
                        context.pop();
                        realm.onDelete!.call();
                      },
                    ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _RealmFallbackArt extends StatelessWidget {
  const _RealmFallbackArt();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF26213A), EverloreTheme.void1],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  );
}

class _RealmStatus extends StatelessWidget {
  final int turns, memories, characters;
  const _RealmStatus({
    required this.turns,
    required this.memories,
    required this.characters,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
    decoration: BoxDecoration(
      color: EverloreTheme.void2,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: EverloreTheme.white10),
    ),
    child: Row(
      children: [
        _RealmStat(value: '$turns', label: 'TURNS'),
        _RealmStat(value: '$characters', label: 'PEOPLE'),
        _RealmStat(value: '$memories', label: 'ECHOES'),
      ],
    ),
  );
}

class _RealmStat extends StatelessWidget {
  final String value, label;
  const _RealmStat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: EverloreTheme.serifDisplay(
            size: 22,
            color: EverloreTheme.parchment,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: EverloreTheme.ui(
            size: 10,
            color: EverloreTheme.ash,
            weight: FontWeight.w700,
            spacing: 1.1,
          ),
        ),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: EverloreTheme.ui(
      size: 11,
      color: EverloreTheme.gold,
      weight: FontWeight.w700,
      spacing: 1.5,
    ),
  );
}

class _RealmAction extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _RealmAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: EverloreTheme.void2,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: EverloreTheme.gold, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: EverloreTheme.ui(
                        size: 15,
                        color: EverloreTheme.parchment,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: EverloreTheme.ui(
                        size: 12,
                        color: EverloreTheme.ash,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: EverloreTheme.ash),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RealmInfo extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _RealmInfo({
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    leading: Icon(icon, color: EverloreTheme.ash, size: 20),
    title: Text(
      label,
      style: EverloreTheme.ui(size: 13, color: EverloreTheme.parchment),
    ),
    trailing: Text(
      value,
      style: EverloreTheme.ui(size: 12, color: EverloreTheme.ash),
    ),
  );
}
