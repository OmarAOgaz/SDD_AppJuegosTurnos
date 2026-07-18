import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:turnos_juegos/features/lobby/widgets/lobby_name_field.dart';

Widget _wrap(String initialName, ValueChanged<String> onChanged) {
  return MaterialApp(
    home: Scaffold(
      body: LobbyNameField(initialName: initialName, onChanged: onChanged),
    ),
  );
}

void main() {
  testWidgets(
    'sends an update per keystroke without resending the initial value',
    (tester) async {
      final sent = <String>[];
      await tester.pumpWidget(_wrap('Ana', sent.add));
      expect(sent, isEmpty);

      await tester.enterText(find.byType(TextField), 'Anab');
      expect(sent, ['Anab']);
      expect(find.text('Anab'), findsOneWidget);
    },
  );

  testWidgets(
    'ignores a later stale echo and keeps the freshest local text',
    (tester) async {
      final sent = <String>[];
      await tester.pumpWidget(_wrap('A', sent.add));

      await tester.enterText(find.byType(TextField), 'An');
      await tester.enterText(find.byType(TextField), 'Ana');
      expect(sent, ['An', 'Ana']);

      // A stale echo of an older keystroke ("An") rebuilds this widget with
      // an outdated `initialName`; it must not revert local text/cursor.
      await tester.pumpWidget(_wrap('An', sent.add));
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('An'), findsNothing);
    },
  );
}
