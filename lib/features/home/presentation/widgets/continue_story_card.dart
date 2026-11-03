import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../shared/models/world_instance.dart';
import '../../../../shared/widgets/everlore_network_image.dart';
import '../../data/home_repository.dart';

/// "Continue your story" card shown at the top of Explore for a returning
/// player with an active save.
///
/// Loads independently of the Explore feed, leaves no empty space if signed out,
/// without saves, or if loading fails, and refreshes when Explore regains focus.
class ContinueStoryCard extends StatefulWidget {
  final EdgeInsetsGeometry padding;
  final VoidCallback? onContinued;

  const ContinueStoryCard({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 6, 16, 0),
    this.onContinued,
  });

  @override
  State<ContinueStoryCard> createState() => ContinueStoryCardState();
}

class ContinueStoryCardState extends State<ContinueStoryCard>
    with WidgetsBindingObserver {
  WorldInstance? _latestInstance;
  int _loadToken = 0;
  StreamSubscription<RealmChange>? _realmChangesSub;
  ModalRoute<dynamic>? _subscribedRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthService.sessionEpoch.addListener(_onSessionChanged);
    _realmChangesSub = HomeRepository.realmChanges.listen(_onRealmChange);
    _loadSaves();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _subscribedRoute) {
      _subscribedRoute?.secondaryAnimation?.removeStatusListener(
        _onSecondaryAnimationStatus,
      );
      _subscribedRoute = route;
      _subscribedRoute?.secondaryAnimation?.addStatusListener(
        _onSecondaryAnimationStatus,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AuthService.sessionEpoch.removeListener(_onSessionChanged);
    _realmChangesSub?.cancel();
    _subscribedRoute?.secondaryAnimation?.removeStatusListener(
      _onSecondaryAnimationStatus,
    );
    super.dispose();
  }

  void _onSessionChanged() {
    refresh(forceRefresh: true);
  }

  void _onRealmChange(RealmChange _) {
    refresh(forceRefresh: true);
  }

  void _onSecondaryAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      refresh(forceRefresh: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refresh(forceRefresh: true);
    }
  }

  Future<void> refresh({bool forceRefresh = false}) =>
      _loadSaves(forceRefresh: forceRefresh);

  Future<void> _loadSaves({bool forceRefresh = false}) async {
    final token = ++_loadToken;
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        if (mounted && token == _loadToken) {
          setState(() => _latestInstance = null);
        }
        return;
      }

      final instances = await HomeRepository.getInstances(
        includeArchived: false,
        forceRefresh: forceRefresh,
      );

      if (!mounted || token != _loadToken) return;

      final active = instances
          .where((i) => !i.meta.isArchived && i.template?['kind'] != 'group')
          .toList();
      setState(() {
        _latestInstance = active.isNotEmpty ? active.first : null;
      });
    } catch (_) {
      if (mounted && token == _loadToken) {
        setState(() => _latestInstance = null);
      }
    }
  }

  Future<void> _openStory(BuildContext context, WorldInstance instance) async {
    widget.onContinued?.call();
    if (instance.template?['kind'] == 'group') {
      await context.push('/group/${instance.id}');
    } else {
      await context.push('/play/${instance.id}');
    }
    if (mounted) {
      refresh(forceRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final instance = _latestInstance;
    if (instance == null) {
      return const SizedBox.shrink();
    }

    final template = instance.template;
    final rawTitle = template?['title'] as String?;
    final title = (rawTitle != null && rawTitle.trim().isNotEmpty)
        ? rawTitle.trim()
        : 'Untitled Story';
    final imageUrl = template?['image_url'] as String? ?? '';
    final isSentient = template?['is_sentient'] as bool? ?? false;
    final accent = isSentient ? EverloreTheme.aetherBright : EverloreTheme.gold;

    return Padding(
      padding: widget.padding,
      child: Container(
        clipBehavior: Clip.antiAlias,
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(
          color: EverloreTheme.void2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.40),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: accent.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(-2, -2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              if (imageUrl.isNotEmpty) ...[
                Positioned.fill(
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.black.withValues(alpha: 0.70),
                      BlendMode.darken,
                    ),
                    child: EverloreNetworkImage(
                      imageUrl: imageUrl,
                      memCacheWidth: 720,
                      fit: BoxFit.cover,
                      errorWidget: const SizedBox.shrink(),
                      semanticLabel: title,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          EverloreTheme.void1.withValues(alpha: 0.92),
                          EverloreTheme.void2.withValues(alpha: 0.78),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          EverloreTheme.void3,
                          EverloreTheme.void2,
                        ],
                      ),
                    ),
                  ),
                ),
              InkWell(
                onTap: () => _openStory(context, instance),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: imageUrl.isNotEmpty
                              ? EverloreNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 160,
                                  errorWidget: _fallbackCover(
                                    accent,
                                    isSentient,
                                  ),
                                  semanticLabel: title,
                                )
                              : _fallbackCover(accent, isSentient),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: EverloreTheme.ui(
                                size: 14.5,
                                color: EverloreTheme.parchment,
                                weight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Continue your story',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: EverloreTheme.aiText.copyWith(
                                fontSize: 12.5,
                                color: EverloreTheme.ash,
                                height: 1.25,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: accent.withValues(alpha: 0.14),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Continue',
                              style: EverloreTheme.ui(
                                size: 12,
                                color: accent,
                                weight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: accent,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackCover(Color accent, bool isSentient) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.22),
            EverloreTheme.void3,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          isSentient ? Icons.psychology_alt_rounded : Icons.auto_stories_rounded,
          color: accent,
          size: 20,
        ),
      ),
    );
  }
}
