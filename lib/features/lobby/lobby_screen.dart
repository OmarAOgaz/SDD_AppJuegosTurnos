import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/catalogs/color_catalog.dart';
import '../../core/catalogs/sound_catalog.dart';
import '../../core/constants/message_types.dart';
import '../../core/domain/eligible_picker.dart';
import '../../core/models/game_phase.dart';
import '../../core/models/local_player_profile.dart';
import '../../core/models/player.dart';
import '../../core/models/room_config.dart';
import '../../core/models/ws_envelope.dart';
import '../../core/network/game_socket_client.dart';
import '../../core/providers/network_providers.dart';
import '../../core/providers/profile_providers.dart';
import 'widgets/lobby_player_row.dart';

/// Pre-game lobby for host and joining clients.
class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({
    super.key,
    this.role = 'host',
    this.host,
    this.port,
  });

  final String role;
  final String? host;
  final int? port;

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  StreamSubscription<WsEnvelope>? _messageSub;
  StreamSubscription<SocketClientState>? _stateSub;
  GameSocketClient? _client;
  String? _statusMessage;
  bool _joinSent = false;
  bool _roomDiscarded = false;
  /// When true, dispose must not tear down the socket (lobby → game).
  bool _retainClientSession = false;
  final _roomNameController = TextEditingController();

  bool get _isHost => widget.role == 'host';

  @override
  void initState() {
    super.initState();
    if (!_isHost) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _connectClient());
    } else {
      final room = ref.read(hostRoomControllerProvider).room;
      _roomNameController.text = room?.displayName ?? '';
    }
  }

  @override
  void dispose() {
    unawaited(_messageSub?.cancel());
    unawaited(_stateSub?.cancel());
    if (!_isHost && !_retainClientSession) {
      final playerId = _client?.localPlayerId;
      if (playerId != null && _client?.state == SocketClientState.connected) {
        _client?.sendLeave(playerId: playerId);
      }
      unawaited(_client?.disconnect());
    }
    _roomNameController.dispose();
    super.dispose();
  }

  Future<void> _connectClient() async {
    final host = widget.host;
    final port = widget.port;
    if (host == null || port == null) {
      setState(() => _statusMessage = 'Falta host o puerto');
      return;
    }

    await ref.read(deviceIdProvider.future);
    final profile = await ref.read(localPlayerProfileProvider.future);
    final client = ref.read(gameSocketClientProvider);
    if (client == null) {
      setState(() => _statusMessage = 'Device id no listo');
      return;
    }
    _client = client;

    _messageSub = client.messages.listen(_onClientMessage);
    _stateSub = client.stateChanges.listen((state) {
      if (!mounted) {
        return;
      }
      setState(() => _statusMessage = 'Estado: ${state.name}');
      if (state == SocketClientState.connected && !_joinSent) {
        _sendJoin(profile);
      }
    });

    setState(() => _statusMessage = 'Conectando a $host:$port…');
    await client.connect(host: host, port: port);
    if (client.state == SocketClientState.connected && !_joinSent) {
      _sendJoin(profile);
    }
  }

  void _sendJoin(LocalPlayerProfile profile) {
    final client = _client;
    if (client == null || _joinSent) {
      return;
    }
    _joinSent = true;
    client.sendJoin(
      displayName: profile.defaultDisplayName,
      preferredColorIds: profile.preferredColorIds,
      preferredSoundIds: profile.preferredSoundIds,
    );
  }

  void _onClientMessage(WsEnvelope envelope) {
    if (!mounted) {
      return;
    }
    if (envelope.type == MessageTypes.roomDiscarded) {
      setState(() => _roomDiscarded = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El host cerró la sala')),
      );
      context.go('/');
      return;
    }
    if (envelope.type == MessageTypes.lobbyState) {
      setState(() {});
    }
    if (envelope.type == MessageTypes.gameState) {
      ref.read(clientSyncProvider.notifier).applyEnvelope(envelope);
      final phase = envelope.payload['gamePhase'];
      if (phase == GameRoomPhase.inGame.wireValue) {
        // Keep the WebSocket + localPlayerId across lobby → game navigation.
        _retainClientSession = true;
        context.go(
          '/game?role=client&host=${Uri.encodeComponent(widget.host!)}'
          '&port=${widget.port}',
        );
      }
      if (phase == GameRoomPhase.ended.wireValue) {
        context.go('/ended');
      }
    }
  }

  List<Player> _playersFromLobbyState(Map<String, dynamic>? payload) {
    if (payload == null) {
      return const [];
    }
    final playersRaw = payload['playersById'];
    if (playersRaw is! Map) {
      return const [];
    }
    final players = playersRaw.values
        .whereType<Map>()
        .map((json) => Player.fromJson(Map<String, dynamic>.from(json)))
        .toList();
    players.sort((a, b) => a.slotNumber.compareTo(b.slotNumber));
    return players;
  }

  @override
  Widget build(BuildContext context) {
    if (_isHost) {
      return _buildHost(context);
    }
    return _buildClient(context);
  }

  Widget _buildHost(BuildContext context) {
    final controller = ref.watch(hostRoomControllerProvider);
    final room = controller.room;

    if (room == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lobby')),
        body: const Center(child: Text('No hay sala activa. Creá una desde Home.')),
      );
    }

    final players = room.seatedPlayers();
    final canStart = controller.canStartGame();

    return Scaffold(
      appBar: AppBar(
        title: Text('Lobby — ${room.displayName}'),
        actions: [
          TextButton(
            onPressed: () async {
              await controller.discardRoom();
              if (context.mounted) {
                context.go('/');
              }
            },
            child: const Text('Cerrar sala'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Jugadores (${players.length}/${room.config.maxPlayers})'),
          const SizedBox(height: 8),
          ...players.map(
            (player) => LobbyPlayerRow(
              key: ValueKey(player.playerId),
              player: player,
              isSelf: player.playerId == room.hostPlayerId,
              showHostAdminSlot: true,
              onNameChanged: player.playerId == room.hostPlayerId
                  ? (value) => controller.updateLocalPlayer(
                        player.playerId,
                        displayName: value,
                      )
                  : null,
            ),
          ),
          const Divider(height: 32),
          Text('Configuración', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _roomNameController,
            decoration: const InputDecoration(labelText: 'Nombre de sala'),
            onSubmitted: (value) {
              controller.setRoomDisplayName(value);
              setState(() {});
            },
          ),
          const SizedBox(height: 8),
          _configRow(
            label: 'Duración turno (s)',
            value: room.config.turnDurationSeconds,
            min: RoomConfig.minTurnDurationSeconds,
            max: RoomConfig.maxTurnDurationSeconds,
            divisions: (RoomConfig.maxTurnDurationSeconds -
                    RoomConfig.minTurnDurationSeconds) ~/
                RoomConfig.turnDurationStepSeconds,
            onChanged: (value) {
              controller.setTurnDuration(value.round());
              setState(() {});
            },
          ),
          _configRow(
            label: 'Incremento por ronda (s)',
            value: room.config.roundIncrementSeconds,
            min: RoomConfig.minRoundIncrementSeconds,
            max: RoomConfig.maxRoundIncrementSeconds,
            divisions: RoomConfig.maxRoundIncrementSeconds,
            onChanged: (value) {
              controller.setRoundIncrement(value.round());
              setState(() {});
            },
          ),
          SwitchListTile(
            title: const Text('Orden variable por ronda'),
            value: room.config.variableTurnOrder,
            onChanged: (value) {
              controller.setVariableTurnOrder(value);
              setState(() {});
            },
          ),
          DropdownButtonFormField<int>(
            initialValue: room.config.maxPlayers,
            decoration: const InputDecoration(labelText: 'Máx. jugadores'),
            items: List.generate(7, (index) => index + 2)
                .map(
                  (count) => DropdownMenuItem(
                    value: count,
                    child: Text('$count'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              controller.setMaxPlayers(value);
              setState(() {});
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: canStart
                ? () async {
                    final started = await controller.startGame();
                    if (!context.mounted) {
                      return;
                    }
                    if (started) {
                      controller.showHostKeepOpenBannerIfNeeded(context);
                      context.go('/game?role=host');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Se necesitan al menos 2 jugadores'),
                        ),
                      );
                    }
                  }
                : null,
            child: Text(
              canStart
                  ? 'Iniciar partida'
                  : 'Iniciar partida (mín. 2 jugadores)',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClient(BuildContext context) {
    final client = _client;
    final lobbyState = client?.lastLobbyState;
    final players = _playersFromLobbyState(lobbyState);
    final localPlayerId = client?.localPlayerId;
    Player? localPlayer;
    for (final player in players) {
      if (player.playerId == localPlayerId) {
        localPlayer = player;
        break;
      }
    }

    if (_roomDiscarded) {
      return const Scaffold(
        body: Center(child: Text('La sala fue cerrada por el host')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Lobby')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_statusMessage != null) Text(_statusMessage!),
          const SizedBox(height: 12),
          Text('Jugadores (${players.length})'),
          const SizedBox(height: 8),
          if (players.isEmpty)
            const Text('Esperando LOBBY_STATE…')
          else
            ...players.map(
              (player) => LobbyPlayerRow(
                key: ValueKey(player.playerId),
                player: player,
                isSelf: player.playerId == localPlayerId,
                showHostAdminSlot: false,
                onNameChanged: player.playerId == localPlayerId
                    ? (value) => _client?.sendUpdatePlayer(
                          playerId: player.playerId,
                          displayName: value,
                        )
                    : null,
              ),
            ),
          if (localPlayer != null) ...[
            const Divider(height: 32),
            Text('Tu perfil', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _clientSelfEditor(localPlayer, lobbyState),
          ],
        ],
      ),
    );
  }

  Widget _clientSelfEditor(Player player, Map<String, dynamic>? lobbyState) {
    final takenColors = _takenColors(lobbyState);
    final takenSounds = _takenSounds(lobbyState);
    final colorOptions = eligibleColorIds(
      takenColorIds: takenColors,
      ownColorId: player.colorId,
    );
    final soundOptions = eligibleSoundIds(
      takenSoundIds: takenSounds,
      ownSoundId: player.soundId,
    );

    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: player.colorId,
          decoration: const InputDecoration(labelText: 'Color'),
          items: colorOptions
              .map(
                (id) => DropdownMenuItem(
                  value: id,
                  child: Text(ColorCatalog.byId(id)?.displayName ?? id),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) {
              return;
            }
            _client?.sendUpdatePlayer(
              playerId: player.playerId,
              colorId: value,
            );
          },
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: player.soundId,
          decoration: const InputDecoration(labelText: 'Sonido'),
          items: soundOptions
              .map(
                (id) => DropdownMenuItem(
                  value: id,
                  child: Text(SoundCatalog.byId(id)?.displayName ?? id),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) {
              return;
            }
            _client?.sendUpdatePlayer(
              playerId: player.playerId,
              soundId: value,
            );
          },
        ),
      ],
    );
  }

  Set<String> _takenColors(Map<String, dynamic>? lobbyState) {
    return _playersFromLobbyState(lobbyState)
        .map((player) => player.colorId)
        .toSet();
  }

  Set<String> _takenSounds(Map<String, dynamic>? lobbyState) {
    return _playersFromLobbyState(lobbyState)
        .map((player) => player.soundId)
        .toSet();
  }

  Widget _configRow({
    required String label,
    required int value,
    required int min,
    required int max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $value'),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
