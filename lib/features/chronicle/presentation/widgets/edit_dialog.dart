import 'package:flutter/material.dart';
import '../../../../../app/theme/nexus_theme.dart';

class EditMemoryDialog extends StatefulWidget {
  final String initialText;
  final String initialType;
  final int initialImportance;

  const EditMemoryDialog({
    super.key,
    required this.initialText,
    required this.initialType,
    required this.initialImportance,
  });

  @override
  State<EditMemoryDialog> createState() => _EditMemoryDialogState();
}

class _EditMemoryDialogState extends State<EditMemoryDialog> {
  late TextEditingController _textController;
  late String _type;
  late int _importance;

  static const _types = [
    ('relationship', 'Bond', Icons.favorite_outline),
    ('promise', 'Oath', Icons.handshake_outlined),
    ('lore', 'Lore', Icons.auto_stories),
    ('observation', 'Sight', Icons.visibility_outlined),
    ('emotion', 'Feeling', Icons.sentiment_satisfied_outlined),
    ('secret', 'Secret', Icons.lock_outline),
  ];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
    _type = widget.initialType;
    _importance = widget.initialImportance;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Color _typeColor(String type) {
    return switch (type) {
      'relationship' => const Color(0xFFEC4899),
      'promise' => EverloreTheme.gold,
      'lore' => EverloreTheme.cyanBright,
      'observation' => EverloreTheme.violetBright,
      'emotion' => const Color(0xFFF97316),
      'secret' => EverloreTheme.crimson,
      _ => EverloreTheme.ash,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: EverloreTheme.void2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: EverloreTheme.goldDim.withValues(alpha: 0.4)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.bookmark_outline,
                    color: EverloreTheme.gold, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Edit Echo',
                  style: TextStyle(
                    color: EverloreTheme.parchment,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close,
                        color: EverloreTheme.ash, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Text field
            const Text('Memory', style: EverloreTheme.sectionHeader),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              maxLines: 4,
              style: const TextStyle(
                color: EverloreTheme.parchment,
                fontSize: 14,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: 'What was remembered...',
                fillColor: EverloreTheme.void3,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: EverloreTheme.goldDim.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: EverloreTheme.goldDim.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: EverloreTheme.gold),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Type selector
            const Text('Type', style: EverloreTheme.sectionHeader),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _types.map((typeData) {
                final (value, label, icon) = typeData;
                final selected = _type == value;
                final color = _typeColor(value);
                return GestureDetector(
                  onTap: () => setState(() => _type = value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: selected
                          ? color.withValues(alpha: 0.15)
                          : EverloreTheme.void3,
                      border: Border.all(
                        color: selected
                            ? color.withValues(alpha: 0.6)
                            : EverloreTheme.goldDim.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon,
                            size: 12,
                            color: selected ? color : EverloreTheme.ash),
                        const SizedBox(width: 5),
                        Text(
                          label,
                          style: TextStyle(
                            color: selected ? color : EverloreTheme.ash,
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Importance
            Row(
              children: [
                const Text('Importance', style: EverloreTheme.sectionHeader),
                const Spacer(),
                ...List.generate(
                  5,
                  (i) => GestureDetector(
                    onTap: () => setState(() => _importance = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Icon(
                        i < _importance
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 20,
                        color: i < _importance
                            ? EverloreTheme.gold
                            : EverloreTheme.white20,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EverloreTheme.ash,
                      side: BorderSide(
                          color: EverloreTheme.white20),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, {
                      'text': _textController.text,
                      'type': _type,
                      'importance': _importance,
                    }),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EverloreTheme.gold,
                      foregroundColor: EverloreTheme.void0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Save Echo'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
