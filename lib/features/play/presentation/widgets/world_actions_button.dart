import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../app/theme/nexus_theme.dart';
import '../../../../../shared/models/character_profile.dart';
import '../../../../../shared/models/relation_candidate.dart';

/// A deliberate, structured alternative to asking the player to phrase state
/// changes perfectly in prose. Time, travel, party, and kinship all originate
/// here as explicit commands.
class WorldActionsButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onContinue;
  final ValueChanged<String> onAdvance;
  final void Function(
    String destination,
    List<String> companions,
    String? advance,
  )
  onTravel;
  final void Function(
    String character,
    String relation,
    bool correction,
    String? replacesRelation,
  )
  onRelationship;
  final List<CharacterProfile> characters;
  final List<String> presentCharacters;
  final Future<List<String>> Function()? loadKnownDestinations;
  final Future<List<RelationCandidate>> Function()? loadRelationCandidates;
  final Future<Map<String, String>> Function()? loadConfirmedKinship;
  final Future<bool> Function(
    String candidateId,
    String action,
    String? relation,
  )?
  onResolveRelationCandidate;
  final Future<bool> Function(CharacterProfile character, String newName)?
  onRenameCharacter;

  const WorldActionsButton({
    super.key,
    required this.enabled,
    required this.onContinue,
    required this.onAdvance,
    required this.onTravel,
    required this.onRelationship,
    required this.characters,
    this.presentCharacters = const [],
    this.loadKnownDestinations,
    this.loadRelationCandidates,
    this.loadConfirmedKinship,
    this.onResolveRelationCandidate,
    this.onRenameCharacter,
  });

  void _open(BuildContext context) {
    HapticFeedback.mediumImpact();
    var candidatesLoaded = false;
    var candidates = const <RelationCandidate>[];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: EverloreTheme.void2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (modalContext, setSheetState) {
          if (!candidatesLoaded && loadRelationCandidates != null) {
            candidatesLoaded = true;
            loadRelationCandidates!()
                .then((loaded) {
                  if (modalContext.mounted) {
                    setSheetState(() => candidates = loaded);
                  }
                })
                .catchError((_) {});
          }
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WORLD ACTIONS',
                      style: EverloreTheme.ui(
                        size: 11,
                        weight: FontWeight.w700,
                        color: EverloreTheme.gold.withValues(alpha: 0.82),
                        spacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Make the change. The story follows.',
                      style: EverloreTheme.ui(
                        size: 12,
                        color: EverloreTheme.ash,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ActionTile(
                      icon: Icons.play_arrow_rounded,
                      title: 'Continue story',
                      subtitle: 'Let the present moment unfold',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        onContinue();
                      },
                    ),
                    _SheetLabel('LET TIME PASS'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          const [
                                _TimeChoice(
                                  'hours',
                                  'Later today',
                                  Icons.wb_twilight_outlined,
                                ),
                                _TimeChoice(
                                  'day',
                                  'Tomorrow',
                                  Icons.wb_sunny_outlined,
                                ),
                                _TimeChoice(
                                  'days',
                                  'A few days',
                                  Icons.calendar_today_outlined,
                                ),
                                _TimeChoice(
                                  'season',
                                  'Next season',
                                  Icons.ac_unit,
                                ),
                              ]
                              .map(
                                (choice) => _TimePill(
                                  choice: choice,
                                  onTap: () {
                                    Navigator.of(sheetContext).pop();
                                    onAdvance(choice.key!);
                                  },
                                ),
                              )
                              .toList(),
                    ),
                    if (candidates.isNotEmpty) ...[
                      _SheetLabel('REVIEW STORY DETAILS'),
                      _ActionTile(
                        icon: Icons.fact_check_outlined,
                        title:
                            'Review possible relationship${candidates.length > 1 ? 's' : ''}',
                        subtitle: candidates.length == 1
                            ? '${candidates.first.characterName} may be your ${_relationLabel(candidates.first.relation)}'
                            : '${candidates.length} details await your decision',
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _showRelationCandidates(context, candidates);
                        },
                      ),
                    ],
                    _SheetLabel('MAKE A DELIBERATE CHANGE'),
                    _ActionTile(
                      icon: Icons.explore_outlined,
                      title: 'Travel to…',
                      subtitle: 'Choose a destination and who comes',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _showTravelSheet(context);
                      },
                    ),
                    _ActionTile(
                      icon: Icons.account_tree_outlined,
                      title: 'Set a relationship',
                      subtitle: 'Confirm or correct story canon',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _showRelationshipSheet(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showRelationCandidates(
    BuildContext context,
    List<RelationCandidate> candidates,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: EverloreTheme.void2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SheetHeader(
                  icon: Icons.fact_check_outlined,
                  title: 'REVIEW STORY DETAILS',
                  subtitle: 'Nothing becomes canon until you confirm it.',
                  onBack: () {
                    Navigator.of(sheetContext).pop();
                    _open(context);
                  },
                ),
                ...candidates.map(
                  (candidate) => _ActionTile(
                    icon: Icons.account_tree_outlined,
                    title:
                        '${candidate.characterName} may be your ${_relationLabel(candidate.relation)}',
                    subtitle: candidate.evidence,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _showRelationCandidateDetail(context, candidate);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRelationCandidateDetail(
    BuildContext context,
    RelationCandidate candidate,
  ) {
    String relation = candidate.relation;
    const relations = [
      'mother',
      'father',
      'sister',
      'brother',
      'daughter',
      'son',
      'aunt',
      'uncle',
      'grandmother',
      'grandfather',
      'niece',
      'nephew',
      'cousin',
      'wife',
      'husband',
      'fiance',
      'fiancee',
      'partner',
    ];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: EverloreTheme.void2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (modalContext, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetHeader(
                icon: Icons.account_tree_outlined,
                title: 'POSSIBLE RELATIONSHIP',
                subtitle:
                    '${candidate.characterName} may be your ${_relationLabel(relation)}.',
                onBack: () {
                  Navigator.of(sheetContext).pop();
                  _showRelationCandidates(context, [candidate]);
                },
              ),
              _FieldLabel('STORY EVIDENCE'),
              Text(
                candidate.evidence,
                style: EverloreTheme.ui(size: 13, color: EverloreTheme.ash),
              ),
              _FieldLabel('RELATION TO YOU'),
              DropdownButtonFormField<String>(
                value: relation,
                dropdownColor: EverloreTheme.void3,
                style: EverloreTheme.ui(
                  size: 14,
                  color: EverloreTheme.parchment,
                ),
                decoration: _inputDecoration('Choose relationship'),
                items: relations
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(_relationLabel(item)),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setSheetState(() => relation = value!),
              ),
              const SizedBox(height: 14),
              _PrimaryAction(
                label: 'Confirm relationship',
                enabled: onResolveRelationCandidate != null,
                onTap: () async {
                  final resolve = onResolveRelationCandidate;
                  if (resolve == null ||
                      !await resolve(candidate.id, 'accept', relation)) {
                    return;
                  }
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onResolveRelationCandidate == null
                          ? null
                          : () async {
                              if (await onResolveRelationCandidate!(
                                    candidate.id,
                                    'reject',
                                    null,
                                  ) &&
                                  sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                              }
                            },
                      child: const Text('Not related'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onResolveRelationCandidate == null
                          ? null
                          : () async {
                              if (await onResolveRelationCandidate!(
                                    candidate.id,
                                    'defer',
                                    null,
                                  ) &&
                                  sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                              }
                            },
                      child: const Text('Not now'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTravelSheet(BuildContext context) {
    final companions = <String>{};
    String? advance;
    var destinationsLoaded = false;
    var knownDestinations = const <String>[];
    final available = _presentTravelCompanions();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: EverloreTheme.void2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _OwnedTextController(
        builder: (controllerContext, destination) => StatefulBuilder(
          builder: (modalContext, setSheetState) {
            if (!destinationsLoaded) {
              destinationsLoaded = true;
              loadKnownDestinations
                  ?.call()
                  .then((loaded) {
                    if (!modalContext.mounted) return;
                    final seen = <String>{};
                    setSheetState(() {
                      knownDestinations = loaded
                          .map((name) => name.trim())
                          .where((name) => name.isNotEmpty)
                          .where((name) => seen.add(name.toLowerCase()))
                          .take(12)
                          .toList();
                    });
                  })
                  .catchError((_) {});
            }
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                16 + MediaQuery.viewInsetsOf(modalContext).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SheetHeader(
                      icon: Icons.explore_outlined,
                      title: 'PLAN A JOURNEY',
                      subtitle: 'Your selection becomes the world state.',
                      onBack: () {
                        Navigator.of(sheetContext).pop();
                        _open(context);
                      },
                    ),
                    _FieldLabel('WHERE ARE YOU GOING?'),
                    TextField(
                      controller: destination,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 80,
                      onChanged: (_) => setSheetState(() {}),
                      style: EverloreTheme.ui(
                        size: 15,
                        color: EverloreTheme.parchment,
                      ),
                      decoration: _inputDecoration(
                        'Name a known or new destination',
                      ),
                    ),
                    if (knownDestinations.isNotEmpty) ...[
                      _FieldLabel('KNOWN DESTINATIONS'),
                      Text(
                        'Choose a place already in this world, or name somewhere new.',
                        style: EverloreTheme.ui(
                          size: 12,
                          color: EverloreTheme.ash,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: knownDestinations.map((place) {
                          final selected =
                              destination.text.trim().toLowerCase() ==
                              place.toLowerCase();
                          return ChoiceChip(
                            selected: selected,
                            label: Text(place),
                            onSelected: (_) => setSheetState(() {
                              destination.value = TextEditingValue(
                                text: place,
                                selection: TextSelection.collapsed(
                                  offset: place.length,
                                ),
                              );
                            }),
                            selectedColor: EverloreTheme.gold.withValues(
                              alpha: 0.16,
                            ),
                            backgroundColor: EverloreTheme.void3,
                            side: BorderSide(
                              color: EverloreTheme.gold.withValues(
                                alpha: selected ? 0.55 : 0.18,
                              ),
                            ),
                            labelStyle: EverloreTheme.ui(
                              size: 12,
                              color: selected
                                  ? EverloreTheme.parchment
                                  : EverloreTheme.ash,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    _FieldLabel('WHO TRAVELS WITH YOU?'),
                    Text(
                      companions.isEmpty
                          ? 'Just you — everyone else remains behind.'
                          : '${companions.join(', ')} will travel with you.',
                      style: EverloreTheme.ui(
                        size: 12,
                        color: EverloreTheme.ash,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (available.isEmpty)
                      Text(
                        'No one else is in this scene to travel with you.',
                        style: EverloreTheme.ui(
                          size: 12,
                          color: EverloreTheme.ash,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: available.map((characterName) {
                          final selected = companions.contains(characterName);
                          return FilterChip(
                            selected: selected,
                            label: Text(characterName),
                            onSelected: (value) => setSheetState(() {
                              if (value) {
                                companions.add(characterName);
                              } else {
                                companions.remove(characterName);
                              }
                            }),
                            selectedColor: EverloreTheme.gold.withValues(
                              alpha: 0.16,
                            ),
                            backgroundColor: EverloreTheme.void3,
                            side: BorderSide(
                              color: EverloreTheme.gold.withValues(
                                alpha: selected ? 0.55 : 0.18,
                              ),
                            ),
                            labelStyle: EverloreTheme.ui(
                              size: 12,
                              color: selected
                                  ? EverloreTheme.parchment
                                  : EverloreTheme.ash,
                            ),
                          );
                        }).toList(),
                      ),
                    _FieldLabel('HOW MUCH TIME PASSES?'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          [
                                const _TimeChoice(
                                  null,
                                  'No stated skip',
                                  Icons.timelapse_outlined,
                                ),
                                const _TimeChoice(
                                  'hours',
                                  'Later today',
                                  Icons.wb_twilight_outlined,
                                ),
                                const _TimeChoice(
                                  'day',
                                  'Tomorrow',
                                  Icons.wb_sunny_outlined,
                                ),
                                const _TimeChoice(
                                  'days',
                                  'A few days',
                                  Icons.calendar_today_outlined,
                                ),
                              ]
                              .map(
                                (choice) => ChoiceChip(
                                  selected: advance == choice.key,
                                  label: Text(choice.label),
                                  onSelected: (_) =>
                                      setSheetState(() => advance = choice.key),
                                  selectedColor: EverloreTheme.gold.withValues(
                                    alpha: 0.16,
                                  ),
                                  backgroundColor: EverloreTheme.void3,
                                  side: BorderSide(
                                    color: EverloreTheme.gold.withValues(
                                      alpha: advance == choice.key
                                          ? 0.55
                                          : 0.18,
                                    ),
                                  ),
                                  labelStyle: EverloreTheme.ui(
                                    size: 12,
                                    color: advance == choice.key
                                        ? EverloreTheme.parchment
                                        : EverloreTheme.ash,
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 20),
                    _PrimaryAction(
                      label: destination.text.trim().isEmpty
                          ? 'Choose a destination'
                          : 'Begin journey',
                      enabled: destination.text.trim().length >= 2,
                      onTap: () {
                        if (destination.text.trim().length < 2) return;
                        Navigator.of(sheetContext).pop();
                        onTravel(
                          destination.text.trim(),
                          companions.toList(),
                          advance,
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// The codex is global; the journey party is local to this exact scene.
  /// A companion must be both present *and* an established character card.  Do
  /// not fall back to the raw presence label: the state extractor can observe a
  /// capitalized place name in prose, but a place must never become a traveller.
  List<String> _presentTravelCompanions() {
    final out = <String>[];
    final seen = <String>{};
    for (final raw in presentCharacters) {
      final key = raw.trim().toLowerCase();
      if (key.isEmpty || !seen.add(key)) continue;
      CharacterProfile? match;
      for (final character in characters) {
        final sameCanonical =
            character.canonicalName.trim().toLowerCase() == key;
        final sameAlias = character.aliases.any(
          (alias) => alias.trim().toLowerCase() == key,
        );
        if (sameCanonical || sameAlias) {
          match = character;
          break;
        }
      }
      if (match == null || match.isProtagonist) continue;
      // Defensive client-side seam for older/bad cards produced before the
      // backend presence guard. A location card is not a person to travel with.
      if (match.role.trim().toLowerCase() == 'location') continue;
      final display = match.canonicalName.trim();
      if (display.isNotEmpty) out.add(display);
      if (out.length >= 8) break;
    }
    return out;
  }

  void _showRelationshipSheet(BuildContext context) {
    final candidates = characters
        .where((c) => !c.isProtagonist)
        .take(20)
        .toList();
    CharacterProfile? character = candidates.isNotEmpty
        ? candidates.first
        : null;
    String? relation;
    var kinshipLoaded = false;
    var confirmedKinship = const <String, String>{};
    var correction = false;
    String? replacesRelation;
    const relations = [
      'mother',
      'father',
      'sister',
      'brother',
      'daughter',
      'son',
      'aunt',
      'uncle',
      'grandmother',
      'grandfather',
      'niece',
      'nephew',
      'cousin',
      'wife',
      'husband',
      'fiance',
      'fiancee',
      'partner',
    ];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: EverloreTheme.void2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _OwnedTextController(
        initialText: character?.canonicalName ?? '',
        builder: (controllerContext, name) => StatefulBuilder(
          builder: (modalContext, setSheetState) {
            if (!kinshipLoaded && loadConfirmedKinship != null) {
              kinshipLoaded = true;
              loadConfirmedKinship!()
                  .then((loaded) {
                    if (modalContext.mounted) {
                      setSheetState(() {
                        confirmedKinship = loaded;
                        final known =
                            confirmedKinship[character?.canonicalName
                                .toLowerCase()];
                        if (known != null && relations.contains(known)) {
                          relation = known;
                        }
                      });
                    }
                  })
                  .catchError((_) {});
            }
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                16 + MediaQuery.viewInsetsOf(modalContext).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SheetHeader(
                      icon: Icons.account_tree_outlined,
                      title: 'SET A RELATIONSHIP',
                      subtitle: 'This writes confirmed story canon.',
                      onBack: () {
                        Navigator.of(sheetContext).pop();
                        _open(context);
                      },
                    ),
                    if (candidates.isEmpty)
                      Text(
                        'Meet or establish a character before setting a relationship.',
                        style: EverloreTheme.ui(
                          size: 13,
                          color: EverloreTheme.ash,
                        ),
                      )
                    else ...[
                      _FieldLabel('CHARACTER'),
                      TextField(
                        controller: name,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 80,
                        onChanged: (value) => setSheetState(() {
                          final normalized = value.trim().toLowerCase();
                          final matchingCharacter = candidates
                              .where(
                                (candidate) =>
                                    candidate.canonicalName.toLowerCase() ==
                                    normalized,
                              )
                              .cast<CharacterProfile?>()
                              .firstOrNull;
                          if (matchingCharacter != null &&
                              matchingCharacter.id != character?.id) {
                            character = matchingCharacter;
                            relation =
                                confirmedKinship[matchingCharacter.canonicalName
                                    .toLowerCase()];
                            replacesRelation = null;
                          }
                        }),
                        style: EverloreTheme.ui(
                          size: 15,
                          color: EverloreTheme.parchment,
                        ),
                        decoration: _inputDecoration('Name this character')
                            .copyWith(
                              suffixIcon: PopupMenuButton<CharacterProfile>(
                                tooltip: 'Choose established character',
                                color: EverloreTheme.void3,
                                icon: Icon(
                                  Icons.arrow_drop_down_rounded,
                                  color: EverloreTheme.ash,
                                ),
                                onSelected: (selected) => setSheetState(() {
                                  character = selected;
                                  name.text = selected.canonicalName;
                                  relation =
                                      confirmedKinship[selected.canonicalName
                                          .toLowerCase()];
                                  replacesRelation = null;
                                }),
                                itemBuilder: (context) => candidates
                                    .map(
                                      (candidate) => PopupMenuItem(
                                        value: candidate,
                                        child: Text(
                                          candidate.canonicalName,
                                          style: EverloreTheme.ui(
                                            size: 14,
                                            color: EverloreTheme.parchment,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                      ),
                      Text(
                        name.text.trim().toLowerCase() ==
                                character?.canonicalName.toLowerCase()
                            ? 'Type to rename this character, or use the arrow to choose another.'
                            : 'Saving renames ${character?.canonicalName} and keeps their story ties intact.',
                        style: EverloreTheme.ui(
                          size: 11,
                          color: EverloreTheme.ash,
                        ),
                      ),
                      _FieldLabel('RELATION TO YOU'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: relations
                            .map(
                              (item) => ChoiceChip(
                                label: Text(_relationLabel(item)),
                                selected: relation == item,
                                onSelected: (_) => setSheetState(() {
                                  relation = item;
                                  replacesRelation = null;
                                }),
                                selectedColor: EverloreTheme.gold.withValues(
                                  alpha: 0.16,
                                ),
                                backgroundColor: EverloreTheme.void3,
                                side: BorderSide(
                                  color: EverloreTheme.gold.withValues(
                                    alpha: relation == item ? 0.55 : 0.18,
                                  ),
                                ),
                                labelStyle: EverloreTheme.ui(
                                  size: 12,
                                  color: relation == item
                                      ? EverloreTheme.parchment
                                      : EverloreTheme.ash,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: correction,
                        onChanged: relation == null
                            ? null
                            : (value) => setSheetState(() {
                                correction = value;
                                replacesRelation = null;
                              }),
                        title: Text(
                          'Replace an existing relationship',
                          style: EverloreTheme.ui(
                            size: 13,
                            color: EverloreTheme.parchment,
                          ),
                        ),
                        subtitle: Text(
                          'Choose the earlier relation to remove before saving this one.',
                          style: EverloreTheme.ui(
                            size: 11,
                            color: EverloreTheme.ash,
                          ),
                        ),
                        activeTrackColor: EverloreTheme.gold.withValues(
                          alpha: 0.55,
                        ),
                      ),
                      if (correction) ...[
                        _FieldLabel('REPLACE'),
                        DropdownButtonFormField<String>(
                          value: replacesRelation,
                          dropdownColor: EverloreTheme.void3,
                          style: EverloreTheme.ui(
                            size: 14,
                            color: EverloreTheme.parchment,
                          ),
                          decoration: _inputDecoration(
                            'Choose earlier relationship',
                          ),
                          items: relations
                              .where((item) => item != relation)
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(_relationLabel(item)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setSheetState(() => replacesRelation = value),
                        ),
                      ],
                      const SizedBox(height: 14),
                      _PrimaryAction(
                        label: correction
                            ? 'Correct relationship'
                            : 'Confirm relationship',
                        enabled:
                            character != null &&
                            relation != null &&
                            name.text.trim().length >= 2 &&
                            (!correction || replacesRelation != null),
                        onTap: () async {
                          if (character == null) return;
                          final selected = character!;
                          final typedName = name.text.trim();
                          final nextName =
                              typedName.toLowerCase() ==
                                  selected.canonicalName.toLowerCase()
                              ? selected.canonicalName
                              : typedName;
                          if (nextName.length < 2) return;
                          if (nextName != selected.canonicalName) {
                            final rename = onRenameCharacter;
                            if (rename == null ||
                                !await rename(selected, nextName)) {
                              return;
                            }
                            if (!sheetContext.mounted) return;
                          }
                          Navigator.of(sheetContext).pop();
                          onRelationship(
                            nextName,
                            relation!,
                            correction,
                            replacesRelation,
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _relationLabel(String relation) {
    const labels = {'fiance': 'Fiancé', 'fiancee': 'Fiancée'};
    return labels[relation] ??
        (relation[0].toUpperCase() + relation.substring(1));
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'World actions',
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? () => _open(context) : null,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: EverloreTheme.void3,
              border: Border.all(
                color: enabled
                    ? EverloreTheme.gold.withValues(alpha: 0.4)
                    : EverloreTheme.goldDim.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(
              Icons.tune_rounded,
              size: 19,
              color: enabled
                  ? EverloreTheme.gold.withValues(alpha: 0.9)
                  : EverloreTheme.ash.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    ),
  );
}

class _TimeChoice {
  final String? key;
  final String label;
  final IconData icon;
  const _TimeChoice(this.key, this.label, this.icon);
}

class _TimePill extends StatelessWidget {
  final _TimeChoice choice;
  final VoidCallback onTap;
  const _TimePill({required this.choice, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: EverloreTheme.void3,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: EverloreTheme.gold.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            choice.icon,
            size: 14,
            color: EverloreTheme.gold.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 6),
          Text(
            choice.label,
            style: EverloreTheme.ui(size: 11, color: EverloreTheme.parchment),
          ),
        ],
      ),
    ),
  );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: EverloreTheme.gold.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: EverloreTheme.gold.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: EverloreTheme.ui(
                    size: 14,
                    color: EverloreTheme.parchment,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: EverloreTheme.ui(size: 11, color: EverloreTheme.ash),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: EverloreTheme.ash.withValues(alpha: 0.55),
          ),
        ],
      ),
    ),
  );
}

class _SheetLabel extends StatelessWidget {
  final String text;
  const _SheetLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      text,
      style: EverloreTheme.ui(
        size: 10,
        weight: FontWeight.w700,
        color: EverloreTheme.gold.withValues(alpha: 0.65),
        spacing: 1.5,
      ),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      text,
      style: EverloreTheme.ui(
        size: 10,
        weight: FontWeight.w700,
        color: EverloreTheme.gold.withValues(alpha: 0.65),
        spacing: 1.4,
      ),
    ),
  );
}

/// Owns a field controller for exactly as long as its modal route is mounted.
/// Disposing from a modal's completion Future is too early: the route can still
/// rebuild its reverse-transition subtree after that Future has completed.
class _OwnedTextController extends StatefulWidget {
  final String initialText;
  final Widget Function(BuildContext context, TextEditingController controller)
  builder;

  const _OwnedTextController({this.initialText = '', required this.builder});

  @override
  State<_OwnedTextController> createState() => _OwnedTextControllerState();
}

class _OwnedTextControllerState extends State<_OwnedTextController> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}

class _SheetHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  const _SheetHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onBack,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (onBack != null) ...[
        IconButton(
          tooltip: 'Back to world actions',
          onPressed: onBack,
          icon: Icon(
            Icons.arrow_back_rounded,
            color: EverloreTheme.gold.withValues(alpha: 0.86),
          ),
        ),
        const SizedBox(width: 2),
      ],
      Icon(icon, color: EverloreTheme.gold.withValues(alpha: 0.86)),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: EverloreTheme.ui(
                size: 11,
                weight: FontWeight.w700,
                color: EverloreTheme.gold.withValues(alpha: 0.82),
                spacing: 1.8,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: EverloreTheme.ui(size: 12, color: EverloreTheme.ash),
            ),
          ],
        ),
      ),
    ],
  );
}

class _PrimaryAction extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _PrimaryAction({
    required this.label,
    required this.enabled,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: enabled ? onTap : null,
      style: FilledButton.styleFrom(
        backgroundColor: EverloreTheme.gold.withValues(alpha: 0.88),
        disabledBackgroundColor: EverloreTheme.void3,
        foregroundColor: EverloreTheme.void2,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: EverloreTheme.ui(
          size: 13,
          weight: FontWeight.w700,
          color: enabled ? EverloreTheme.void2 : EverloreTheme.ash,
        ),
      ),
    ),
  );
}

InputDecoration _inputDecoration(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: EverloreTheme.ui(
    size: 13,
    color: EverloreTheme.ash.withValues(alpha: 0.6),
  ),
  counterStyle: EverloreTheme.ui(size: 10, color: EverloreTheme.ash),
  filled: true,
  fillColor: EverloreTheme.void3,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: EverloreTheme.gold.withValues(alpha: 0.2)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: EverloreTheme.gold.withValues(alpha: 0.62)),
  ),
);
