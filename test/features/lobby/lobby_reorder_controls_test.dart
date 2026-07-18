import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/features/lobby/widgets/lobby_reorder_controls.dart';

void main() {
  Future<void> pump(WidgetTester t, int index, int count,
      {VoidCallback? up, VoidCallback? down}) {
    return t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReorderableListView(
          onReorderItem: (_, __) {},
          buildDefaultDragHandles: false,
          children: [
            for (var i = 0; i < count; i++)
              ListTile(
                key: ValueKey(i),
                title: Text('$i'),
                trailing: i == index
                    ? LobbyReorderControls(
                        index: index,
                        itemCount: count,
                        onMoveUp: up,
                        onMoveDown: down,
                      )
                    : null,
              ),
          ],
        ),
      ),
    ));
  }

  testWidgets('edge arrows disabled; drag handle accessible', (tester) async {
    var up = 0, down = 0;
    await pump(tester, 0, 3, up: () => up++, down: () => down++);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('lobby-reorder-up-0')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('lobby-reorder-down-0')));
    expect(down, 1);
    await pump(tester, 2, 3, up: () => up++, down: () => down++);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('lobby-reorder-down-2')))
          .onPressed,
      isNull,
    );
    final size = tester.getSize(find.byKey(const Key('lobby-reorder-drag')));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(find.byType(ReorderableDragStartListener), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle), findsOneWidget);
  });
}
