import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../state/home_cubit.dart';
import 'widgets/world_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeCubit()..loadInstances(),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d0d1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0d0d1a),
        title: const Text(
          'Everlore',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.explore, color: Colors.white70),
            onPressed: () => context.push('/templates'),
            tooltip: 'Browse Worlds',
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white70),
            onPressed: () => context.push('/auth'),
          ),
        ],
      ),
      body: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          if (state.isLoading && state.instances.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.purpleAccent),
            );
          }

          if (state.error != null &&
              state.error!.contains('Unauthorized') &&
              state.instances.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    color: Colors.white24,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sign in to access your worlds',
                    style: TextStyle(color: Colors.white54, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/auth'),
                    icon: const Icon(Icons.login),
                    label: const Text('Open Auth'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                    ),
                  ),
                ],
              ),
            );
          }

          if (state.instances.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.auto_stories,
                    color: Colors.white24,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No worlds yet',
                    style: TextStyle(color: Colors.white54, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Browse templates to create your first world',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/templates'),
                    icon: const Icon(Icons.explore),
                    label: const Text('Browse Worlds'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => context.read<HomeCubit>().loadInstances(),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: state.instances.length,
              itemBuilder: (context, index) {
                final instance = state.instances[index];
                return WorldCard(
                  instance: instance,
                  onTap: () => context.push('/play/${instance.id}'),
                  onArchive: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Archive World?'),
                        content: const Text(
                          'This world will be archived. You can restore it later.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              context.read<HomeCubit>().archiveInstance(
                                instance.id,
                              );
                            },
                            child: const Text('Archive'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
