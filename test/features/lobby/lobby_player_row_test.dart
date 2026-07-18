import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:turnos_juegos/core/models/player.dart';
import 'package:turnos_juegos/features/lobby/widgets/lobby_player_row.dart';

Player _player({String displayName = 'Ana', bool connected = true}) {
  return Player(
    playerId: 'p1',
    displayName: displayName,
    colorId: 'color_1',
    soundId: 'sound_1',
    deviceId: 'device-1',
    slotNumber: 1,
    connected: connected,
  );
}

Future<void> _pump(
  WidgetTester tester,
  Player player, {
  required bool isSelf,
  required bool showHostAdminSlot,
  ValueChanged<String>? onNameChanged,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LobbyPlayerRow(
          player: player,
          isSelf: isSelf,
          showHostAdminSlot: showHostAdminSlot,
          onNameChanged: onNameChanged,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'host and client share row structure; admin slot is host-only',
    (tester) async {
      final player = _player();

      await _pump(tester, player, isSelf: false, showHostAdminSlot: true);
      expect(find.text('Jugador 1'), findsOneWidget);
      expect(find.text('Conectado'), findsOneWidget);
      expect(find.byKey(const Key('lobby-admin-slot')), findsOneWidget);

      await _pump(tester, player, isSelf: false, showHostAdminSlot: false);
      expect(find.byKey(const Key('lobby-admin-slot')), findsNothing);
    },
  );

  testWidgets('own connected row is editable', (tester) async {
    var changed = '';
    await _pump(
      tester,
      _player(),
      isSelf: true,
      showHostAdminSlot: false,
      onNameChanged: (value) => changed = value,
    );
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Ana2');
    expect(changed, 'Ana2');
  });

  testWidgets('another player row is read-only', (tester) async {
    await _pump(
      tester,
      _player(),
      isSelf: false,
      showHostAdminSlot: false,
      onNameChanged: (_) => fail('non-self row must not be editable'),
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('a disconnected self row disables editing', (tester) async {
    await _pump(
      tester,
      _player(connected: false),
      isSelf: true,
      showHostAdminSlot: false,
      onNameChanged: (_) => fail('disconnected row must not be editable'),
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Desconectado'), findsOneWidget);
  });
}
