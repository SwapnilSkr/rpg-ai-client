import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme/nexus_theme.dart';
import '../../../core/network/ws_manager.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/chronicle_repository.dart';
import '../data/side_chat_data.dart';

class SideChatScreen extends StatefulWidget {
  final String instanceId;
  final String characterId;
  final String characterName;

  const SideChatScreen({
    super.key,
    required this.instanceId,
    required this.characterId,
    required this.characterName,
  });

  @override
  State<SideChatScreen> createState() => _SideChatScreenState();
}

class _SideChatScreenState extends State<SideChatScreen> {
  final _ws = WsManager();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _turns = <SideChatTurn>[];
  final _subs = <StreamSubscription>[];

  SideChatCharacter? _character;
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bindSocket();
    _connectSocket();
    _load();
  }

  void _bindSocket() {
    _subs.add(
      _ws.onSideChatDelta.listen((msg) {
        if (!_matches(msg)) return;
        _appendDelta(msg['delta']?.toString() ?? '');
      }),
    );
    _subs.add(
      _ws.onSideChatComplete.listen((msg) {
        if (!_matches(msg)) return;
        final event = msg['event'];
        if (event is! Map) return;
        final narrative = event['narrative']?.toString() ?? '';
        final finalTurn = SideChatTurn(
          id: event['id']?.toString() ?? '',
          sequence: (event['sequence'] as num?)?.toInt() ?? 0,
          playerInput: event['player_input']?.toString() ?? _lastPlayerInput(),
          narrative: narrative,
          createdAt:
              DateTime.tryParse(event['created_at']?.toString() ?? '') ??
              DateTime.now(),
        );
        _replaceStreaming(finalTurn);
        setState(() {
          _isSending = false;
          _error = null;
        });
        _scrollToEnd();
      }),
    );
    _subs.add(
      _ws.onSideChatError.listen((msg) {
        if (!_matches(msg)) return;
        _failSend(msg['message']?.toString() ?? 'The thread fell silent.');
      }),
    );
    _subs.add(
      _ws.onError.listen((msg) {
        if (msg['instanceId'] != null &&
            msg['instanceId']?.toString() != widget.instanceId) {
          return;
        }
        if (!_isSending) return;
        _failSend(msg['message']?.toString() ?? 'Could not send that message.');
      }),
    );
  }

  bool _matches(Map<String, dynamic> msg) {
    if (msg['instanceId']?.toString() != widget.instanceId) return false;
    final cid =
        msg['characterId']?.toString() ??
        (msg['character'] is Map
            ? (msg['character'] as Map)['id']?.toString()
            : null);
    return cid == null || cid == widget.characterId;
  }

  Future<void> _connectSocket() async {
    final token = await SecureStore.getToken();
    if (token == null || token.isEmpty) return;
    await _ws.connect(token);
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await ChronicleRepository.getSideChatThread(
        widget.instanceId,
        widget.characterId,
      );
      if (!mounted) return;
      setState(() {
        _character = data.character;
        _turns
          ..clear()
          ..addAll(data.events);
        _isLoading = false;
      });
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty || _isSending) return;
    _input.clear();
    setState(() {
      _isSending = true;
      _error = null;
      _turns.add(
        SideChatTurn(
          id: 'pending-${DateTime.now().microsecondsSinceEpoch}',
          sequence: 0,
          playerInput: text,
          narrative: '',
          createdAt: DateTime.now(),
          isStreaming: true,
          isOptimistic: true,
        ),
      );
    });
    _scrollToEnd();
    _ws.sendSideChatMessage(widget.instanceId, widget.characterId, text);
  }

  void _appendDelta(String delta) {
    if (delta.isEmpty) return;
    final idx = _turns.lastIndexWhere((t) => t.isStreaming);
    if (idx < 0) return;
    setState(() {
      _turns[idx] = _turns[idx].copyWith(
        narrative: '${_turns[idx].narrative}$delta',
      );
    });
    _scrollToEnd();
  }

  void _replaceStreaming(SideChatTurn turn) {
    final idx = _turns.lastIndexWhere((t) => t.isStreaming);
    if (idx >= 0) {
      _turns[idx] = turn;
    } else {
      _turns.add(turn);
    }
  }

  String _lastPlayerInput() {
    final idx = _turns.lastIndexWhere((t) => t.isStreaming);
    return idx >= 0 ? _turns[idx].playerInput : '';
  }

  void _failSend(String message) {
    setState(() {
      _isSending = false;
      _error = message;
      _turns.removeWhere((t) => t.isOptimistic && t.isStreaming);
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = _character?.name ?? widget.characterName;
    return Scaffold(
      backgroundColor: EverloreTheme.void1,
      body: Column(
        children: [
          _Header(name: name, role: _character?.role),
          Expanded(child: _body(name)),
          if (_error != null) _ErrorStrip(message: _error!, onRetry: _load),
          _Composer(controller: _input, enabled: !_isSending, onSend: _send),
        ],
      ),
    );
  }

  Widget _body(String name) {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: EverloreTheme.gold,
          ),
        ),
      );
    }
    if (_turns.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            'No private words with $name yet.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: EverloreTheme.ash,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _turns.length,
      itemBuilder: (context, i) => _TurnTile(turn: _turns[i], name: name),
    );
  }
}

