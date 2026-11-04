import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/models/world_template.dart';
import '../../../../shared/widgets/everlore_network_image.dart';
import '../../models/group_chat_models.dart';
import 'member_avatar.dart';

/// Reusable tall cover card (132x198 or masonry width): full-bleed cover,
/// bottom gradient, title, and overlapping member faces.
class GroupCoverCard extends StatelessWidget {
  final WorldTemplate template;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  const GroupCoverCard({
    super.key,
    required this.template,
    this.width,
    this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final members = template.members;
    final displayFaces = members.take(3).toList();

    Widget card = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: EverloreTheme.void2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: EverloreTheme.goldDim.withValues(alpha: 0.28),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed cover image
          if (template.imageUrl.isNotEmpty)
            EverloreNetworkImage(
              imageUrl: template.imageUrl,
              fit: BoxFit.cover,
              memCacheWidth: 720,
            )
          else
            Container(color: EverloreTheme.void3),

          // Bottom gradient
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: height != null ? height! * 0.65 : 120,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    EverloreTheme.void0.withValues(alpha: 0.7),
                    EverloreTheme.void0.withValues(alpha: 0.95),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Title and overlapping faces
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  template.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: EverloreTheme.ui(
                    size: 13,
                    weight: FontWeight.w700,
                    color: EverloreTheme.parchment,
                    height: 1.25,
                  ),
                ),
                if (displayFaces.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 22,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        for (var i = 0; i < displayFaces.length; i++)
                          Positioned(
                            left: i * 14.0,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: EverloreTheme.void0,
                                  width: 1.2,
                                ),
                              ),
                              child: MemberAvatar(
                                member: GroupMember(
                                  id: 'm_$i',
                                  name: displayFaces[i].name,
                                  role: displayFaces[i].role,
                                  portraitUrl: displayFaces[i].portraitUrl,
                                ),
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (width == null && height == null) {
      card = AspectRatio(aspectRatio: 132 / 198, child: card);
    }

    return GestureDetector(
      onTap: onTap ?? () => context.push('/group-preview/${template.id}', extra: template),
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }
}
