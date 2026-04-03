import 'package:flutter/material.dart';

class PlayerInput extends StatefulWidget {
  final bool isGenerating;
  final bool isConnected;
  final ValueChanged<String> onSend;

  const PlayerInput({
    super.key,
    required this.isGenerating,
    required this.isConnected,
    required this.onSend,
  });

  @override
  State<PlayerInput> createState() => _PlayerInputState();
}

class _PlayerInputState extends State<PlayerInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isGenerating) return;
    widget.onSend(text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0d0d1a),
        border: Border(
          top: BorderSide(color: Colors.white10),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: !widget.isGenerating,
                maxLines: 4,
                minLines: 1,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: widget.isGenerating
                      ? 'Waiting for response...'
                      : widget.isConnected
                          ? 'What do you do?'
                          : 'Reconnecting...',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF1a1a2e),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              onPressed: widget.isGenerating ? null : _submit,
              backgroundColor: widget.isGenerating
                  ? Colors.white12
                  : Colors.purpleAccent,
              child: widget.isGenerating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white38,
                      ),
                    )
                  : const Icon(Icons.send, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
