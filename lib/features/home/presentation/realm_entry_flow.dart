import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/nexus_theme.dart';
import '../../../core/auth/auth_service.dart';
import '../../../shared/models/realm_play_status.dart';
import '../../../shared/models/persona.dart';
import '../../../shared/widgets/everlore_session_loader.dart';
import '../../../shared/widgets/neu.dart';
import '../data/home_repository.dart';
import '../../personas/data/persona_repository.dart';

enum RealmEntryChoice { continueStory, beginAnew }

class RealmEntryResult {
  final RealmEntryChoice choice;
  final String? instanceId;

  const RealmEntryResult({required this.choice, this.instanceId});
}

/// Checks whether the player has visited this world before and guides them to
/// continue an existing story or begin a fresh one.
Future<void> enterRealmFromTemplate(
  BuildContext context, {
  required String templateId,
  required String worldTitle,
  bool isSentient = false,
}) async {
  final loggedIn = await AuthService.isLoggedIn();
  if (!context.mounted) return;

  if (!loggedIn) {
    context.push('/auth');
    return;
  }

  final status = await showEverloreSessionLoading<RealmPlayStatus>(
    context,
    message: 'Checking your path',
    task: () => HomeRepository.getPlayStatus(templateId),
  );
  if (!context.mounted || status == null) return;

  if (!status.hasPlayed) {
    await beginNewRealmStory(context, templateId, isSentient: isSentient);
    return;
  }

  final result = await showRealmContinueSheet(
    context,
    worldTitle: worldTitle,
    status: status,
  );
  if (!context.mounted || result == null) return;

  switch (result.choice) {
    case RealmEntryChoice.continueStory:
      final id = result.instanceId ?? status.latestInstanceId;
      if (id != null) context.push('/play/$id');
      break;
    case RealmEntryChoice.beginAnew:
      await beginNewRealmStory(context, templateId, isSentient: isSentient);
      break;
  }
}

