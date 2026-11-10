import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../core/errors/user_message.dart';
import '../../../../core/guide/guide_anchor.dart';
import '../../../../core/guide/guide_flows.dart';
import '../../../../core/guide/guide_ids.dart';
import '../../../../core/guide/guide_trigger.dart';
import '../../../../shared/models/world_instance.dart';
import '../../../../shared/models/world_template.dart';
import '../../../../shared/widgets/everlore_network_image.dart';
import '../../../../shared/widgets/everlore_notice.dart';
import '../../../../shared/widgets/everlore_session_loader.dart';
import '../../../home/data/home_repository.dart';
import '../../../templates/data/template_repository.dart';
import '../../models/group_chat_models.dart';
import '../../state/chats_cubit.dart';
import '../widgets/create_group/group_face_mosaic.dart';
import '../widgets/member_avatar.dart';

/// Preview screen for a group chat world before joining.
/// Shows full-bleed cover fading into void0, title, description,
/// member portraits, and Join/Open button.
class GroupPreviewScreen extends StatefulWidget {
  final String templateId;
  final WorldTemplate? template;

  /// Seams for tests; production reads and creates saves through the home
  /// repository.
  final Future<List<WorldInstance>> Function()? loadSaves;
  final Future<WorldInstance> Function(String templateId)? createSave;

  const GroupPreviewScreen({
    super.key,
    required this.templateId,
    this.template,
    this.loadSaves,
    this.createSave,
  });

  @override
  State<GroupPreviewScreen> createState() => _GroupPreviewScreenState();
}

class _GroupPreviewScreenState extends State<GroupPreviewScreen> {
  WorldTemplate? _template;
  WorldInstance? _existingSave;
  bool _isLoading = true;
  bool _descriptionExpanded = false;
  late final ChatsCubit _chats;

