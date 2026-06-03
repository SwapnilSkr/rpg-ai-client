import 'package:flutter/widgets.dart';

import 'narrative_styles.dart';

class AppIcons {
  static const navExplore = 'assets/icons/nav_explore.png';
  static const navRealms = 'assets/icons/nav_realms.png';
  static const navCreate = 'assets/icons/nav_create.png';
  static const navWorlds = 'assets/icons/nav_worlds.png';
  static const navProfile = 'assets/icons/nav_profile.png';

  static const forgeSigil = 'assets/icons/forge_sigil.png';
  static const appIcon = 'assets/icons/app_icon.png';

  static const echo = 'assets/icons/echo.png';
  static const event = 'assets/icons/event.png';
  static const chronicle = 'assets/icons/chronicle.png';
  static const realmActive = 'assets/icons/realm_active.png';
  static const reconnecting = 'assets/icons/reconnecting.png';

  static const sceneDialogue = 'assets/icons/scene_dialogue.png';
  static const sceneCombat = 'assets/icons/scene_combat.png';
  static const sceneRomantic = 'assets/icons/scene_romantic.png';
  static const sceneIntimate = 'assets/icons/scene_intimate.png';
  static const sceneExploration = 'assets/icons/scene_exploration.png';
  static const sceneExistential = 'assets/icons/scene_existential.png';
  static const sceneCosmic = 'assets/icons/scene_cosmic.png';
  static const sceneMundane = 'assets/icons/scene_mundane.png';

  static const familyModernEveryday = 'assets/icons/family_modern_everyday.png';
  static const familyEpicAdventure = 'assets/icons/family_epic_adventure.png';
  static const familyAtmosphericDark =
      'assets/icons/family_atmospheric_dark.png';
  static const familyRomanceCharged = 'assets/icons/family_romance_charged.png';
  static const familyCozyPlayful = 'assets/icons/family_cozy_playful.png';

  static const seal = 'assets/icons/seal.png';
  static const destroy = 'assets/icons/destroy.png';
  static const publish = 'assets/icons/publish.png';
  static const voice = 'assets/icons/voice.png';
  static const length = 'assets/icons/length.png';
  static const pov = 'assets/icons/pov.png';
  static const nsfw = 'assets/icons/nsfw.png';
  static const continueStory = 'assets/icons/continue.png';

  static const emptyRealms = 'assets/icons/empty_realms.png';
  static const emptyForge = 'assets/icons/empty_forge.png';
  static const lockedGate = 'assets/icons/locked_gate.png';
  static const errorRune = 'assets/icons/error_rune.png';

  static String scene(String tag) {
    return switch (_slug(tag)) {
      'dialogue' => sceneDialogue,
      'combat' => sceneCombat,
      'romantic' => sceneRomantic,
      'intimate' => sceneIntimate,
      'exploration' => sceneExploration,
      'existential' => sceneExistential,
      'cosmic' => sceneCosmic,
      'mundane' => sceneMundane,
      _ => sceneExploration,
    };
  }

  static String family(String key) {
    return switch (_slug(key)) {
      'modern_everyday' => familyModernEveryday,
      'epic_adventure' => familyEpicAdventure,
      'atmospheric_dark' => familyAtmosphericDark,
      'romance_charged' => familyRomanceCharged,
      'cozy_playful' => familyCozyPlayful,
      _ => familyEpicAdventure,
    };
  }

  static String familyForStyle(String styleKey) {
    return family(familyOfStyle(styleKey) ?? '');
  }

  static String _slug(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }
}

class EvIcon extends StatelessWidget {
  final String name;
  final double size;
  final BoxFit fit;

  const EvIcon(
    this.name, {
    super.key,
    this.size = 24,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      name,
      width: size,
      height: size,
      fit: fit,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
    );
  }
}
