import 'package:flutter/material.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/widgets/everlore_network_image.dart';
import '../../models/group_chat_models.dart';

/// Circular avatar showing either the member's portrait or a clean initial avatar.
class MemberAvatar extends StatelessWidget {
  final GroupMember? member;
  final String? name;
  final String? portraitUrl;

  /// The small copy of the portrait; falls back to the full one if it fails.
  final String? portraitThumbUrl;
  final double size;
  final bool hasPending;
  final VoidCallback? onTap;

  const MemberAvatar({
    super.key,
    this.member,
    this.name,
    this.portraitUrl,
    this.portraitThumbUrl,
    this.size = 38,
    this.hasPending = false,
    this.onTap,
  });

  String get _displayName => member?.name ?? name ?? '?';
  String? get _url => member?.portraitUrl ?? portraitUrl;
  String? get _thumb => member?.portraitThumbUrl ?? portraitThumbUrl;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final cacheWidth = (size * dpr).ceil();
    final initial = _displayName.trim().isNotEmpty
        ? _displayName.trim()[0].toUpperCase()
        : '?';

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: EverloreTheme.void3,
        border: Border.all(
          color: EverloreTheme.goldDim.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: _url != null && _url!.isNotEmpty
          ? EverloreNetworkImage(
              imageUrl: _thumb != null && _thumb!.isNotEmpty ? _thumb! : _url!,
              fallbackUrl: _url,
              fit: BoxFit.cover,
              memCacheWidth: cacheWidth,
              // Portraits are tall: keep the face, not the chest.
              alignment: const Alignment(0, -0.6),
              errorWidget: _InitialFallback(initial: initial, size: size),
            )
          : _InitialFallback(initial: initial, size: size),
    );

    if (hasPending) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: EverloreTheme.aetherBright,
                shape: BoxShape.circle,
                border: Border.all(
                  color: EverloreTheme.void0,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: EverloreTheme.aetherBright.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: avatar,
      );
    }

    return avatar;
  }
}

class _InitialFallback extends StatelessWidget {
  final String initial;
  final double size;

  const _InitialFallback({required this.initial, required this.size});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initial,
        style: EverloreTheme.ui(
          size: size * 0.42,
          weight: FontWeight.w700,
          color: EverloreTheme.goldGlow,
        ),
      ),
    );
  }
}
