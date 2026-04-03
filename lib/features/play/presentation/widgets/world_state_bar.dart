import 'package:flutter/material.dart';
import '../../../../shared/widgets/stat_bar.dart';

class WorldStateBar extends StatelessWidget {
  final Map<String, num> worldState;
  final bool expanded;
  final VoidCallback onToggle;

  const WorldStateBar({
    super.key,
    required this.worldState,
    this.expanded = false,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: const Color(0xFF12122a),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'World State',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white38,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: worldState.entries
                    .map((e) => StatBar(
                          label: _formatLabel(e.key),
                          value: e.value,
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _formatLabel(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }
}
