import 'package:flutter/material.dart';

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

  final _types = [
    'relationship', 'promise', 'lore', 'observation', 'emotion', 'secret'
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1a1a2e),
      title: const Text('Edit Memory', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _textController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Memory text',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.purpleAccent),
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _type,
              dropdownColor: const Color(0xFF2a2a3e),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Type',
                labelStyle: TextStyle(color: Colors.white54),
              ),
              items: _types
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (val) => setState(() => _type = val ?? _type),
            ),
            const SizedBox(height: 16),
            const Text('Importance', style: TextStyle(color: Colors.white54)),
            Slider(
              value: _importance.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: '$_importance',
              activeColor: Colors.purpleAccent,
              onChanged: (val) => setState(() => _importance = val.round()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, {
            'text': _textController.text,
            'type': _type,
            'importance': _importance,
          }),
          child: const Text('Save', style: TextStyle(color: Colors.purpleAccent)),
        ),
      ],
    );
  }
}
