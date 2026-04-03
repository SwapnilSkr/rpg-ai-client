import 'package:flutter/material.dart';
import '../../../../shared/models/event.dart';

class NarrativeBubble extends StatelessWidget {
  final GameEvent event;
  final VoidCallback? onLongPress;

  const NarrativeBubble({
    super.key,
    required this.event,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Player input
        if (event.playerInput != null && event.playerInput!.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.only(left: 60, right: 16, top: 8, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.purpleAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.purpleAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                event.playerInput!,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ),

        // AI response
        if (event.aiResponse != null && event.aiResponse!.isNotEmpty)
          GestureDetector(
            onLongPress: onLongPress,
            child: Container(
              margin: const EdgeInsets.only(left: 16, right: 60, top: 4, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1a1a2e),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.aiResponse!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  if (event.sceneTag != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _tagColor(event.sceneTag!).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            event.sceneTag!,
                            style: TextStyle(
                              color: _tagColor(event.sceneTag!),
                              fontSize: 10,
                            ),
                          ),
                        ),
                        if (event.isUserEdited) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.edit, size: 12, color: Colors.white24),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

        // Optimistic loading indicator
        if (event.isOptimistic && event.aiResponse == null)
          Container(
            margin: const EdgeInsets.only(left: 16, right: 60, top: 4, bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1a1a2e),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.purpleAccent,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'The world is responding...',
                  style: TextStyle(
                    color: Colors.white38,
                    fontStyle: FontStyle.italic,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Color _tagColor(String tag) {
    return switch (tag) {
      'combat' => Colors.redAccent,
      'intimate' => Colors.pinkAccent,
      'exploration' => Colors.greenAccent,
      'existential' => Colors.cyanAccent,
      'cosmic' => Colors.deepPurpleAccent,
      'mundane' => Colors.grey,
      _ => Colors.blueAccent,
    };
  }
}
