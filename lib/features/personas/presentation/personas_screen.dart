import 'package:flutter/material.dart';
import '../../../app/theme/nexus_theme.dart';
import '../../../shared/models/persona.dart';
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
  String? _error;
  List<Persona> _personas = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await PersonaRepository.list(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _personas = rows;
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
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: EverloreTheme.gold,
          backgroundColor: EverloreTheme.void2,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Personas',
                      style: EverloreTheme.serifDisplay(
                        size: 30,
                        color: EverloreTheme.parchment,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _openEditor(),
                    icon: const Icon(Icons.add, color: EverloreTheme.gold),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: CircularProgressIndicator(color: EverloreTheme.gold),
                  ),
                )
              else if (_error != null)
                _EmptyPersonaState(text: _error!, action: _load)
              else if (_personas.isEmpty)
                _EmptyPersonaState(
                  text: 'No personas yet.',
                  action: () => _openEditor(),
                  actionLabel: 'Create persona',
                )
              else
                for (final p in _personas)
                  _PersonaCard(
                    persona: p,
                    onTap: () => _openEditor(p),
                    onDelete: () => _delete(p),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

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
      _genderOptions.firstWhere(
        (g) => g.$1 == persona.gender,
        orElse: () => _genderOptions.last,
      ).$2,
      if (persona.age != null) '${persona.age}',
    ].join(' • ');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: EverloreTheme.void2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EverloreTheme.goldDim.withValues(alpha: 0.22)),
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
          style: EverloreTheme.ui(size: 12, color: EverloreTheme.ash, height: 1.35),
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
    return Padding(
      padding: const EdgeInsets.only(top: 90),
      child: Column(
        children: [
          Text(text, style: EverloreTheme.ui(size: 14, color: EverloreTheme.ash)),
          const SizedBox(height: 14),
          TextButton(
            onPressed: action,
            child: Text(actionLabel, style: const TextStyle(color: EverloreTheme.gold)),
          ),
        ],
      ),
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
              Text(
                widget.persona == null ? 'New Persona' : 'Edit Persona',
                style: EverloreTheme.serifDisplay(size: 22, color: EverloreTheme.parchment),
              ),
              const SizedBox(height: 16),
              _PersonaField(controller: _name, label: 'Name', maxLength: 60),
              const SizedBox(height: 12),
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
                        color: _gender == g.$1 ? EverloreTheme.gold : EverloreTheme.ash,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _PersonaField(
                controller: _age,
                label: 'Age',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              _PersonaField(
                controller: _description,
                label: 'Description',
                maxLength: 500,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              _PersonaField(
                controller: _other,
                label: 'Other information',
                maxLength: 500,
                maxLines: 4,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EverloreTheme.gold,
                    foregroundColor: EverloreTheme.void0,
                  ),
                  child: Text(_saving ? 'Saving...' : 'Save'),
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
  final int? maxLength;
  final int maxLines;
  final TextInputType? keyboardType;

  const _PersonaField({
    required this.controller,
    required this.label,
    this.maxLength,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: EverloreTheme.ui(size: 14, color: EverloreTheme.parchment),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: EverloreTheme.ui(size: 12, color: EverloreTheme.ash),
        filled: true,
        fillColor: EverloreTheme.void3,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
