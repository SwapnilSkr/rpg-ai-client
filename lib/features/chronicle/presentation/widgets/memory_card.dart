import 'package:flutter/material.dart';
import '../../../../shared/models/memory.dart';

class MemoryCard extends StatelessWidget {
  final Memory memory;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const MemoryCard({
    super.key,
    required this.memory,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1a1a2e),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _typeColor(memory.type).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    memory.type,
                    style: TextStyle(
                      color: _typeColor(memory.type),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ...List.generate(
                  memory.importance,
                  (_) => const Icon(Icons.star, size: 10, color: Colors.amber),
                ),
                const Spacer(),
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit, size: 16, color: Colors.white38),
                    onPressed: onEdit,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: Colors.white38),
                    onPressed: onDelete,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              memory.text,
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
            ),
            if (memory.isArchived)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Archived',
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    return switch (type) {
      'relationship' => Colors.pinkAccent,
      'promise' => Colors.amberAccent,
      'lore' => Colors.cyanAccent,
      'observation' => Colors.blueAccent,
      'emotion' => Colors.purpleAccent,
      'secret' => Colors.redAccent,
      _ => Colors.grey,
    };
  }
}
