import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/features/game/ended_screen.dart';

void main() {
  testWidgets('EndedScreen shows exit to Home', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: EndedScreen()),
      ),
    );
    expect(find.text('Volver al inicio'), findsOneWidget);
  });
}
