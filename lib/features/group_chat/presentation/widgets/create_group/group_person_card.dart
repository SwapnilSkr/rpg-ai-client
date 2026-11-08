import 'package:flutter/material.dart';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/features/group_chat/models/group_draft.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_closeness_picker.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_face_frame.dart';
import 'package:everlore/features/group_chat/state/create_group_state.dart';
import 'package:everlore/shared/widgets/everlore_network_image.dart';

/// Person card for group creation form and editor views.
/// Radius 16, border goldDim at 0.28, clip antiAlias.
/// Supports all form states (empty, filled, with-errors, add-slot)
/// and all editor face states (idle no face, painting, ready, resting/unseen, faceWillReset, with-errors).
class GroupPersonCard extends StatelessWidget {
  final String name;
  final int? age;
  final GroupCloseness? bond;
  final String? look;
  final String? portraitUrl;
  final String? portraitThumbUrl;
  final GroupFaceStatus faceStatus;
  final String? faceMessage;
  final bool faceWillReset;
  final bool hasError;
  final String? errorMessage;
  final bool isAddSlot;
  final bool isFormMode;
  final bool isEmpty;
  final VoidCallback? onTap;
  final VoidCallback? onPaintFace;

  const GroupPersonCard({
    super.key,
    this.name = '',
    this.age,
    this.bond,
    this.look,
    this.portraitUrl,
    this.portraitThumbUrl,
    this.faceStatus = GroupFaceStatus.idle,
    this.faceMessage,
    this.faceWillReset = false,
    this.hasError = false,
    this.errorMessage,
    this.isAddSlot = false,
    this.isFormMode = false,
    this.isEmpty = false,
    this.onTap,
    this.onPaintFace,
  });

  /// Factory for the "Add a person" card slot in the form.
  factory GroupPersonCard.addSlot({Key? key, required VoidCallback onTap}) =>
      GroupPersonCard(key: key, isAddSlot: true, onTap: onTap);

  /// Factory for a person card in the form view.
  factory GroupPersonCard.form({
    Key? key,
    required GroupFormPerson person,
    required int index,
    required VoidCallback onTap,
    Map<String, String>? formErrors,
  }) {
    final hasName = person.name.trim().isNotEmpty;
    final hasLook = person.look.trim().isNotEmpty;

    final nameError = formErrors?['people.$index.name'];
    final ageError = formErrors?['people.$index.age'];
    final lookError = formErrors?['people.$index.look'];
    final personalityError = formErrors?['people.$index.personality'];
    final knowsPlayerError = formErrors?['people.$index.knowsPlayer'];

    final hasError =
        nameError != null ||
        ageError != null ||
        lookError != null ||
        personalityError != null ||
        knowsPlayerError != null;

    final isEmpty = !hasName && !hasLook && person.age == null;

    String? errorMessage;
    if (hasError) {
      if (nameError != null && lookError != null) {
        errorMessage = 'Still needs a name and a look';
      } else if (nameError != null) {
        errorMessage = 'Still needs a name';
      } else if (lookError != null) {
        errorMessage = 'Still needs a look';
      } else if (ageError != null) {
        errorMessage = 'Still needs an age';
      } else {
        errorMessage = 'Still needs more detail';
      }
    }

    return GroupPersonCard(
      key: key,
      isFormMode: true,
      isEmpty: isEmpty,
      name: person.name,
      age: person.age,
      bond: person.closeness,
      look: person.look,
      hasError: hasError,
      errorMessage: errorMessage,
      onTap: onTap,
    );
  }

