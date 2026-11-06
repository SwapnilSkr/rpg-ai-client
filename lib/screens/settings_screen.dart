import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app/theme/nexus_theme.dart';
import '../core/auth/auth_service.dart';
import '../core/auth/google_auth_service.dart';
import '../core/auth/group_notifications.dart';
import '../core/errors/user_message.dart';
import '../core/push/push_service.dart';
import '../core/reminders/reminder_service.dart';
import '../core/telemetry/telemetry.dart';
import '../shared/models/user.dart';
import '../shared/widgets/age_confirm_dialog.dart';
import '../shared/widgets/everlore_notice.dart';
import '../shared/widgets/settings_group.dart';
import 'reminder_switch_row.dart';
import 'sharing_switch_row.dart';

/// What used to crowd the profile: the mature-themes switch, reminders,
/// privacy and account deletion.
class SettingsScreen extends StatefulWidget {
  /// [user], [reminders], [messages] and [systemAllowsMessages] are seams for
  /// tests; production reads the cached session user, the shared reminder
  /// service, the account's preferences and the phone's notification setting.
  const SettingsScreen({
    super.key,
    this.user,
    this.reminders,
    this.messages = const GroupNotificationsPref(),
    this.systemAllowsMessages,
  });

  final User? user;
  final ReminderService? reminders;
  final GroupNotificationsPref messages;
  final Future<bool> Function()? systemAllowsMessages;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  User? _user;
  bool _loaded = false;
  bool _isUpdatingPreferences = false;
  bool _isDeletingAccount = false;
  String? _version;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    if (widget.user != null) {
      _user = widget.user;
      _loaded = true;
    } else {
      _loadUser();
    }
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      if (info.version.trim().isNotEmpty) {
        setState(() => _version = 'Everlore v${info.version.trim()}');
      }
    } catch (_) {}
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getCachedUser();
    if (!mounted) return;
    setState(() {
      _user = user;
      _loaded = true;
    });
  }

  Future<void> _handleNsfwToggle(bool enabled) async {
    final user = _user;
    if (user == null || _isUpdatingPreferences) return;

    if (enabled && user.ageConfirmedAt == null) {
      final confirmed = await showAgeConfirmDialog(context);
      if (!confirmed || !mounted) return;
    }

    setState(() => _isUpdatingPreferences = true);

    try {
      final payload = <String, dynamic>{
        'nsfw_enabled': enabled,
        if (enabled && user.ageConfirmedAt == null) 'age_confirmed': true,
      };
      final updated = await AuthService.updatePreferences(payload);
      if (!mounted) return;
      setState(() => _user = updated);
      showEverloreNotice(
        context,
        enabled
            ? 'Mature content enabled for eligible worlds.'
            : 'Mature content disabled.',
        tone: NoticeTone.success,
      );
    } catch (e) {
      if (!mounted) return;
      final message = userFacingError(
        e,
        fallback: 'Could not update that preference. Please try again.',
      );
      showEverloreNotice(context, message, tone: NoticeTone.error);
    } finally {
      if (mounted) setState(() => _isUpdatingPreferences = false);
    }
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: EverloreTheme.void2,
        title: Text(
          'Delete your account?',
          style: EverloreTheme.serifDisplay(
            size: 18,
            color: EverloreTheme.parchment,
          ),
        ),
        content: Text(
          'This permanently deletes your profile, all your realms and chats, '
          'and any worlds you created. This cannot be undone.',
          style: EverloreTheme.ui(
            size: 14,
            color: EverloreTheme.ash,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Cancel',
              style: EverloreTheme.ui(color: EverloreTheme.ash),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _handleDeleteAccount();
            },
            child: Text(
              'Delete',
              style: EverloreTheme.ui(color: EverloreTheme.crimson),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteAccount() async {
    // Taken before the awaits: the account is gone once the call succeeds, so
    // the player must still reach /auth even if they backed out meanwhile.
    final router = GoRouter.of(context);
    setState(() => _isDeletingAccount = true);
    try {
      await AuthService.deleteAccount();
      Telemetry.instance.track('account_action', {'action': 'account_deleted'});
      try {
        // Best-effort: the account is already gone. Offline, the Google and
        // Firebase sign-out can hang for many seconds before giving up.
        await GoogleAuthService().signOut().timeout(const Duration(seconds: 2));
      } catch (_) {}
      router.go('/auth');
      // The notice rides the root overlay, which outlives this screen; with
      // no mounted context left there is nothing to attach it to.
      if (!mounted) return;
      showEverloreNotice(
        context,
        'Your account was deleted.',
        tone: NoticeTone.success,
      );
    } catch (e) {
      if (!mounted) return;
      final message = userFacingError(
        e,
        fallback: 'Your account was not deleted. Please try again.',
      );
      setState(() => _isDeletingAccount = false);
      showEverloreNotice(context, message, tone: NoticeTone.error);
    }
  }

  Widget _body() {
    if (!_loaded) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: EverloreTheme.gold,
            strokeWidth: 2,
          ),
        ),
      );
    }
    final user = _user;
    final signedIn = user != null && !user.guest;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ListView(
      padding: EdgeInsets.fromLTRB(28, 12, 28, 40 + bottomInset),
      children: [
        const SettingsSectionLabel('Story', isFirst: true),
        SettingsGroup(
          children: [
            SettingsSwitchRow(
              icon: Icons.local_fire_department_outlined,
              title: 'Allow mature themes',
              subtitle: 'Needed before a world with mature themes will open.',
              value: user?.preferences.nsfwEnabled ?? false,
              onChanged: (user == null || _isUpdatingPreferences)
                  ? null
                  : _handleNsfwToggle,
              busy: _isUpdatingPreferences,
            ),
          ],
        ),
        const SettingsSectionLabel('Reminders'),
        SettingsGroup(
          children: [
            ReminderSwitchRow(service: widget.reminders),
            if (signedIn)
              _MessagesSwitchRow(
                pref: widget.messages,
                systemAllows: widget.systemAllowsMessages,
              ),
          ],
        ),
        const SettingsSectionLabel('Privacy'),
        SettingsGroup(
          children: [
            const SharingSwitchRow(),
            SettingsNavRow(
              icon: Icons.shield_outlined,
              label: 'Blocked content',
              onTap: () => context.push('/blocked-content'),
            ),
          ],
        ),
        if (signedIn) ...[
          const SettingsSectionLabel('Account'),
          SettingsGroup(
            children: [
              SettingsNavRow(
                icon: Icons.delete_outline_rounded,
                label: _isDeletingAccount
                    ? 'Deleting your account…'
                    : 'Delete account',
                tone: EverloreTheme.crimson,
                busy: _isDeletingAccount,
                onTap: _isDeletingAccount ? null : _confirmDeleteAccount,
              ),
            ],
          ),
        ],
        if (_version != null) ...[
          const SizedBox(height: 24),
          Center(
            child: Text(
              _version!,
              style: EverloreTheme.ui(
                size: 11.5,
                color: EverloreTheme.ash.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EverloreTheme.void1,
      appBar: AppBar(
        backgroundColor: EverloreTheme.void0,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: EverloreTheme.ash,
            size: 18,
          ),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(
          'Settings',
          style: EverloreTheme.serifDisplay(
            size: 19,
            color: EverloreTheme.parchment,
          ),
        ),
      ),
      body: _body(),
    );
  }
}

/// The switch for messages from the player's stories. Reads and writes the
/// account's own preference; the phone's notification setting only decides
/// whether the player is reminded to allow it.
class _MessagesSwitchRow extends StatefulWidget {
  const _MessagesSwitchRow({required this.pref, this.systemAllows});

  final GroupNotificationsPref pref;
  final Future<bool> Function()? systemAllows;

  @override
  State<_MessagesSwitchRow> createState() => _MessagesSwitchRowState();
}

class _MessagesSwitchRowState extends State<_MessagesSwitchRow> {
  // Absent reads as on, so that is what shows until the account answers.
  bool _on = true;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final on = await widget.pref.read();
      if (!mounted || _updating) return;
      setState(() => _on = on);
    } catch (_) {
      // Stays as shown; the next open reads again.
    }
  }

  Future<bool> _systemAllows() async {
    try {
      return await (widget.systemAllows ??
          PushService.instance.permissionGranted)();
    } catch (_) {
      return true;
    }
  }

  Future<void> _toggle(bool value) async {
    final before = _on;
    setState(() {
      _on = value;
      _updating = true;
    });
    try {
      await widget.pref.write(value);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _on = before;
        _updating = false;
      });
      showEverloreNotice(
        context,
        userFacingError(
          e,
          fallback: 'Could not update that preference. Please try again.',
        ),
        tone: NoticeTone.error,
      );
      return;
    }
    if (!mounted) return;
    setState(() => _updating = false);
    if (value && !await _systemAllows()) {
      if (!mounted) return;
      showEverloreNotice(
        context,
        'Allow notifications for Everlore, then turn this on.',
        tone: NoticeTone.info,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSwitchRow(
      icon: Icons.chat_bubble_outline_rounded,
      title: 'Messages from your stories',
      subtitle: "When someone writes to you, or a story moves on while you're away.",
      value: _on,
      onChanged: _updating ? null : _toggle,
      busy: _updating,
    );
  }
}
