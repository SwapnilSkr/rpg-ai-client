import 'package:flutter/material.dart';
import '../../../../shared/models/world_instance.dart';

class WorldCard extends StatelessWidget {
  final WorldInstance instance;
  final VoidCallback onTap;
  final VoidCallback? onArchive;

  const WorldCard({
    super.key,
    required this.instance,
    required this.onTap,
    this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final title = instance.template?['title'] ?? 'Untitled World';
    final description = instance.template?['description'] ?? '';
    final isSentient = instance.template?['is_sentient'] ?? false;

    return Card(
      color: const Color(0xFF1a1a2e),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isSentient ? Icons.psychology : Icons.auto_stories,
                    color: isSentient
                        ? Colors.purpleAccent
                        : Colors.blueAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (onArchive != null)
                    IconButton(
                      icon: const Icon(Icons.archive_outlined,
                          color: Colors.white38, size: 20),
                      onPressed: onArchive,
                    ),
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _chip('${instance.meta.totalEvents} events'),
                  const SizedBox(width: 8),
                  _chip('${instance.meta.totalMemories} memories'),
                  const Spacer(),
                  Text(
                    _timeAgo(instance.meta.lastActiveAt),
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white54, fontSize: 11)),
    );
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}
