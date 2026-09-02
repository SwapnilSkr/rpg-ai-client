import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/nexus_theme.dart';
import '../../../shared/app_icons.dart';
import '../../../shared/models/realm_play_status.dart';
import '../../../shared/widgets/everlore_session_loader.dart';
import '../../../shared/widgets/neu.dart';
import '../../../shared/widgets/everlore_empty_state.dart';
import '../../../shared/widgets/realm_backdrop.dart';
import '../data/home_repository.dart';
import 'realm_entry_flow.dart';
import '../../../core/errors/user_message.dart';
import '../../../shared/widgets/everlore_notice.dart';
import '../../../shared/text_format.dart';

class RealmPlaythroughsScreen extends StatefulWidget {
  final String templateId;

  const RealmPlaythroughsScreen({super.key, required this.templateId});

  @override
  State<RealmPlaythroughsScreen> createState() =>
      _RealmPlaythroughsScreenState();
}

class _RealmPlaythroughsScreenState extends State<RealmPlaythroughsScreen> {
  RealmTemplateStories? _data;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_maybeLoadMore);
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 520) {
      return;
    }
    _loadMore();
  }

  Future<void> _loadMore() async {
    final data = _data;
    if (data == null || _isLoading || _isLoadingMore || !data.hasMore) {
      return;
    }
    setState(() => _isLoadingMore = true);
    try {
      final next = await HomeRepository.getStoriesByTemplate(
        widget.templateId,
        page: data.page + 1,
      );
      if (!mounted) return;
      final known = data.stories.map((s) => s.summary.id).toSet();
      final merged = [
        ...data.stories,
        ...next.stories.where((s) => known.add(s.summary.id)),
      ];
      setState(() {
        _data = data.copyWith(
          stories: merged,
          total: next.total,
          page: next.page,
        );
      });
    } catch (_) {
      // Keep current list; next scroll can retry.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await HomeRepository.getStoriesByTemplate(
        widget.templateId,
        forceRefresh: true,
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = userFacingError(
          e,
          fallback: 'Could not load these playthroughs.',
        );
      });
    }
  }

  String get _title => _data?.template?['title'] as String? ?? 'Your stories';

  Future<void> _beginNewStory() async {
    await beginNewRealmStory(
      context,
      widget.templateId,
      isSentient: _data?.template?['is_sentient'] == true,
    );
    if (mounted) unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EverloreTheme.void1,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: EverloreTheme.ash,
            size: 18,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _title,
          style: const TextStyle(
            color: EverloreTheme.parchment,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/art/forge-muse.webp',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          const EmberOverlay(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  EverloreTheme.void0.withValues(alpha: 0.22),
                  EverloreTheme.void0.withValues(alpha: 0.58),
                  EverloreTheme.void0.withValues(alpha: 0.84),
                ],
                stops: const [0, 0.42, 1],
              ),
            ),
          ),
          _buildBody(context),
        ],
      ),
      bottomNavigationBar: _isLoading || _error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: NeuButton(
                  label: 'Begin a new story',
                  icon: Icons.auto_stories,
                  onTap: _beginNewStory,
                ),
              ),
            ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: EverloreSessionLoader(message: 'Gathering your stories'),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EvIcon(AppIcons.errorRune, size: 100),
              const SizedBox(height: 16),
              const Text(
                'Could not reach your stories',
                style: TextStyle(
                  color: EverloreTheme.parchment,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: EverloreTheme.ash, fontSize: 13),
              ),
              const SizedBox(height: 24),
              NeuButton(label: 'Try Again', onTap: _load),
            ],
          ),
        ),
      );
    }

    final stories = _data?.stories ?? [];
    if (stories.isEmpty) {
      return EverloreEmptyState(
        icon: Icons.menu_book_rounded,
        eyebrow: 'UNWRITTEN CHAPTER',
        title: 'No stories in this realm yet',
        message:
            'Begin a fresh playthrough and this realm will keep every chapter here.',
        actionLabel: 'Begin a story',
        actionIcon: Icons.auto_stories_rounded,
        accent: EverloreTheme.gold,
        onAction: _beginNewStory,
      );
    }

    final totalLabel = _data?.total ?? stories.length;
    return RefreshIndicator(
      color: EverloreTheme.gold,
      backgroundColor: EverloreTheme.void2,
      onRefresh: _load,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
              20,
              0,
            ),
            sliver: SliverList.list(
              children: [
                Text(
                  'Pick up where you left off',
                  style: EverloreTheme.sectionHeader,
                ),
                const SizedBox(height: 6),
                Text(
                  '$totalLabel ${totalLabel == 1 ? 'story' : 'stories'} in progress',
                  style: const TextStyle(
                    color: EverloreTheme.ash,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverList.builder(
              itemCount: stories.length,
              itemBuilder: (context, index) {
                final story = stories[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _StoryCard(
                    story: story,
                    onTap: () async {
                      await context.push('/play/${story.summary.id}');
                      if (mounted) unawaited(_load());
                    },
                    onArchive: () => _archive(story.summary.id),
                    onDelete: () => _delete(story.summary.id),
                  ),
                );
              },
            ),
          ),
          if (_isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: EverloreTheme.gold,
                    ),
                  ),
                ),
              ),
            )
          else
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }

  Future<void> _archive(String instanceId) async {
    try {
      await HomeRepository.archiveInstance(instanceId);
      if (mounted) unawaited(_load());
    } catch (e) {
      if (!mounted) return;
      showEverloreNotice(
        context,
        userFacingError(e, fallback: 'Could not archive that playthrough.'),
        tone: NoticeTone.error,
      );
    }
  }

  Future<void> _delete(String instanceId) async {
    final countBefore = _data?.stories.length ?? 0;
    try {
      await HomeRepository.deleteInstance(instanceId);
      if (!mounted) return;
      unawaited(_load());
      if (countBefore <= 1) context.pop();
    } catch (e) {
      if (!mounted) return;
      showEverloreNotice(
        context,
        userFacingError(e, fallback: 'Could not delete that playthrough.'),
        tone: NoticeTone.error,
      );
    }
  }
}