  /// Factory for an editor person card (with face states).
  factory GroupPersonCard.editor({
    Key? key,
    required GroupDraftPerson person,
    required int index,
    required VoidCallback onTap,
    VoidCallback? onPaintFace,
    GroupFace face = GroupFace.idle,
    bool faceWillReset = false,
    bool hasError = false,
    String? errorMessage,
  }) {
    return GroupPersonCard(
      key: key,
      isFormMode: false,
      name: person.name,
      age: person.age,
      bond: GroupCloseness.fromWire(person.startBond),
      look: person.appearance,
      portraitUrl: person.portraitUrl,
      portraitThumbUrl: person.portraitThumbUrl,
      faceStatus: face.status,
      faceMessage: face.message,
      faceWillReset: faceWillReset,
      hasError: hasError,
      errorMessage: errorMessage ?? (hasError ? 'Needs a look' : null),
      onTap: onTap,
      onPaintFace: onPaintFace,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isAddSlot) {
      return _buildAddSlot();
    }

    final hasPortrait =
        (portraitThumbUrl != null && portraitThumbUrl!.trim().isNotEmpty) ||
        (portraitUrl != null && portraitUrl!.trim().isNotEmpty);

    final cardBorder = hasError
        ? Border.all(color: EverloreTheme.crimson, width: 1.5)
        : Border.all(
            color: EverloreTheme.goldDim.withValues(alpha: 0.28),
            width: 1.0,
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: EverloreTheme.void2,
            borderRadius: BorderRadius.circular(16),
            border: cardBorder,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Face layer / Arch frame
                _buildFaceLayer(hasPortrait),

                // 2. Top-left faceWillReset badge
                if (faceWillReset)
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: EverloreTheme.void0.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'New face after you save',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: EverloreTheme.ui(
                            size: 10.5,
                            color: EverloreTheme.parchment,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),

                // 3. Bottom scrim
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 120,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          EverloreTheme.void1.withValues(alpha: 0.85),
                          EverloreTheme.void1,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),

                // 4. Bottom details
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 8,
                  child: isFormMode
                      ? _buildFormBottom()
                      : _buildEditorBottom(hasPortrait),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddSlot() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: EverloreTheme.void2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: EverloreTheme.goldDim.withValues(alpha: 0.28),
              width: 1.0,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 28, color: EverloreTheme.gold),
                const SizedBox(height: 8),
                Text(
                  'Add a person',
                  style: EverloreTheme.ui(
                    size: 13,
                    color: EverloreTheme.gold,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFaceLayer(bool hasPortrait) {
    if (isFormMode) {
      if (isEmpty || name.trim().isEmpty) {
        return GroupFaceFrame(
          key: ValueKey('form_${isEmpty ? "empty" : "err_no_name"}_$bond'),
          icon: Icons.person_outline,
          tone: _bondTone(bond),
          bond: bond,
        );
      }
      return GroupFaceFrame(
        key: ValueKey('form_arch_${name}_$bond'),
        initial: name,
        bond: bond,
      );
    }

    // Editor mode: one AnimatedSwitcher wrapping arch and portrait branches with distinct keys.
    final Widget child;
    if (hasPortrait && faceStatus != GroupFaceStatus.painting) {
      final url =
          (portraitThumbUrl != null && portraitThumbUrl!.trim().isNotEmpty)
          ? portraitThumbUrl!
          : portraitUrl!;

      child = EverloreNetworkImage(
        key: ValueKey('portrait_$url'),
        imageUrl: url,
        fit: BoxFit.cover,
        alignment: const Alignment(0, -0.55),
        placeholder: GroupFaceFrame(
          key: ValueKey('ph_${name}_$bond'),
          initial: name,
          bond: bond,
        ),
        errorWidget: GroupFaceFrame(
          key: ValueKey('err_${name}_$bond'),
          initial: name,
          bond: bond,
        ),
      );
    } else {
      final isPainting = faceStatus == GroupFaceStatus.painting;
      child = GroupFaceFrame(
        key: ValueKey('arch_${name}_${isPainting ? "painting" : "idle"}_$bond'),
        initial: name,
        bond: bond,
        pulsing: isPainting,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      child: child,
    );
  }

  Widget _buildFormBottom() {
    if (isEmpty || name.trim().isEmpty) {
      final showErr = hasError && errorMessage != null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Someone new',
            style: EverloreTheme.aiText.copyWith(
              fontSize: 16,
              color: EverloreTheme.parchment,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            showErr ? errorMessage! : 'Tap to describe them',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EverloreTheme.ui(
              size: 11,
              color: showErr ? EverloreTheme.crimson : EverloreTheme.ash,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                name.isNotEmpty ? name : 'Someone new',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: EverloreTheme.ui(
                  size: 16,
                  weight: FontWeight.w700,
                  color: EverloreTheme.parchment,
                ),
              ),
            ),
            if (age != null) ...[
              const SizedBox(width: 4),
              Text(
                '$age',
                style: EverloreTheme.ui(size: 13, color: EverloreTheme.ash),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: _bondTone(bond),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _bondLabel(bond),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: EverloreTheme.ui(
                  size: 12,
                  color: _bondTone(bond),
                  weight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        if (hasError && errorMessage != null) ...[
          const SizedBox(height: 2),
          Text(
            errorMessage!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EverloreTheme.ui(size: 11, color: EverloreTheme.crimson),
          ),
        ] else if (look != null && look!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            look!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: EverloreTheme.aiText.copyWith(
              fontSize: 13,
              color: EverloreTheme.ash,
              height: 1.25,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEditorBottom(bool hasPortrait) {
    final showRestingMessage =
        (faceStatus == GroupFaceStatus.resting ||
            faceStatus == GroupFaceStatus.unseen) &&
        faceMessage != null &&
        faceMessage!.isNotEmpty;

    final isPainting = faceStatus == GroupFaceStatus.painting;

    final showPaintPill =
        (faceStatus == GroupFaceStatus.idle && !hasPortrait) ||
        faceStatus == GroupFaceStatus.resting ||
        faceStatus == GroupFaceStatus.unseen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showRestingMessage) ...[
          Text(
            faceMessage!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: EverloreTheme.ui(size: 11, color: EverloreTheme.ash),
          ),
          const SizedBox(height: 4),
        ],
        if (isPainting) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Painting…',
              style: EverloreTheme.ui(
                size: 12,
                weight: FontWeight.w600,
                color: EverloreTheme.gold,
              ),
            ),
          ),
        ] else if (showPaintPill) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: _buildPaintPill(
              hasPortrait ? 'Paint again' : 'Paint a face',
            ),
          ),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            Flexible(
              child: Text(
                name.isNotEmpty ? name : 'Someone new',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: EverloreTheme.ui(
                  size: 16,
                  weight: FontWeight.w700,
                  color: EverloreTheme.parchment,
                ),
              ),
            ),
            if (age != null && age! > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$age',
                style: EverloreTheme.ui(size: 13, color: EverloreTheme.ash),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        if (hasError && errorMessage != null) ...[
          Text(
            errorMessage!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EverloreTheme.ui(size: 11, color: EverloreTheme.crimson),
          ),
        ] else ...[
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _bondTone(bond),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _bondLabel(bond),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EverloreTheme.ui(
                    size: 12,
                    color: _bondTone(bond),
                    weight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPaintPill(String label) {
    final pill = Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: EverloreTheme.void0.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: EverloreTheme.gold.withValues(alpha: 0.8),
          width: 1.0,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: EverloreTheme.ui(
          size: 11.5,
          weight: FontWeight.w600,
          color: EverloreTheme.gold,
        ),
      ),
    );

    if (onPaintFace == null) {
      return IgnorePointer(child: pill);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPaintFace,
      child: pill,
    );
  }

  static Color _bondTone(GroupCloseness? bond) =>
      GroupClosenessPicker.toneOf(bond);

  static String _bondLabel(GroupCloseness? bond) =>
      GroupClosenessPicker.labelOf(bond);
}
