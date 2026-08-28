import 'dart:async';
import '../../../core/guide/guide_anchor.dart';
import '../../../core/guide/guide_flows.dart';
import '../../../core/guide/guide_ids.dart';
import '../../../core/guide/guide_trigger.dart';

import 'package:flutter/material.dart';
import '../../../app/theme/nexus_theme.dart';
import '../../../shared/models/persona.dart';
import '../../../shared/widgets/everlore_top_bar.dart';
import '../../../shared/widgets/everlore_session_loader.dart';
import '../../../shared/widgets/everlore_empty_state.dart';
import '../../../shared/widgets/realm_backdrop.dart';
import '../data/persona_repository.dart';

const _genderOptions = [
  ('male', 'Male'),
  ('female', 'Female'),
  ('non_binary', 'Non-binary'),
];

class PersonasScreen extends StatefulWidget {
  const PersonasScreen({super.key});

  @override
  State<PersonasScreen> createState() => _PersonasScreenState();
}

class _PersonasScreenState extends State<PersonasScreen> {
  bool _loading = true;
  bool _loadingMore = false;
  bool _searchOpen = false;
  String? _error;
  List<Persona> _personas = const [];
  int _page = 1;
  int _total = 0;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await PersonaRepository.listPage(
        search: _searchController.text,
      );
      if (!mounted) return;
      setState(() {
        _personas = result.personas;
        _page = result.page;
        _total = result.total;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load personas.';
        _loading = false;
      });
    }
  }

  void _maybeLoadMore() {
    if (_scrollController.position.extentAfter > 480) return;
    if (_loading || _loadingMore || _personas.length >= _total) return;
    _loadMore();
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final result = await PersonaRepository.listPage(
        page: _page + 1,
        search: _searchController.text,
      );
      if (!mounted) return;
      final known = _personas.map((p) => p.id).toSet();
      setState(() {
        _personas = [
          ..._personas,
          ...result.personas.where((persona) => known.add(persona.id)),
        ];
        _page = result.page;
        _total = result.total;
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _setSearchOpen() {
    setState(() => _searchOpen = !_searchOpen);
    if (!_searchOpen && _searchController.text.isNotEmpty) {
      _searchDebounce?.cancel();
      _searchController.clear();
      _load();
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), _load);
  }

  Future<void> _openEditor([Persona? persona]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: EverloreTheme.void2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PersonaEditorSheet(persona: persona),
    );
    if (changed == true) _load();
  }

  Future<void> _delete(Persona persona) async {
    await PersonaRepository.delete(persona.id);
    if (!mounted) return;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EverloreTheme.void0,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/art/persona-muse.webp',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          const EmberOverlay(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  EverloreTheme.void0.withValues(alpha: 0.2),
                  EverloreTheme.void0.withValues(alpha: 0.55),
                  EverloreTheme.void0.withValues(alpha: 0.8),
                ],
                stops: const [0, 0.42, 1],
              ),
            ),
          ),
          GuideOnEnter(
            flow: GuideFlows.personas,
            child: Column(
              children: [
                EverloreTopBar(
                  title: 'Personas',
                  subtitle: _total == 0
                      ? 'Saved identities'
                      : '$_total saved identities',
                  backgroundOpacity: 0.68,
                  actions: [
                    EverloreTopBarIcon(
                      icon: _searchOpen
                          ? Icons.close_rounded
                          : Icons.search_rounded,
                      tooltip: _searchOpen ? 'Close search' : 'Search personas',
                      onTap: _setSearchOpen,
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: _searchOpen
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            onChanged: _onSearchChanged,
                            textInputAction: TextInputAction.search,
                            style: EverloreTheme.ui(
                              size: 14,
                              color: EverloreTheme.parchment,
                            ),
                            decoration: _searchDecoration('Search personas'),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                // Creation lives here only once the vault has entries — the
                // empty state's central "Create persona" button owns first-run.
                if (!_loading && _error == null && _personas.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      children: [
                        Text(
                          'YOUR PERSONAS',
                          style: EverloreTheme.sectionHeader,
                        ),
                        const Spacer(),
                        GuideAnchor(
                          id: GuideIds.personasAdd,
                          child: Semantics(
                            button: true,
                            child: GestureDetector(
                              onTap: () => _openEditor(),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                // 14pt vertical padding keeps the pill at the
                                // 48pt minimum tap target.
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      EverloreTheme.goldGlow,
                                      EverloreTheme.gold,
                                    ],
                                  ),
                                  border: Border.all(
                                    color: EverloreTheme.goldHot.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: EverloreTheme.gold.withValues(
                                        alpha: 0.25,
                                      ),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.add_rounded,
                                      size: 16,
                                      color: EverloreTheme.void0,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'New persona',
                                      style: TextStyle(
                                        fontFamily: EverloreTheme.uiFamily,
                                        color: EverloreTheme.void0,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    color: EverloreTheme.gold,
                    backgroundColor: EverloreTheme.void2,
                    child: ListView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),
                      children: [
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.only(top: 64),
                            child: Center(
                              child: EverloreSessionLoader(
                                message: 'Gathering personas',
                              ),
                            ),
                          )
                        else if (_error != null)
                          _EmptyPersonaState(text: _error!, action: _load)
                        else if (_personas.isEmpty)
                          _EmptyPersonaState(
                            text: _searchController.text.isNotEmpty
                                ? 'No personas match that search.'
                                : 'No personas yet.',
                            action: _searchController.text.isNotEmpty
                                ? () {
                                    _searchController.clear();
                                    _load();
                                  }
                                : () => _openEditor(),
                            actionLabel: _searchController.text.isNotEmpty
                                ? 'Clear search'
                                : 'Create persona',
                          )
                        else ...[
                          for (final p in _personas)
                            _PersonaCard(
                              persona: p,
                              onTap: () => _openEditor(p),
                              onDelete: () => _delete(p),
                            ),
                          if (_loadingMore)
                            const Padding(
                              padding: EdgeInsets.all(18),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: EverloreTheme.gold,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
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

InputDecoration _searchDecoration(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: EverloreTheme.ui(size: 14, color: EverloreTheme.ash),
  prefixIcon: const Icon(Icons.search_rounded, color: EverloreTheme.goldDim),
  filled: true,
  fillColor: EverloreTheme.void2,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(
      color: EverloreTheme.goldDim.withValues(alpha: 0.22),
    ),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(
      color: EverloreTheme.goldDim.withValues(alpha: 0.22),
    ),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: EverloreTheme.gold, width: 1.2),
  ),
);

class _PersonaCard extends StatelessWidget {
  final Persona persona;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PersonaCard({
    required this.persona,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final meta = [
      _genderOptions
          .firstWhere(
            (g) => g.$1 == persona.gender,
            orElse: () => _genderOptions.last,
          )
          .$2,
      if (persona.age != null) '${persona.age}',
    ].join(' • ');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: EverloreTheme.void2.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: EverloreTheme.goldDim.withValues(alpha: 0.22),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          persona.name,
          style: EverloreTheme.ui(
            size: 16,
            weight: FontWeight.w700,
            color: EverloreTheme.parchment,
          ),
        ),
        subtitle: Text(
          [
            meta,
            if (persona.description.trim().isNotEmpty) persona.description,
          ].join('\n'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: EverloreTheme.ui(
            size: 12,
            color: EverloreTheme.ash,
            height: 1.35,
          ),
        ),
        trailing: IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, color: EverloreTheme.crimson),
        ),
      ),
    );
  }
}

class _EmptyPersonaState extends StatelessWidget {
  final String text;
  final VoidCallback action;
  final String actionLabel;

  const _EmptyPersonaState({
    required this.text,
    required this.action,
    this.actionLabel = 'Retry',
  });

  @override
  Widget build(BuildContext context) {
    final isInitial = actionLabel == 'Create persona';
    return EverloreEmptyState(
      icon: isInitial
          ? Icons.person_add_alt_1_rounded
          : Icons.cloud_off_rounded,
      eyebrow: isInitial ? 'PERSONA VAULT' : 'CONNECTION LOST',
      title: isInitial
          ? 'Who will you become?'
          : 'Your personas are out of reach',
      message: isInitial
          ? 'Create a reusable identity for your journeys. Your name, voice, and story begin here.'
          : text,
      actionLabel: actionLabel,
      actionIcon: isInitial ? Icons.add_rounded : Icons.refresh_rounded,
      accent: isInitial ? EverloreTheme.gold : EverloreTheme.crimson,
      // The walkthrough's "Masks" beat targets the Create persona button
      // itself. It only exists while the vault is empty, so the beat degrades
      // to a floating card once the player has personas — by design.
      anchorId: isInitial ? GuideIds.personasCreate : null,
      onAction: action,
      compact: false,
      artAsset: null,
    );
  }
}

class _PersonaEditorSheet extends StatefulWidget {
  final Persona? persona;
  const _PersonaEditorSheet({this.persona});

  @override
  State<_PersonaEditorSheet> createState() => _PersonaEditorSheetState();
}

class _PersonaEditorSheetState extends State<_PersonaEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _description;
  late final TextEditingController _other;
  late String _gender;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.persona;
    _name = TextEditingController(text: p?.name ?? '');
    _age = TextEditingController(text: p?.age?.toString() ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _other = TextEditingController(text: p?.otherInfo ?? '');
    _gender = p?.gender ?? 'non_binary';
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _description.dispose();
    _other.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    final ageText = _age.text.trim();
    final age = ageText.isEmpty ? null : int.tryParse(ageText);
    setState(() => _saving = true);
    try {
      if (widget.persona == null) {
        await PersonaRepository.create(
          name: name,
          gender: _gender,
          age: age,
          description: _description.text,
          otherInfo: _other.text,
        );
      } else {
        await PersonaRepository.update(
          widget.persona!.id,
          name: name,
          gender: _gender,
          age: age,
          clearAge: ageText.isEmpty,
          description: _description.text,
          otherInfo: _other.text,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: EverloreTheme.goldDim.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.persona == null ? 'New Persona' : 'Edit Persona',
                style: EverloreTheme.serifDisplay(
                  size: 22,
                  color: EverloreTheme.parchment,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.persona == null
                    ? 'A reusable identity for your journeys.'
                    : 'Refine the identity carried into your journeys.',
                style: EverloreTheme.ui(size: 13, color: EverloreTheme.ash),
              ),
              const SizedBox(height: 22),
              _PersonaField(
                controller: _name,
                label: 'Name',
                hint: 'The name you want to be known by',
                maxLength: 60,
                required: true,
              ),
              const SizedBox(height: 18),
              Text(
                'IDENTITY',
                style: EverloreTheme.ui(
                  size: 11,
                  color: EverloreTheme.goldDim,
                  weight: FontWeight.w700,
                  spacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final g in _genderOptions)
                    ChoiceChip(
                      label: Text(g.$2),
                      selected: _gender == g.$1,
                      onSelected: (_) => setState(() => _gender = g.$1),
                      selectedColor: EverloreTheme.gold.withValues(alpha: 0.18),
                      backgroundColor: EverloreTheme.void3,
                      labelStyle: EverloreTheme.ui(
                        size: 12,
                        color: _gender == g.$1
                            ? EverloreTheme.gold
                            : EverloreTheme.ash,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _PersonaField(
                controller: _age,
                label: 'Age',
                hint: 'Optional · 13–120',
                keyboardType: TextInputType.number,
                optional: true,
              ),
              const SizedBox(height: 18),
              _PersonaField(
                controller: _description,
                label: 'Persona essence',
                hint: 'A few traits, a voice, or a past they carry.',
                helper: 'This helps a world recognize who you are.',
                maxLength: 500,
                maxLines: 3,
                optional: true,
              ),
              const SizedBox(height: 18),
              _PersonaField(
                controller: _other,
                label: 'Private notes',
                hint: 'Anything else you want remembered.',
                helper: 'Optional details for future journeys.',
                maxLength: 500,
                maxLines: 3,
                optional: true,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EverloreTheme.gold,
                    foregroundColor: EverloreTheme.void0,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(_saving ? 'Saving persona…' : 'Save persona'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonaField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? helper;
  final int? maxLength;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool required;
  final bool optional;

  const _PersonaField({
    required this.controller,
    required this.label,
    required this.hint,
    this.helper,
    this.maxLength,
    this.maxLines = 1,
    this.keyboardType,
    this.required = false,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label.toUpperCase(),
                style: EverloreTheme.ui(
                  size: 11,
                  color: EverloreTheme.goldDim,
                  weight: FontWeight.w700,
                  spacing: 1.1,
                ),
              ),
              if (required) ...[
                const SizedBox(width: 6),
                Text(
                  'REQUIRED',
                  style: EverloreTheme.ui(size: 10, color: EverloreTheme.ash),
                ),
              ] else if (optional) ...[
                const SizedBox(width: 6),
                Text(
                  'OPTIONAL',
                  style: EverloreTheme.ui(size: 10, color: EverloreTheme.ash),
                ),
              ],
              const Spacer(),
              if (maxLength != null)
                Text(
                  '${value.text.characters.length} / $maxLength',
                  style: EverloreTheme.ui(size: 11, color: EverloreTheme.ash),
                ),
            ],
          ),
          if (helper != null) ...[
            const SizedBox(height: 4),
            Text(
              helper!,
              style: EverloreTheme.ui(size: 12, color: EverloreTheme.ash),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLength: maxLength,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: EverloreTheme.ui(size: 14, color: EverloreTheme.parchment),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: EverloreTheme.ui(size: 14, color: EverloreTheme.ash),
              counterText: '',
              filled: true,
              fillColor: EverloreTheme.void3,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: maxLines > 1 ? 14 : 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: EverloreTheme.goldDim.withValues(alpha: 0.26),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: EverloreTheme.goldDim.withValues(alpha: 0.26),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: EverloreTheme.gold,
                  width: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
