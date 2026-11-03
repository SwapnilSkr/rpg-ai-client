import 'package:flutter/material.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../models/group_chat_models.dart';
import 'member_avatar.dart';

/// Sheet shown when a character's avatar or name is tapped: Message and Bond.
class CharacterSheet extends StatelessWidget {
  final GroupMember member;
  final VoidCallback onMessage;
  final VoidCallback onBond;

  const CharacterSheet({
    super.key,
    required this.member,
    required this.onMessage,
    required this.onBond,
  });

  static Future<void> show(
    BuildContext context, {
    required GroupMember member,
    required VoidCallback onMessage,
    required VoidCallback onBond,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CharacterSheet(
        member: member,
        onMessage: () {
          Navigator.of(context).pop();
          onMessage();
        },
        onBond: () {
          Navigator.of(context).pop();
          onBond();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: EverloreTheme.void1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(
          top: BorderSide(color: EverloreTheme.goldDim, width: 1.2),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: EverloreTheme.ash.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              MemberAvatar(member: member, size: 64),
              const SizedBox(height: 12),
              Text(
                member.name,
                style: EverloreTheme.cardTitle.copyWith(
                  fontSize: 20,
                  color: EverloreTheme.parchment,
                ),
                textAlign: TextAlign.center,
              ),
              if (member.role.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  member.role,
                  style: EverloreTheme.bodyDim.copyWith(
                    color: EverloreTheme.ash,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: EverloreTheme.gold,
                        side: const BorderSide(color: EverloreTheme.goldDim),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.favorite_outline_rounded, size: 18),
                      label: Text(
                        'Bond',
                        style: EverloreTheme.ui(
                          size: 14,
                          weight: FontWeight.w600,
                          color: EverloreTheme.gold,
                        ),
                      ),
                      onPressed: onBond,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EverloreTheme.goldDeep,
                        foregroundColor: EverloreTheme.parchment,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                      label: Text(
                        'Message',
                        style: EverloreTheme.ui(
                          size: 14,
                          weight: FontWeight.w700,
                          color: EverloreTheme.parchment,
                        ),
                      ),
                      onPressed: onMessage,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
