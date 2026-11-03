import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/layout/responsive.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../../models/group_chat_models.dart';
import '../../state/group_chat_cubit.dart';
import '../../state/group_chat_state.dart';
import 'member_avatar.dart';

/// Shows character bond meters, recent moments, and an interactive "Set it yourself" slider control.
class BondSheet extends StatefulWidget {
  final GroupChatCubit cubit;
  final GroupMember member;

  const BondSheet({super.key, required this.cubit, required this.member});

  static Future<void> show(
    BuildContext context, {
    required GroupChatCubit cubit,
    required GroupMember member,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BondSheet(cubit: cubit, member: member),
    );
  }

  @override
  State<BondSheet> createState() => _BondSheetState();
}

class _BondSheetState extends State<BondSheet> {
  bool _customMode = false;
  int? _trust;
  int? _affection;
  int? _fear;
  int? _rivalry;

  @override
  void initState() {
    super.initState();
    widget.cubit.loadBonds();
  }

  GroupBond _currentBond(GroupChatState state) {
    for (final b in state.bonds) {
      if (b.characterId == widget.member.id) return b;
    }
    return GroupBond(
      characterId: widget.member.id,
      name: widget.member.name,
      meters: const BondMeters(),
      moments: const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GroupChatCubit, GroupChatState>(
      bloc: widget.cubit,
      builder: (context, state) {
        final bond = _currentBond(state);
        final trustVal = _trust ?? bond.meters.trust;
        final affectionVal = _affection ?? bond.meters.affection;
        final fearVal = _fear ?? bond.meters.fear;
        final rivalryVal = _rivalry ?? bond.meters.rivalry;

        final maxHeight = context.layout.sheetBodyMaxHeight(chrome: 90);

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: EverloreTheme.ash.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Row(
                    children: [
                      MemberAvatar(member: widget.member, size: 44),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.member.name,
                              style: EverloreTheme.cardTitle.copyWith(
                                color: EverloreTheme.parchment,
                              ),
                            ),
                            if (widget.member.role.isNotEmpty)
                              Text(
                                widget.member.role,
                                style: EverloreTheme.caption.copyWith(
                                  color: EverloreTheme.ash,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: EverloreTheme.ash,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(color: EverloreTheme.white10, height: 1),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('BOND', style: EverloreTheme.sectionHeader),
                        const SizedBox(height: 14),
                        _buildMeterRow('Trust', trustVal, EverloreTheme.aether),
                        const SizedBox(height: 10),
                        _buildMeterRow(
                          'Affection',
                          affectionVal,
                          EverloreTheme.rose,
                        ),
                        const SizedBox(height: 10),
                        _buildMeterRow('Fear', fearVal, EverloreTheme.ash),
                        const SizedBox(height: 10),
                        _buildMeterRow(
                          'Rivalry',
                          rivalryVal,
                          EverloreTheme.ember,
                        ),
                        const SizedBox(height: 20),
                        // "Set it yourself" switch
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Set it yourself',
                              style: EverloreTheme.body.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Switch(
                              value: _customMode,
                              activeThumbColor: EverloreTheme.gold,
                              activeTrackColor: EverloreTheme.goldDeep,
                              inactiveTrackColor: EverloreTheme.void3,
                              onChanged: (val) {
                                setState(() {
                                  _customMode = val;
                                  if (!val) {
                                    _trust = null;
                                    _affection = null;
                                    _fear = null;
                                    _rivalry = null;
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                        if (_customMode) ...[
                          const SizedBox(height: 12),
                          _buildSlider(
                            'Trust',
                            trustVal,
                            EverloreTheme.aether,
                            (v) => setState(() => _trust = v.round()),
                            (v) => widget.cubit.setBond(
                              widget.member.id,
                              {
                                'trust': v.round(),
                                'affection': affectionVal,
                                'fear': fearVal,
                                'rivalry': rivalryVal,
                              },
                            ),
                          ),
                          _buildSlider(
                            'Affection',
                            affectionVal,
                            EverloreTheme.rose,
                            (v) => setState(() => _affection = v.round()),
                            (v) => widget.cubit.setBond(
                              widget.member.id,
                              {
                                'trust': trustVal,
                                'affection': v.round(),
                                'fear': fearVal,
                                'rivalry': rivalryVal,
                              },
                            ),
                          ),
                          _buildSlider(
                            'Fear',
                            fearVal,
                            EverloreTheme.ash,
                            (v) => setState(() => _fear = v.round()),
                            (v) => widget.cubit.setBond(
                              widget.member.id,
                              {
                                'trust': trustVal,
                                'affection': affectionVal,
                                'fear': v.round(),
                                'rivalry': rivalryVal,
                              },
                            ),
                          ),
                          _buildSlider(
                            'Rivalry',
                            rivalryVal,
                            EverloreTheme.ember,
                            (v) => setState(() => _rivalry = v.round()),
                            (v) => widget.cubit.setBond(
                              widget.member.id,
                              {
                                'trust': trustVal,
                                'affection': affectionVal,
                                'fear': fearVal,
                                'rivalry': v.round(),
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (bond.moments.isNotEmpty) ...[
                          Text('RECENT MOMENTS', style: EverloreTheme.sectionHeader),
                          const SizedBox(height: 12),
                          ...bond.moments.map(_buildMomentCard),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMeterRow(String label, int value, Color accent) {
    final clamped = (value.clamp(0, 100) / 100.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: EverloreTheme.bodyDim.copyWith(fontSize: 13)),
            Text(
              '$value%',
              style: EverloreTheme.caption.copyWith(
                color: EverloreTheme.parchment,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: clamped,
            minHeight: 7,
            backgroundColor: EverloreTheme.void3,
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
        ),
      ],
    );
  }

  Widget _buildSlider(
    String label,
    int value,
    Color accent,
    ValueChanged<double> onChanged,
    ValueChanged<double> onChangeEnd,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: EverloreTheme.caption.copyWith(
                color: EverloreTheme.parchment,
              ),
            ),
            Text(
              '$value',
              style: EverloreTheme.caption.copyWith(color: accent),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: accent,
            inactiveTrackColor: EverloreTheme.void3,
            thumbColor: EverloreTheme.goldGlow,
            overlayColor: accent.withValues(alpha: 0.15),
            trackHeight: 3.5,
          ),
          child: Slider(
            value: value.toDouble().clamp(0, 100),
            min: 0,
            max: 100,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    );
  }

  Widget _buildMomentCard(BondMoment moment) {
    final deltas = moment.deltas.entries
        .map((e) => '${e.key} ${e.value >= 0 ? '+${e.value}' : '${e.value}'}')
        .join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EverloreTheme.void2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: EverloreTheme.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (moment.evidence.isNotEmpty)
            Text(
              moment.evidence,
              style: EverloreTheme.aiText.copyWith(
                fontSize: 14,
                height: 1.4,
                color: EverloreTheme.parchment,
              ),
            ),
          if (deltas.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              deltas,
              style: EverloreTheme.caption.copyWith(
                color: EverloreTheme.goldDim,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
