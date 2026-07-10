import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/network_providers.dart';

/// Minimal post-game screen — exit to Home.
class EndedScreen extends ConsumerWidget {
  const EndedScreen({super.key});

  Future<void> _goHome(WidgetRef ref, BuildContext context) async {
    final resumeStore = ref.read(gameResumeStoreProvider).asData?.value;
    await resumeStore?.clear();
    await ref.read(gameSocketClientProvider)?.disconnect();
    ref.read(clientSyncProvider.notifier).reset();
    if (context.mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Partida terminada')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.flag_outlined, size: 64),
              const SizedBox(height: 16),
              Text(
                'Partida terminada',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => _goHome(ref, context),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
