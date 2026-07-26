import 'package:flutter/material.dart';
import '../../../../../app/theme/nexus_theme.dart';
import '../../../../shared/models/character_profile.dart';

/// Compact relationship ledger readout — the four meters that make a bond
/// inspectable and playable. Fills ease to their values; colors are stable
/// per meter so players learn the language (green trust, warm affection…).
class BondMeters extends StatelessWidget {
  final RelationshipMeters meters;
  final List<RelationshipMoment> moments;
  final bool dense;

  const BondMeters({
    super.key,
    required this.meters,
    this.moments = const [],
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final observed = moments.map((moment) => moment.meter).toSet();
    final rows = <(String, int, Color)>[
      if (observed.contains('trust') || meters.trust != 50)
        ('Trust', meters.trust, EverloreTheme.verdant),
      if (observed.contains('affection') || meters.affection != 50)
        ('Affection', meters.affection, EverloreTheme.ember),
      if (observed.contains('fear') || meters.fear > 0)
        ('Fear', meters.fear, EverloreTheme.violetBright),
      if (observed.contains('rivalry') || meters.rivalry > 0)
        ('Rivalry', meters.rivalry, EverloreTheme.crimson),
    ];
    final latest = moments.isEmpty ? null : moments.last;
    final latestValue = latest == null
        ? null
        : switch (latest.meter) {
            'trust' => meters.trust,
            'affection' => meters.affection,
            'fear' => meters.fear,
            'rivalry' => meters.rivalry,
            _ => null,
          };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (label, value, color) in rows)
          Padding(
            padding: EdgeInsets.only(top: dense ? 4 : 6),
            child: Row(
              children: [
                SizedBox(
                  width: dense ? 58 : 70,
                  child: Text(
                    label,
                    style: EverloreTheme.ui(
                      size: dense ? 10 : 11,
                      color: EverloreTheme.ash,
                      spacing: 0.3,
                    ),
                  ),
                ),
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: (value / 100).clamp(0.0, 1.0)),
                    duration: const Duration(milliseconds: 650),
                    curve: Curves.easeOutCubic,
                    builder: (context, pct, _) => Stack(
                      children: [
                        Container(
                          height: dense ? 4 : 5,
                          decoration: BoxDecoration(
                            color: EverloreTheme.void4,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: pct,
                          child: Container(
                            height: dense ? 4 : 5,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              gradient: LinearGradient(
                                colors: [color.withValues(alpha: 0.65), color],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.35),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 24,
                  child: Text(
                    '$value',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: color,
                      fontSize: dense ? 10 : 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (latest != null && latest.evidence.isNotEmpty && !dense) ...[
          const SizedBox(height: 8),
          Text(
            '${latest.meter[0].toUpperCase()}${latest.meter.substring(1)} is '
            '${_stage(latest.meter, latestValue!)} · '
            '${latest.delta > 0 ? '+' : ''}${latest.delta} · “${latest.evidence}”',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: EverloreTheme.ui(
              size: 10.5,
              color: EverloreTheme.ash,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }

  String _stage(String meter, int value) {
    if (meter == 'fear') {
      if (value < 20) return 'unafraid';
      if (value < 40) return 'uneasy';
      if (value < 60) return 'wary';
      if (value < 80) return 'afraid';
      return 'terrified';
    }
    if (meter == 'rivalry') {
      if (value < 20) return 'uncompetitive';
      if (value < 40) return 'watchful';
      if (value < 60) return 'competitive';
      if (value < 80) return 'hostile';
      return 'consumed by rivalry';
    }
    if (value < 20) return meter == 'trust' ? 'hostile' : 'closed off';
    if (value < 40) return meter == 'trust' ? 'guarded' : 'reserved';
    if (value < 60) return 'tentative';
    if (value < 80) return meter == 'trust' ? 'trusting' : 'warm';
    return meter == 'trust' ? 'deeply loyal' : 'deeply attached';
  }
}
