import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:turnos_juegos/core/domain/lobby_rules.dart';
import 'package:turnos_juegos/core/models/game_room.dart';
import 'package:turnos_juegos/core/models/local_player_profile.dart';
import 'package:turnos_juegos/core/models/player.dart';
import 'package:turnos_juegos/core/network/game_socket_client.dart';
import 'package:turnos_juegos/core/providers/network_providers.dart';
import 'package:turnos_juegos/core/providers/profile_providers.dart';
import 'package:turnos_juegos/features/lobby/lobby_screen.dart';
import 'package:turnos_juegos/server/host_room_controller.dart';

/// Device: `flutter test integration_test/lobby_host_reorder_drag_integration_test.dart -d <id>`
/// Host drag path through LobbyScreen + ReorderableDragStartListener (no direct callback).
const _h = 'host-1';
const _g = 'guest-1';

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

class _TrackingHost extends HostRoomController {
  _TrackingHost(this._room);

  final GameRoom _room;
  final List<List<String>> reorderCalls = [];

  @override
  GameRoom? get room => _room;

  @override
  bool reorderSeats(List<String> orderedPlayerIds) {
    reorderCalls.add(List<String>.from(orderedPlayerIds));
    final ok = LobbyRules.tryReorderSeats(_room, orderedPlayerIds);
    if (ok) {
      notifyListeners();
    }
    return ok;
  }
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

Finder _row(String id) => find.byKey(ValueKey(id));

Finder _handleOnRow(String id) => find.descendant(
      of: _row(id),
      matching: find.byKey(const Key('lobby-reorder-drag')),
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'host drag handle reorders rows visually and atomically',
    (tester) async {
      final room = _room();
      final host = _TrackingHost(room);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostRoomControllerProvider.overrideWith((ref) => host),
          ],
          child: const MaterialApp(home: LobbyScreen(role: 'host')),
        ),
      );
      await tester.pumpAndSettle();

      expect(_handleOnRow(_h), findsOneWidget);
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));
      expect(tester.getTopLeft(_row(_h)).dy,
          lessThan(tester.getTopLeft(_row(_g)).dy));
      expect(find.text('Jugador 1 (Tú)'), findsOneWidget);
      expect(find.text('Jugador 2'), findsOneWidget);

      final dragDy =
          tester.getCenter(_row(_g)).dy - tester.getCenter(_row(_h)).dy + 24;
      await tester.timedDrag(
        _handleOnRow(_h),
        Offset(0, dragDy),
        const Duration(milliseconds: 800),
      );
      await tester.pumpAndSettle();

      // Gesture path only — never tapped arrows.
      expect(host.reorderCalls, [
        [_g, _h],
      ]);
      expect(room.slots, [_g, _h]);
      expect(room.turnSequence, [_g, _h]);
      expect(room.hostPlayerId, _h);
      expect(room.playersById[_g]!.slotNumber, 1);
      expect(room.playersById[_h]!.slotNumber, 2);

      expect(tester.getTopLeft(_row(_g)).dy,
          lessThan(tester.getTopLeft(_row(_h)).dy));
      expect(find.text('Jugador 1'), findsOneWidget);
      expect(find.text('Jugador 2 (Tú)'), findsOneWidget);
    },
  );

  testWidgets('client lobby has no admin drag handle', (tester) async {
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
    expect(find.byKey(const Key('lobby-reorder-drag')), findsNothing);
    expect(find.byType(ReorderableDragStartListener), findsNothing);
    expect(find.byIcon(Icons.drag_handle), findsNothing);
  });
}
