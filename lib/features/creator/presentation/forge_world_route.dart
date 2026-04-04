import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/nexus_theme.dart';
import '../../../core/auth/auth_service.dart';
import '../../../shared/models/user.dart';
import '../../../shared/models/world_template.dart';
import '../data/creator_repository.dart';
import 'forge_world_screen.dart';

/// Tier gate + optional fetch-by-id for deep links (`/my-worlds/:id/forge` without `extra`).
class ForgeWorldRoute extends StatelessWidget {
  final WorldTemplate? existing;
  final String? templateId;

  const ForgeWorldRoute({
    super.key,
    this.existing,
    this.templateId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User?>(
      future: AuthService.getCachedUser(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: EverloreTheme.void1,
            body: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: EverloreTheme.gold,
                ),
              ),
            ),
          );
        }
        final user = snap.data;
        if (user == null) {
          return _gateScaffold(
            context,
            title: 'Sign in to forge',
            body:
                'You need an account to use the arcane forge.',
            buttonLabel: 'Sign In',
            onPressed: () => context.push('/auth'),
          );
        }
        if (user.tier == 'free') {
          return _gateScaffold(
            context,
            title: 'Ascend to forge',
            body:
                'World creation requires Premium or Creator tier. Upgrade from My Worlds.',
            buttonLabel: 'Back',
            onPressed: () => context.go('/my-worlds'),
          );
        }

        if (existing != null) {
          return ForgeWorldScreen(existing: existing);
        }

        final id = templateId?.trim();
        if (id == null || id.isEmpty) {
          return const ForgeWorldScreen();
        }

        return FutureBuilder<WorldTemplate>(
          future: CreatorRepository.getById(id),
          builder: (context, templateSnap) {
            if (templateSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: EverloreTheme.void1,
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: EverloreTheme.gold,
                        ),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Loading world…',
                        style: TextStyle(color: EverloreTheme.ash, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (templateSnap.hasError) {
              return _gateScaffold(
                context,
                title: 'Could not load world',
                body: templateSnap.error.toString(),
                buttonLabel: 'Back',
                onPressed: () => context.go('/my-worlds'),
              );
            }
            final t = templateSnap.data!;
            return ForgeWorldScreen(existing: t);
          },
        );
      },
    );
  }

  Widget _gateScaffold(
    BuildContext context, {
    required String title,
    required String body,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Scaffold(
      backgroundColor: EverloreTheme.void1,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 16),
                  child: Icon(Icons.arrow_back_ios_new,
                      size: 18, color: EverloreTheme.ash),
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  color: EverloreTheme.parchment,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                body,
                style: const TextStyle(
                  color: EverloreTheme.ash,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onPressed,
                  child: Text(buttonLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
