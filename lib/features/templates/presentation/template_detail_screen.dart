import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/world_template.dart';
import '../../../shared/widgets/stat_bar.dart';
import '../data/template_repository.dart';
import '../../home/data/home_repository.dart';

class TemplateDetailScreen extends StatefulWidget {
  final String templateId;

  const TemplateDetailScreen({super.key, required this.templateId});

  @override
  State<TemplateDetailScreen> createState() => _TemplateDetailScreenState();
}

class _TemplateDetailScreenState extends State<TemplateDetailScreen> {
  WorldTemplate? _template;
  bool _isLoading = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await TemplateRepository.getById(widget.templateId);
      setState(() {
        _template = t;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createInstance() async {
    if (_isCreating) return;
    setState(() => _isCreating = true);
    try {
      final instance = await HomeRepository.createInstance(widget.templateId);
      if (mounted) {
        context.go('/play/${instance.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create world: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d0d1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0d0d1a),
        title: Text(
          _template?.title ?? 'Loading...',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.purpleAccent))
          : _template == null
              ? const Center(
                  child: Text('Template not found',
                      style: TextStyle(color: Colors.white54)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Icon(
                            _template!.isSentient
                                ? Icons.psychology
                                : Icons.auto_stories,
                            color: _template!.isSentient
                                ? Colors.purpleAccent
                                : Colors.blueAccent,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _template!.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _template!.isSentient
                                      ? 'Sentient World'
                                      : 'Game Master World',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      Text(
                        _template!.description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),

                      // Stats preview
                      if (_template!.baseStatsTemplate.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'World Stats',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._template!.baseStatsTemplate.entries.map((e) {
                          return Column(
                            children: [
                              StatBar(
                                label: e.key.replaceAll('_', ' '),
                                value: e.value.defaultValue,
                                max: e.value.max,
                              ),
                              Text(
                                e.value.description,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          );
                        }),
                      ],

                      // Scene tags
                      if (_template!.sceneTags.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Scene Types',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _template!.sceneTags.map((tag) {
                            return Chip(
                              label: Text(tag),
                              backgroundColor: Colors.white10,
                              labelStyle:
                                  const TextStyle(color: Colors.white54),
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
      bottomNavigationBar: _template != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _createInstance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Enter This World',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            )
          : null,
    );
  }
}