  /// A create is running: a second tap must not make a second save.
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _chats = context.read<ChatsCubit>();
    _template = widget.template;
    _loadData();
  }

  Future<void> _loadData() async {
    WorldTemplate? loadedTemplate = _template;
    WorldInstance? foundSave;

    try {
      if (loadedTemplate == null || loadedTemplate.members.isEmpty) {
        loadedTemplate = await TemplateRepository.getById(widget.templateId);
      }
    } catch (_) {}

    try {
      final instances =
          await (widget.loadSaves ??
              () => HomeRepository.getInstances(forceRefresh: true))();
      for (final inst in instances) {
        if (inst.templateId == widget.templateId ||
            inst.template?['id'] == widget.templateId) {
          foundSave = inst;
          break;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _template = loadedTemplate ?? _template;
        _existingSave = foundSave;
        _isLoading = false;
      });
    }
  }

  void _showMemberPortrait(TemplateMember member) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: EverloreTheme.ash.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (member.portraitUrl != null && member.portraitUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 340),
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: EverloreNetworkImage(
                        imageUrl: member.portraitUrl!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                )
              else
                MemberAvatar(name: member.name, size: 96),
              const SizedBox(height: 16),
              Text(
                member.name,
                style: EverloreTheme.cardTitle.copyWith(
                  color: EverloreTheme.parchment,
                  fontSize: 20,
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
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAction() async {
    if (_joining) return;
    var save = _existingSave;
    if (save == null) {
      final template = _template;
      if (template == null) return;
      _joining = true;
      try {
        save = await showEverloreSessionLoading(
          context,
          message: 'Entering group',
          task: () =>
              (widget.createSave ?? HomeRepository.createInstance)(template.id),
        );
      } catch (e) {
        if (mounted) {
          showEverloreNotice(
            context,
            userFacingError(e, fallback: 'Could not join that group.'),
            tone: NoticeTone.error,
          );
        }
      } finally {
        _joining = false;
      }
      if (!mounted || save == null) return;
      // Coming back to this screen must open the save, not make another.
      _existingSave = save;
      setState(() {});
    }

    final id = save.id;
    unawaited(_chats.markOpened(id));
    await context.push('/group/$id');
    unawaited(_chats.markOpened(id));
    unawaited(_chats.refresh());
  }

  @override
  Widget build(BuildContext context) {
    final template = _template;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final coverHeight = screenHeight * 0.50;

    final description = template != null
        ? (template.description.isNotEmpty
              ? template.description
              : template.globalLore)
        : '';

    final members = template?.members ?? const <TemplateMember>[];

    return Scaffold(
      backgroundColor: EverloreTheme.void0,
      body: GuideOnEnter(
        flow: GuideFlows.groupPreview,
        enabled: !_isLoading && members.isNotEmpty,
        child: Stack(
          children: [
            // Scrollable body
            CustomScrollView(
              slivers: [
                // Top Cover in top two-thirds fading into void0
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: coverHeight,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (template != null && template.imageUrl.isNotEmpty)
                          EverloreNetworkImage(
                            imageUrl: template.imageUrl,
                            fit: BoxFit.cover,
                          )
                        else
                          // Mosaic fallback from template members when group has no cover;
                          // Stack(fit: expand) inside bounded SizedBox gives bounded parent.
                          GroupFaceMosaic(
                            faceUrls: [
                              for (final m
                                  in template?.members ??
                                      const <TemplateMember>[])
                                // The full painting: tiles here are far larger than a thumbnail.
                                if ((m.portraitUrl ?? m.portraitThumbUrl) !=
                                        null &&
                                    (m.portraitUrl ?? m.portraitThumbUrl)!
                                        .isNotEmpty)
                                  (m.portraitUrl ?? m.portraitThumbUrl)!,
                            ],
                          ),
                        // Top gradient for status bar legibility
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 100,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    EverloreTheme.void0.withValues(alpha: 0.55),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Bottom fade into void0
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: coverHeight * 0.65,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  EverloreTheme.void0.withValues(alpha: 0.55),
                                  EverloreTheme.void0.withValues(alpha: 0.9),
                                  EverloreTheme.void0,
                                ],
                                stops: const [0.0, 0.45, 0.8, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Title, description, and cast
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          template?.title ?? 'Group Chat',
                          style: EverloreTheme.serifDisplay(
                            size: 26,
                            color: EverloreTheme.parchment,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Description in aiText, up to 4 lines then More
                        if (description.isNotEmpty) ...[
                          Text(
                            description,
                            maxLines: _descriptionExpanded ? null : 4,
                            overflow: _descriptionExpanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: EverloreTheme.aiText.copyWith(
                              fontSize: 15,
                              color: EverloreTheme.parchment.withValues(
                                alpha: 0.88,
                              ),
                              height: 1.5,
                            ),
                          ),
                          if (description.length > 160)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _descriptionExpanded = !_descriptionExpanded;
                                });
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: 6,
                                  bottom: 4,
                                ),
                                child: Text(
                                  _descriptionExpanded ? 'Less' : 'More',
                                  style: EverloreTheme.ui(
                                    size: 13,
                                    weight: FontWeight.w600,
                                    color: EverloreTheme.gold,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),
                        ],

                        // Who's in it: horizontal row of 64px portraits
                        if (members.isNotEmpty) ...[
                          Text(
                            "WHO'S IN IT",
                            style: EverloreTheme.ui(
                              size: 11,
                              weight: FontWeight.w700,
                              color: EverloreTheme.goldDim,
                              spacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GuideAnchor(
                            id: GuideIds.groupPreviewFaces,
                            child: SizedBox(
                              height: 124,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: members.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 16),
                                itemBuilder: (context, index) {
                                  final member = members[index];
                                  final firstName = member.name
                                      .trim()
                                      .split(' ')
                                      .first;

                                  return GestureDetector(
                                    onTap: () => _showMemberPortrait(member),
                                    behavior: HitTestBehavior.opaque,
                                    child: SizedBox(
                                      width: 72,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          MemberAvatar(
                                            member: GroupMember(
                                              id: 'm_$index',
                                              name: member.name,
                                              role: member.role,
                                              portraitUrl: member.portraitUrl,
                                              portraitThumbUrl:
                                                  member.portraitThumbUrl,
                                            ),
                                            portraitUrl: member.portraitUrl,
                                            portraitThumbUrl:
                                                member.portraitThumbUrl,
                                            name: member.name,
                                            size: 64,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            firstName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: EverloreTheme.ui(
                                              size: 12,
                                              weight: FontWeight.w600,
                                              color: EverloreTheme.parchment,
                                            ),
                                          ),
                                          if (member.role.isNotEmpty)
                                            Text(
                                              member.role,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: EverloreTheme.ui(
                                                size: 10,
                                                color: EverloreTheme.ash,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Top back button
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, top: 8),
                  child: Semantics(
                    button: true,
                    label: 'Back',
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: EverloreTheme.void0.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: EverloreTheme.parchment,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Fixed bottom button in safe area
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      EverloreTheme.void0,
                      EverloreTheme.void0.withValues(alpha: 0.92),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.65, 1.0],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EverloreTheme.gold,
                        foregroundColor: EverloreTheme.void0,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _isLoading ? null : _handleAction,
                      child: Text(
                        _existingSave != null ? 'Open' : 'Join',
                        style: EverloreTheme.ui(
                          size: 15,
                          weight: FontWeight.w700,
                          spacing: 1.2,
                          color: EverloreTheme.void0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