Future<void> beginNewRealmStory(
  BuildContext context,
  String templateId, {
  bool isSentient = false,
}) async {
  try {
    String? personaId;
    if (isSentient) {
      final choice = await _chooseSentientPersona(context);
      if (!context.mounted || choice == null) return;
      personaId = choice.personaId;
    }
    final instance = await showEverloreSessionLoading(
      context,
      message: 'Opening the gate',
      task: () =>
          HomeRepository.createInstance(templateId, personaId: personaId),
    );
    if (!context.mounted || instance == null) return;
    context.push('/play/${instance.id}');
  } catch (e) {
    if (!context.mounted) return;
    final msg = e.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: EverloreTheme.crimson.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _PersonaStartChoice {
  final String? personaId;
  const _PersonaStartChoice({this.personaId});
}

Future<_PersonaStartChoice?> _chooseSentientPersona(
  BuildContext context,
) async {
  List<Persona> personas = const [];
  try {
    personas = await PersonaRepository.list();
  } catch (_) {
    // New stories must still be playable when the optional account persona
    // library cannot be reached.
  }
  if (!context.mounted) return null;
  return showModalBottomSheet<_PersonaStartChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: EverloreTheme.void2,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => _SentientPersonaStartSheet(personas: personas),
  );
}

/// Used by the creator's immediate-play flow. A null result means the player
/// chose to start without a saved persona (or dismissed this optional step).
Future<String?> choosePersonaForNewSentientStory(BuildContext context) async {
  final choice = await _chooseSentientPersona(context);
  return choice?.personaId;
}

class _SentientPersonaStartSheet extends StatefulWidget {
  final List<Persona> personas;
  const _SentientPersonaStartSheet({required this.personas});

  @override
  State<_SentientPersonaStartSheet> createState() =>
      _SentientPersonaStartSheetState();
}

class _SentientPersonaStartSheetState
    extends State<_SentientPersonaStartSheet> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _createAndUse() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _creating = true);
    try {
      final persona = await PersonaRepository.create(
        name: name,
        gender: 'non_binary',
        description: _description.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context, _PersonaStartChoice(personaId: persona.id));
      }
    } catch (_) {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: EverloreTheme.void4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Who enters this story?',
              style: EverloreTheme.serifDisplay(
                size: 19,
                color: EverloreTheme.parchment,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a reusable persona or create one. This story receives a '
              'snapshot, so your later edits never rewrite its past.',
              style: EverloreTheme.ui(
                size: 12.5,
                color: EverloreTheme.ash,
                height: 1.45,
              ),
            ),
            if (widget.personas.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                'YOUR PERSONAS',
                style: EverloreTheme.ui(
                  size: 11,
                  color: EverloreTheme.gold,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.personas.map((persona) {
                  final subtitle = persona.description.trim();
                  return GestureDetector(
                    onTap: () => Navigator.pop(
                      context,
                      _PersonaStartChoice(personaId: persona.id),
                    ),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 280),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: EverloreTheme.gold.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: EverloreTheme.gold.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        subtitle.isEmpty
                            ? persona.name
                            : '${persona.name} · $subtitle',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: EverloreTheme.ui(
                          size: 13,
                          color: EverloreTheme.parchment,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'CREATE A NEW PERSONA',
              style: EverloreTheme.ui(
                size: 11,
                color: EverloreTheme.gold,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              style: EverloreTheme.ui(size: 15, color: EverloreTheme.parchment),
              decoration: _personaDecoration('Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              minLines: 1,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              style: EverloreTheme.ui(size: 14, color: EverloreTheme.parchment),
              decoration: _personaDecoration(
                'Optional: a few defining details',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, const _PersonaStartChoice()),
                  child: Text(
                    'Continue without one',
                    style: EverloreTheme.ui(size: 13, color: EverloreTheme.ash),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _creating ? null : _createAndUse,
                  style: FilledButton.styleFrom(
                    backgroundColor: EverloreTheme.gold,
                    foregroundColor: EverloreTheme.void1,
                  ),
                  child: Text(_creating ? 'Saving…' : 'Create and use'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _personaDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: EverloreTheme.ui(size: 13, color: EverloreTheme.ash),
    filled: true,
    fillColor: EverloreTheme.void3,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: EverloreTheme.goldDim.withValues(alpha: .25),
      ),
    ),
  );
}

Future<RealmEntryResult?> showRealmContinueSheet(
  BuildContext context, {
  required String worldTitle,
  required RealmPlayStatus status,
}) {
  return showModalBottomSheet<RealmEntryResult>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: status.count > 1,
    builder: (sheetCtx) {
      return _RealmContinueSheet(
        worldTitle: worldTitle,
        status: status,
        onContinueLatest: () => Navigator.pop(
          sheetCtx,
          RealmEntryResult(
            choice: RealmEntryChoice.continueStory,
            instanceId: status.latestInstanceId,
          ),
        ),
        onBeginAnew: () => Navigator.pop(
          sheetCtx,
          const RealmEntryResult(choice: RealmEntryChoice.beginAnew),
        ),
        onPickStory: (id) => Navigator.pop(
          sheetCtx,
          RealmEntryResult(
            choice: RealmEntryChoice.continueStory,
            instanceId: id,
          ),
        ),
      );
    },
  );
}

class _RealmContinueSheet extends StatelessWidget {
  final String worldTitle;
  final RealmPlayStatus status;
  final VoidCallback onContinueLatest;
  final VoidCallback onBeginAnew;
  final void Function(String id) onPickStory;

  const _RealmContinueSheet({
    required this.worldTitle,
    required this.status,
    required this.onContinueLatest,
    required this.onBeginAnew,
    required this.onPickStory,
  });

  @override
  Widget build(BuildContext context) {
    final multiple = status.count > 1;
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.72;

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      decoration: const BoxDecoration(
        color: EverloreTheme.void2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0x33D8B878))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: EverloreTheme.goldDim.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                "You've wandered here before",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: EverloreTheme.uiFamily,
                  color: EverloreTheme.parchment,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                multiple
                    ? 'Your stories in $worldTitle are waiting. Pick one up or begin anew.'
                    : 'Your story in $worldTitle awaits. Continue where you left off, or begin a fresh journey.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: EverloreTheme.ash,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              if (multiple) ...[
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: status.stories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final story = status.stories[i];
                      return _StoryPickTile(
                        label: 'Story ${status.stories.length - i}',
                        lastActiveAt: story.lastActiveAt,
                        turnCount: story.totalEvents,
                        onTap: () => onPickStory(story.id),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                NeuButton(
                  label: 'Begin a new story',
                  icon: Icons.auto_stories,
                  primary: false,
                  onTap: onBeginAnew,
                ),
              ] else ...[
                NeuButton(
                  label: 'Continue your story',
                  icon: Icons.play_arrow_rounded,
                  accent: EverloreTheme.aether,
                  onTap: onContinueLatest,
                ),
                const SizedBox(height: 12),
                NeuButton(
                  label: 'Begin anew',
                  icon: Icons.refresh_rounded,
                  primary: false,
                  onTap: onBeginAnew,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryPickTile extends StatelessWidget {
  final String label;
  final DateTime? lastActiveAt;
  final int turnCount;
  final VoidCallback onTap;

  const _StoryPickTile({
    required this.label,
    required this.lastActiveAt,
    required this.turnCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [EverloreTheme.void3, EverloreTheme.void2],
          ),
          border: Border.all(
            color: EverloreTheme.goldDim.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: EverloreTheme.parchment,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _subtitle(),
                    style: const TextStyle(
                      color: EverloreTheme.ash,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: EverloreTheme.goldDim,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle() {
    final ago = _formatAgo(lastActiveAt);
    if (turnCount > 0 && ago.isNotEmpty) return '$turnCount turns · $ago';
    if (turnCount > 0) return '$turnCount turns';
    if (ago.isNotEmpty) return 'Last visited $ago';
    return 'Ready to continue';
  }

  String _formatAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 7) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}
