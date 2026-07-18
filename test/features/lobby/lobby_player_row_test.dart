import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:turnos_juegos/core/models/player.dart';
import 'package:turnos_juegos/features/lobby/widgets/color_picker_sheet.dart';
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
  ValueChanged<String>? onColorChanged,
  Set<String> takenColorIds = const {},
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LobbyPlayerRow(
          player: player,
          isSelf: isSelf,
          showHostAdminSlot: showHostAdminSlot,
          onNameChanged: onNameChanged,
          onColorChanged: onColorChanged,
          takenColorIds: takenColorIds,
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
      onColorChanged: (_) => fail('disconnected row must not open color'),
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const Key('lobby-color-button')), findsNothing);
    expect(find.text('Desconectado'), findsOneWidget);
  });

  testWidgets('Color control only on own connected row', (tester) async {
    final color = find.byKey(const Key('lobby-color-button'));
    await _pump(
      tester,
      _player(),
      isSelf: true,
      showHostAdminSlot: false,
      onColorChanged: (_) {},
    );
    expect(color, findsOneWidget);

    await _pump(tester, _player(), isSelf: false, showHostAdminSlot: false);
    expect(color, findsNothing);

    await _pump(
      tester,
      _player(connected: false),
      isSelf: true,
      showHostAdminSlot: false,
      onColorChanged: (_) {},
    );
    expect(color, findsNothing);
  });

  testWidgets('Color opens sheet and reports selection', (tester) async {
    var newColorId = '';
    await _pump(
      tester,
      _player(),
      isSelf: true,
      showHostAdminSlot: false,
      takenColorIds: const {'color_2'},
      onColorChanged: (value) => newColorId = value,
    );
    await tester.tap(find.byKey(const Key('lobby-color-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('color-option-color_3')));
    await tester.pumpAndSettle();
    expect(newColorId, 'color_3');
    expect(find.byType(ColorPickerSheet), findsNothing);
  });
}
