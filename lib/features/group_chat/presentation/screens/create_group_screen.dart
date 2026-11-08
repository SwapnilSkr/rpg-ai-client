import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/features/group_chat/state/create_group_cubit.dart';
import 'package:everlore/features/group_chat/state/create_group_state.dart';
import 'package:everlore/shared/widgets/everlore_notice.dart';
import 'package:everlore/shared/widgets/everlore_top_bar.dart';
import '../widgets/create_group/group_art_backdrop.dart';
import '../widgets/create_group/group_delete_sheet.dart';
import '../widgets/create_group/group_drafting_view.dart';
import '../widgets/create_group/group_editor_view.dart';
import '../widgets/create_group/group_form_view.dart';
import '../widgets/create_group/group_leave_sheet.dart';

/// Screen for creating, drafting and editing a group chat.
class CreateGroupScreen extends StatefulWidget {
  final String? templateId;

  const CreateGroupScreen({super.key, this.templateId});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.templateId != null) {
      final cubit = context.read<CreateGroupCubit>();
      if (cubit.state.draft?.id != widget.templateId) {
        cubit.load(widget.templateId!);
      }
    }
  }

  @override
  void didUpdateWidget(covariant CreateGroupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.templateId != null) {
      final cubit = context.read<CreateGroupCubit>();
      if (cubit.state.draft?.id != widget.templateId) {
        cubit.load(widget.templateId!);
      }
    }
  }

  Future<void> _handlePop(BuildContext context, CreateGroupState state) async {
    if (state.phase == CreateGroupPhase.drafting) {
      final stop = await showStopDraftingSheet(context);
      if (stop && context.mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (state.phase == CreateGroupPhase.editing && state.needsSave) {
      final leave = await showLeaveUnsavedSheet(context);
      if (leave && context.mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showGroupDeleteSheet(context);
    if (confirmed && context.mounted) {
      await context.read<CreateGroupCubit>().delete();
    }
  }

  Future<void> _confirmStartOver(BuildContext context) async {
    final confirmed = await showStartOverSheet(context);
    if (confirmed && context.mounted) {
      context.read<CreateGroupCubit>().backToForm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CreateGroupCubit, CreateGroupState>(
      listenWhen: (prev, curr) =>
          curr.isDeleted ||
          (curr.error != null && curr.phase != CreateGroupPhase.loading),
      listener: (context, state) {
        if (state.isDeleted) {
          Navigator.of(context).pop();
          return;
        }
        if (state.error != null) {
          showEverloreNotice(context, state.error!, tone: NoticeTone.error);
          context.read<CreateGroupCubit>().clearError();
        }
      },
      builder: (context, state) {
        final canPopDirectly =
            state.phase != CreateGroupPhase.drafting &&
            !(state.phase == CreateGroupPhase.editing && state.needsSave);

        final title = switch (state.phase) {
          CreateGroupPhase.form => 'New group',
          CreateGroupPhase.drafting => '',
          CreateGroupPhase.loading => 'Group',
          CreateGroupPhase.editing => 'Your group',
        };

        return PopScope(
          canPop: canPopDirectly,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              _handlePop(context, state);
            }
          },
          child: Scaffold(
            backgroundColor: EverloreTheme.void1,
            body: Stack(
              fit: StackFit.expand,
              children: [
                if (state.phase == CreateGroupPhase.form ||
                    state.phase == CreateGroupPhase.editing)
                  GroupArtBackdrop(coverUrl: state.draft?.imageThumbUrl),
                if (state.phase == CreateGroupPhase.drafting)
                  Positioned.fill(child: GroupDraftingView(state: state)),
                Column(
                  children: [
                    EverloreTopBar(
                      title: title,
                      showBack: true,
                      showProfile: false,
                      backgroundOpacity:
                          state.phase == CreateGroupPhase.drafting ? 0.0 : 0.68,
                      actions: [
                        if (state.phase == CreateGroupPhase.editing) ...[
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: state.isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: EverloreTheme.gold,
                                      ),
                                    )
                                  : state.needsSave
                                  ? GestureDetector(
                                      onTap: !state.isBusy
                                          ? () => context
                                                .read<CreateGroupCubit>()
                                                .save()
                                          : null,
                                      child: Text(
                                        'Save',
                                        style: EverloreTheme.ui(
                                          size: 14,
                                          weight: FontWeight.w700,
                                          color: EverloreTheme.gold,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      'Saved',
                                      style: EverloreTheme.ui(
                                        size: 13,
                                        color: EverloreTheme.ash,
                                      ),
                                    ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              color: EverloreTheme.ash,
                            ),
                            color: EverloreTheme.void2,
                            onSelected: (val) {
                              if (val == 'delete') _confirmDelete(context);
                              if (val == 'start_over') {
                                _confirmStartOver(context);
                              }
                            },
                            itemBuilder: (_) => [
                              if (state.draft?.id == null)
                                PopupMenuItem(
                                  value: 'start_over',
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.restart_alt,
                                        color: EverloreTheme.parchment,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Start over',
                                        style: EverloreTheme.ui(
                                          size: 14,
                                          color: EverloreTheme.parchment,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (state.draft?.id != null)
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.delete_outline,
                                        color: EverloreTheme.crimson,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Delete group',
                                        style: EverloreTheme.ui(
                                          size: 14,
                                          color: EverloreTheme.crimson,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    if (state.phase != CreateGroupPhase.drafting)
                      Expanded(child: _buildPhaseBody(context, state)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhaseBody(BuildContext context, CreateGroupState state) {
    switch (state.phase) {
      case CreateGroupPhase.form:
        return GroupFormView(state: state);
      case CreateGroupPhase.drafting:
        return GroupDraftingView(state: state);
      case CreateGroupPhase.loading:
        return _buildLoading(context, state);
      case CreateGroupPhase.editing:
        return GroupEditorView(state: state);
    }
  }

  Widget _buildLoading(BuildContext context, CreateGroupState state) {
    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: EverloreTheme.ui(size: 14, color: EverloreTheme.crimson),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  if (widget.templateId != null) {
                    context.read<CreateGroupCubit>().load(widget.templateId!);
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: EverloreTheme.goldDim.withValues(alpha: 0.35),
                  ),
                  foregroundColor: EverloreTheme.parchment,
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    fontFamily: EverloreTheme.uiFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const Center(
      child: SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: EverloreTheme.gold,
        ),
      ),
    );
  }
}
