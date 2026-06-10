import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../../state/chronicle_cubit.dart';

/// Search + filters for the Echoes (memories) tab. Search runs on submit
/// (full-text, server-side); the toggle chips apply immediately.
class EchoesFilterBar extends StatefulWidget {
  const EchoesFilterBar({super.key});

  @override
  State<EchoesFilterBar> createState() => _EchoesFilterBarState();
}

class _EchoesFilterBarState extends State<EchoesFilterBar> {
  late final TextEditingController _controller;

  static const _types = <String>[
    'relationship',
    'promise',
    'lore',
    'observation',
    'emotion',
    'secret',
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: context.read<ChronicleCubit>().state.memoryQuery,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ChronicleCubit>();
    return BlocBuilder<ChronicleCubit, ChronicleState>(
      buildWhen: (a, b) =>
          a.memoryType != b.memoryType ||
          a.memoryUnresolved != b.memoryUnresolved ||
          a.memoryHighImportance != b.memoryHighImportance ||
          a.memoryQuery != b.memoryQuery,
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: EverloreTheme.white10)),
          ),
          child: Column(
            children: [
              // Search field
              TextField(
                controller: _controller,
                style: const TextStyle(
                    color: EverloreTheme.parchment, fontSize: 14),
                textInputAction: TextInputAction.search,
                onSubmitted: (v) => cubit.setMemoryFilters(query: v),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search echoes…',
                  hintStyle: const TextStyle(
                      color: EverloreTheme.ash, fontSize: 14),
                  prefixIcon: const Icon(Icons.search,
                      color: EverloreTheme.ash, size: 18),
                  suffixIcon: state.memoryQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close,
                              color: EverloreTheme.ash, size: 16),
                          onPressed: () {
                            _controller.clear();
                            cubit.setMemoryFilters(query: '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: EverloreTheme.void2,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: EverloreTheme.white10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: EverloreTheme.goldDim.withValues(alpha: 0.6)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _Chip(
                      label: 'Unresolved',
                      active: state.memoryUnresolved,
                      onTap: () => cubit.setMemoryFilters(
                          unresolved: !state.memoryUnresolved),
                    ),
                    const SizedBox(width: 8),
                    _Chip(
                      label: 'Important',
                      active: state.memoryHighImportance,
                      onTap: () => cubit.setMemoryFilters(
                          highImportance: !state.memoryHighImportance),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 1,
                      height: 22,
                      color: EverloreTheme.white10,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    const SizedBox(width: 4),
                    for (final type in _types) ...[
                      _Chip(
                        label: _label(type),
                        active: state.memoryType == type,
                        onTap: () => cubit.setMemoryFilters(
                          type: state.memoryType == type ? '' : type,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _label(String t) => t[0].toUpperCase() + t.substring(1);
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: active
              ? EverloreTheme.gold.withValues(alpha: 0.14)
              : EverloreTheme.void2,
          border: Border.all(
            color: active
                ? EverloreTheme.goldDim.withValues(alpha: 0.6)
                : EverloreTheme.goldDim.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? EverloreTheme.gold : EverloreTheme.ash,
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
