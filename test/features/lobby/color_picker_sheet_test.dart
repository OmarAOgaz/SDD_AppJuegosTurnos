import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:turnos_juegos/core/catalogs/color_catalog.dart';
import 'package:turnos_juegos/core/domain/eligible_picker.dart';
import 'package:turnos_juegos/features/lobby/widgets/color_picker_sheet.dart';

void main() {
  testWidgets(
    'all colors visible; taken struck/disabled/announced; free selectable; >=48dp',
    (tester) async {
      final handle = tester.ensureSemantics();
      var selected = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColorPickerSheet(
              options: colorPickerOptions(
                takenColorIds: const {'color_1'},
                ownColorId: 'color_2',
              ),
              currentColorId: 'color_2',
              onSelected: (id) => selected = id,
            ),
          ),
        ),
      );

      for (final color in ColorCatalog.all) {
        expect(find.text(color.displayName), findsOneWidget);
        expect(
          tester.getSize(find.byKey(Key('color-option-${color.id}'))).height,
          greaterThanOrEqualTo(48),
        );
      }
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('color-option-color_1')),
                matching: find.text('Rojo'),
              ),
            )
            .style
            ?.decoration,
        TextDecoration.lineThrough,
      );
      expect(find.bySemanticsLabel('Rojo, no disponible'), findsOneWidget);

      await tester.tap(find.byKey(const Key('color-option-color_1')));
      await tester.pump();
      expect(selected, isEmpty);

      await tester.tap(find.byKey(const Key('color-option-color_3')));
      await tester.pump();
      expect(selected, 'color_3');
      handle.dispose();
    },
  );
}
