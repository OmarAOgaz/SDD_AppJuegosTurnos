import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/game_room.dart';
import '../../core/providers/network_providers.dart';
import '../../core/utils/duration_format.dart';
import 'widgets/player_summary_card.dart';

/// Post-game summary screen — reads authoritative ended snapshot from sync.
class EndedScreen extends ConsumerWidget {
  const EndedScreen({super.key});

  Future<void> _goHome(WidgetRef ref, BuildContext context) async {
    final resumeStore = await ref.read(gameResumeStoreProvider.future);
    await resumeStore.clear();
    await ref.read(gameSocketClientProvider)?.disconnect();
    ref.read(clientSyncProvider.notifier).reset();
    if (context.mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(clientSyncProvider).lastGameState;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Partida terminada'),
        actions: [
          TextButton(
            onPressed: () => _goHome(ref, context),
            child: const Text('Salir'),
          ),
        ],
      ),
      body: snapshot == null
          ? _EmptySummaryBody(onExit: () => _goHome(ref, context))
          : _MatchSummaryBody(room: GameRoom.fromSnapshot(snapshot)),
    );
  }
}

class _EmptySummaryBody extends StatelessWidget {
  const _EmptySummaryBody({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.flag_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              'No hay datos de resumen disponibles.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchSummaryBody extends StatelessWidget {
  const _MatchSummaryBody({required this.room});

  final GameRoom room;

  @override
  Widget build(BuildContext context) {
    final startedAt = room.turnState.matchStartedAtMs;
    final endedAt = room.turnState.matchEndedAtMs;
    final totalMs = startedAt != null && endedAt != null
        ? endedAt - startedAt
        : null;

    final players = <String>[];
    for (final playerId in room.turnSequence) {
      if (room.playersById.containsKey(playerId)) {
        players.add(playerId);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumen general',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _SummaryRow(
                  label: 'Tiempo total',
                  value: totalMs != null
                      ? formatDurationMs(totalMs)
                      : '—',
                ),
                _SummaryRow(
                  label: 'Rondas jugadas',
                  value: '${room.turnState.currentRound}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Jugadores',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        for (final playerId in players)
          PlayerSummaryCard(player: room.playersById[playerId]!),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}
