import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/world_template.dart';
import '../data/template_repository.dart';

class BrowseTemplatesScreen extends StatefulWidget {
  const BrowseTemplatesScreen({super.key});

  @override
  State<BrowseTemplatesScreen> createState() => _BrowseTemplatesScreenState();
}

class _BrowseTemplatesScreenState extends State<BrowseTemplatesScreen> {
  List<WorldTemplate> _templates = [];
  bool _isLoading = true;
  String? _error;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates({String? search}) async {
    setState(() => _isLoading = true);
    try {
      final result = await TemplateRepository.listPublished(search: search);
      setState(() {
        _templates = result['templates'];
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d0d1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0d0d1a),
        title: const Text('Browse Worlds', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search worlds...',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: const Color(0xFF1a1a2e),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white38),
                  onPressed: () {
                    _searchController.clear();
                    _loadTemplates();
                  },
                ),
              ),
              onSubmitted: (val) => _loadTemplates(search: val),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.purpleAccent))
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.redAccent)))
                    : _templates.isEmpty
                        ? const Center(
                            child: Text('No worlds found',
                                style: TextStyle(color: Colors.white38)))
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: _templates.length,
                            itemBuilder: (context, index) {
                              final t = _templates[index];
                              return _TemplateCard(
                                template: t,
                                onTap: () =>
                                    context.push('/templates/${t.id}'),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final WorldTemplate template;
  final VoidCallback onTap;

  const _TemplateCard({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1a1a2e),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                    template.isSentient ? Icons.psychology : Icons.auto_stories,
                    color: template.isSentient
                        ? Colors.purpleAccent
                        : Colors.blueAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      template.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (template.isNsfwCapable)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'NSFW',
                        style: TextStyle(color: Colors.redAccent, fontSize: 9),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                template.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: template.sceneTags.take(4).map((tag) {
                  return Chip(
                    label: Text(tag, style: const TextStyle(fontSize: 10)),
                    backgroundColor: Colors.white10,
                    labelStyle: const TextStyle(color: Colors.white54),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
