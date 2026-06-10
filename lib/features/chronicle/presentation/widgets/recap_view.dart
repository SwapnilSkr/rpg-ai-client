import 'package:flutter/material.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../../data/recap_data.dart';

/// "Story so far" — a memory-aware recap for re-entering a world. The scene
/// summary forms the prose spine; live open threads, bonds, and the current
/// place/time are layered on so the player can pick the thread back up.
class RecapView extends StatelessWidget {
  final RecapData data;

  const RecapView({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text(
            'Your story is just beginning. Once a few scenes have passed, '
            'a recap will wait for you here whenever you return.',
            textAlign: TextAlign.center,
            style: TextStyle(color: EverloreTheme.ash, fontSize: 13, height: 1.5),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        if ((data.where != null && data.where!.trim().isNotEmpty) ||
            (data.when != null && data.when!.trim().isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (data.where != null && data.where!.trim().isNotEmpty)
                  _Pill(icon: Icons.place, label: data.where!),
                if (data.when != null && data.when!.trim().isNotEmpty)
                  _Pill(icon: Icons.wb_twilight, label: data.when!),
              ],
            ),
          ),
        if (data.spine != null && data.spine!.trim().isNotEmpty)
          _SpineCard(text: data.spine!),
        if (data.openThreads.isNotEmpty) ...[
          const SizedBox(height: 20),
          _Label(icon: Icons.flag_outlined, text: 'STILL HANGING'),
          const SizedBox(height: 10),
          for (final t in data.openThreads)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: EverloreTheme.gold.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t.text,
                      style: const TextStyle(
                          color: EverloreTheme.ash, fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (data.bonds.isNotEmpty) ...[
          const SizedBox(height: 20),
          _Label(icon: Icons.favorite_border, text: 'WHERE YOU STAND'),
          const SizedBox(height: 10),
          for (final b in data.bonds) _BondLine(bond: b),
        ],
      ],
    );
  }
}

class _SpineCard extends StatelessWidget {
  final String text;
  const _SpineCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            EverloreTheme.gold.withValues(alpha: 0.1),
            EverloreTheme.void2,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: EverloreTheme.goldDim.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_stories, color: EverloreTheme.gold, size: 15),
              const SizedBox(width: 6),
              Text(
                'THE STORY SO FAR',
                style: TextStyle(
                  color: EverloreTheme.gold.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: const TextStyle(
              color: EverloreTheme.parchment,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _BondLine extends StatelessWidget {
  final RecapBond bond;
  const _BondLine({required this.bond});

  @override
  Widget build(BuildContext context) {
    final m = bond.meters;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.person_outline, color: EverloreTheme.ash, size: 15),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      bond.name,
                      style: const TextStyle(
                        color: EverloreTheme.parchment,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (m != null) ...[
                      const SizedBox(width: 8),
                      _Spark(label: 'trust', value: m.trust, color: EverloreTheme.aether),
                      _Spark(label: 'warmth', value: m.affection, color: EverloreTheme.rose),
                    ],
                  ],
                ),
                if (bond.disposition != null &&
                    bond.disposition!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    bond.disposition!,
                    style: const TextStyle(
                      color: EverloreTheme.ash,
                      fontSize: 12,
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Spark extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Spark({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color.withValues(alpha: 0.85),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Label({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: EverloreTheme.ash.withValues(alpha: 0.8), size: 13),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: EverloreTheme.ash.withValues(alpha: 0.8),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Pill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: EverloreTheme.void2,
        border: Border.all(color: EverloreTheme.goldDim.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: EverloreTheme.gold),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: EverloreTheme.parchment,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