class _StoryCard extends StatelessWidget {
  final RealmStoryDetail story;
  final VoidCallback onTap;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const _StoryCard({
    required this.story,
    required this.onTap,
    required this.onArchive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF231A12), Color(0xFF0D0A07)],
          ),
          border: Border.all(
            color: EverloreTheme.goldDim.withValues(alpha: 0.22),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 12,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Story ${story.storyIndex}',
                          style: const TextStyle(
                            color: EverloreTheme.parchment,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showOptions(context),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: EverloreTheme.white10,
                          ),
                          child: const Icon(
                            Icons.more_horiz,
                            color: EverloreTheme.ash,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (story.preview.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      story.preview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: EverloreTheme.aiText.copyWith(
                        color: EverloreTheme.ash.withValues(alpha: 0.95),
                        fontSize: 14,
                        height: 1.45,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      EvIcon(AppIcons.event, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        countLabel(story.summary.totalEvents, 'turn'),
                        style: const TextStyle(
                          color: EverloreTheme.ash,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatAgo(story.summary.lastActiveAt),
                        style: TextStyle(
                          color: EverloreTheme.ash.withValues(alpha: 0.65),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.chevron_right,
                        color: EverloreTheme.goldDim,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      backgroundColor: EverloreTheme.void2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const EvIcon(AppIcons.seal, size: 22),
                title: const Text(
                  'Seal this story',
                  style: TextStyle(color: EverloreTheme.parchment),
                ),
                subtitle: const Text(
                  'Hide it from your active realms',
                  style: TextStyle(color: EverloreTheme.ash, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onArchive();
                },
              ),
              ListTile(
                leading: const EvIcon(AppIcons.destroy, size: 22),
                title: const Text(
                  'Destroy this story',
                  style: TextStyle(color: EverloreTheme.crimson),
                ),
                subtitle: const Text(
                  'Erase it and all its echoes forever',
                  style: TextStyle(color: EverloreTheme.ash, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EverloreTheme.void2,
        title: const Text(
          'Destroy this story?',
          style: TextStyle(color: EverloreTheme.parchment, fontSize: 18),
        ),
        content: const Text(
          'This will permanently erase this story and everything that happened in it.',
          style: TextStyle(color: EverloreTheme.ash, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Keep it',
              style: TextStyle(color: EverloreTheme.ash),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: const Text(
              'Destroy forever',
              style: TextStyle(color: EverloreTheme.crimson),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 7) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}
