import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/models/game_room.dart';
import 'package:turnos_juegos/core/models/local_player_profile.dart';
import 'package:turnos_juegos/core/models/player.dart';
import 'package:turnos_juegos/core/network/game_socket_client.dart';
import 'package:turnos_juegos/core/providers/network_providers.dart';
import 'package:turnos_juegos/core/providers/profile_providers.dart';
import 'package:turnos_juegos/features/lobby/lobby_screen.dart';
import 'package:turnos_juegos/server/host_room_controller.dart';

const _h = 'host-1', _g = 'guest-1';

Player _p(String id, String name, String c, String s, int slot) => Player(
      playerId: id,
      displayName: name,
      colorId: c,
      soundId: s,
      deviceId: 'd-$id',
      slotNumber: slot,
    );

GameRoom _room() {
  final host = _p(_h, 'Host', 'color_1', 'sound_1', 1);
  final guest = _p(_g, 'Guest', 'color_2', 'sound_2', 2);
  return GameRoom(
    roomId: 'r1',
    displayName: 'Sala',
    hostPlayerId: _h,
    slots: [_h, _g],
    turnSequence: [_h, _g],
    playersById: {_h: host, _g: guest},
  );
}

class _FakeHost extends HostRoomController {
  _FakeHost(this._room);
  final GameRoom _room;
  @override
  GameRoom? get room => _room;
}

class _FakeClient extends GameSocketClient {
  _FakeClient(Map<String, dynamic> lobby, String localId)
      : _lobby = lobby,
        super(deviceId: 'device-guest') {
    restoreLocalPlayerId(localId);
  }

  final Map<String, dynamic> _lobby;
  @override
  Map<String, dynamic>? get lastLobbyState => _lobby;
  @override
  Future<void> connect({required String host, required int port}) async {}
  @override
  Future<void> disconnect() async {}
}

class _FixedProfile extends LocalPlayerProfileNotifier {
  @override
  Future<LocalPlayerProfile> build() async => LocalPlayerProfile.defaults();
}

Finder _btn(Key row, Key btn) =>
    find.descendant(of: find.byKey(row), matching: find.byKey(btn));

void main() {
  final color = const Key('lobby-color-button');
  final sound = const Key('lobby-sound-button');

  testWidgets('host: own Color/Sound; guest read-only; admin present',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hostRoomControllerProvider.overrideWith((ref) => _FakeHost(_room())),
        ],
        child: const MaterialApp(home: LobbyScreen(role: 'host')),
      ),
    );
    await tester.pumpAndSettle();
    expect(_btn(const ValueKey(_h), color), findsOneWidget);
    expect(_btn(const ValueKey(_h), sound), findsOneWidget);
    expect(_btn(const ValueKey(_g), color), findsNothing);
    expect(_btn(const ValueKey(_g), sound), findsNothing);
    expect(find.byKey(const Key('lobby-admin-slot')), findsNWidgets(2));
    await tester.tap(_btn(const ValueKey(_h), color));
    await tester.pumpAndSettle();
    expect(find.text('Verde'), findsOneWidget);
  });

  testWidgets('client: own Color/Sound; no admin; other read-only',
      (tester) async {
    final room = _room();
    final client = _FakeClient({
      'playersById': room.playersById.map((k, v) => MapEntry(k, v.toJson())),
    }, _g);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceIdProvider.overrideWith((ref) async => 'device-guest'),
          localPlayerProfileProvider.overrideWith(_FixedProfile.new),
          gameSocketClientProvider.overrideWith((ref) => client),
        ],
        child: const MaterialApp(
          home: LobbyScreen(role: 'client', host: '127.0.0.1', port: 9),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lobby-admin-slot')), findsNothing);
    expect(_btn(const ValueKey(_g), color), findsOneWidget);
    expect(_btn(const ValueKey(_g), sound), findsOneWidget);
    expect(_btn(const ValueKey(_h), color), findsNothing);
    await tester.tap(_btn(const ValueKey(_g), sound));
    await tester.pumpAndSettle();
    expect(find.text('Clic claro'), findsOneWidget);
  });
}