class _Header extends StatelessWidget {
  final String name;
  final String? role;

  const _Header({required this.name, this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: EverloreTheme.void0,
        border: Border(bottom: BorderSide(color: EverloreTheme.white10)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 16, 14),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: EverloreTheme.ash,
                  size: 18,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Icon(
                Icons.forum_outlined,
                color: EverloreTheme.gold,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: EverloreTheme.parchment,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (role != null && role!.trim().isNotEmpty)
                      Text(
                        role!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: EverloreTheme.ash.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TurnTile extends StatelessWidget {
  final SideChatTurn turn;
  final String name;

  const _TurnTile({required this.turn, required this.name});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Bubble(
            text: turn.playerInput,
            alignRight: true,
            color: EverloreTheme.goldDim.withValues(alpha: 0.14),
            borderColor: EverloreTheme.goldDim.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 8),
          _Bubble(
            text: turn.narrative.isEmpty && turn.isStreaming
                ? '$name is answering...'
                : turn.narrative,
            alignRight: false,
            color: EverloreTheme.void2,
            borderColor: EverloreTheme.white10,
            italic: turn.narrative.isEmpty && turn.isStreaming,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool alignRight;
  final Color color;
  final Color borderColor;
  final bool italic;

  const _Bubble({
    required this.text,
    required this.alignRight,
    required this.color,
    required this.borderColor,
    this.italic = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: color,
            border: Border.all(color: borderColor),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: EverloreTheme.parchment,
              fontSize: 14,
              height: 1.45,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorStrip extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorStrip({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: EverloreTheme.crimson.withValues(alpha: 0.12),
        border: Border.all(color: EverloreTheme.crimson.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: EverloreTheme.crimson,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: EverloreTheme.ash, fontSize: 12),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: const BoxDecoration(
          color: EverloreTheme.void0,
          border: Border(top: BorderSide(color: EverloreTheme.white10)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                style: const TextStyle(color: EverloreTheme.parchment),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: enabled ? 'Speak privately...' : 'Waiting...',
                  hintStyle: const TextStyle(color: EverloreTheme.ash),
                  filled: true,
                  fillColor: EverloreTheme.void2,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: EverloreTheme.white10),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: EverloreTheme.white10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: EverloreTheme.goldDim),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: EverloreTheme.goldDim.withValues(alpha: 0.24),
                foregroundColor: EverloreTheme.gold,
              ),
              onPressed: enabled ? onSend : null,
              icon: const Icon(Icons.send_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
