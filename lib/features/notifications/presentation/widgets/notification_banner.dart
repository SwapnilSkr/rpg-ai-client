import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/widgets/everlore_network_image.dart';
import '../../models/app_notification.dart';
import '../../state/notifications_cubit.dart';
import '../../state/notifications_state.dart';

/// App-wide host mounted once above the navigator to present in-app banners
/// when notifications arrive live while the app is in the foreground.
class NotificationBannerHost extends StatefulWidget {
  final Widget child;

  const NotificationBannerHost({super.key, required this.child});

  @override
  State<NotificationBannerHost> createState() => _NotificationBannerHostState();
}

class _NotificationBannerHostState extends State<NotificationBannerHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 200),
  );

  Timer? _timer;
  NotificationBanner? _active;
  bool _isLeaving = false;

  @override
  void initState() {
    super.initState();
    final initial = context.read<NotificationsCubit>().state.banner;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onBannerChanged(initial);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  void _onBannerChanged(NotificationBanner? next) {
    if (next == null) {
      if (_active != null && !_isLeaving) {
        _leave();
      }
      return;
    }

    // A new banner arrived or replaced the existing one.
    _timer?.cancel();
    _isLeaving = false;
    setState(() {
      _active = next;
    });
    _anim.forward(from: 0.0);
    _timer = Timer(const Duration(seconds: 4), _leave);
  }

  Future<void> _leave() async {
    if (_isLeaving || _active == null) return;
    _isLeaving = true;
    _timer?.cancel();
    final seqToDismiss = _active?.seq;
    if (mounted) {
      await _anim.reverse();
    }
    if (mounted && _isLeaving) {
      context.read<NotificationsCubit>().dismissBanner(seqToDismiss);
      setState(() {
        _active = null;
        _isLeaving = false;
      });
    }
  }

  void _onTap(AppNotification item) {
    _timer?.cancel();
    _isLeaving = true;
    final seqToDismiss = _active?.seq;
    context.read<NotificationsCubit>().open(item);
    _anim.reverse().then((_) {
      if (mounted) {
        context.read<NotificationsCubit>().dismissBanner(seqToDismiss);
        setState(() {
          _active = null;
          _isLeaving = false;
        });
      }
    });
  }

  void _onDismissed(int seq) {
    _timer?.cancel();
    _isLeaving = false;
    context.read<NotificationsCubit>().dismissBanner(seq);
    setState(() {
      _active = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final curve = CurvedAnimation(
      parent: _anim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return BlocListener<NotificationsCubit, NotificationsState>(
      listenWhen: (prev, curr) => curr.banner != prev.banner,
      listener: (context, state) => _onBannerChanged(state.banner),
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (_active != null)
            Positioned(
              top: topPadding + 8,
              left: 16,
              right: 16,
              child: FadeTransition(
                opacity: curve,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.6),
                    end: Offset.zero,
                  ).animate(curve),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Dismissible(
                        key: ValueKey('banner_${_active!.seq}'),
                        direction: DismissDirection.up,
                        onDismissed: (_) => _onDismissed(_active!.seq),
                        child: GestureDetector(
                          onTap: () => _onTap(_active!.item),
                          behavior: HitTestBehavior.opaque,
                          child: _BannerCard(item: _active!.item),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final AppNotification item;

  const _BannerCard({required this.item});

  @override
  Widget build(BuildContext context) {
    // Mounted above the Navigator, so no Material is above it: without one,
    // text falls back to the debug style (yellow double underline).
    return Material(
      type: MaterialType.transparency,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
            decoration: BoxDecoration(
              color: EverloreTheme.void1.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: EverloreTheme.goldDim.withValues(alpha: 0.22),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.40),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EverloreTheme.ui(
                          size: 14,
                          weight: FontWeight.w600,
                          color: EverloreTheme.parchment,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EverloreTheme.aiText.copyWith(
                          fontSize: 14,
                          height: 1.3,
                          color: EverloreTheme.ash,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final isFilm = item.kind == NotificationKind.filmReady;
    final fallback = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: isFilm ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: isFilm ? BorderRadius.circular(10) : null,
        color: EverloreTheme.void3,
      ),
      alignment: Alignment.center,
      child: Text(
        item.title.trim().isNotEmpty ? item.title.trim()[0].toUpperCase() : '?',
        style: EverloreTheme.ui(
          size: 16,
          weight: FontWeight.w700,
          color: EverloreTheme.gold,
        ),
      ),
    );

    if (item.imageUrl == null || item.imageUrl!.isEmpty) {
      return fallback;
    }

    final image = EverloreNetworkImage(
      imageUrl: item.imageUrl!,
      fit: BoxFit.cover,
      placeholder: fallback,
      errorWidget: fallback,
    );

    if (isFilm) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(width: 44, height: 44, child: image),
      );
    }

    return ClipOval(child: SizedBox(width: 44, height: 44, child: image));
  }
}
