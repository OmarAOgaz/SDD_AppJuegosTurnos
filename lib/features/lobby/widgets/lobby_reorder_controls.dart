import 'package:flutter/material.dart';

/// Host-only up/down arrows + dedicated drag handle (gesture-isolated).
class LobbyReorderControls extends StatelessWidget {
  const LobbyReorderControls({
    super.key,
    required this.index,
    required this.itemCount,
    this.onMoveUp,
    this.onMoveDown,
  });

  final int index;
  final int itemCount;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  bool get _canUp => index > 0;
  bool get _canDown => index < itemCount - 1;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: Key('lobby-reorder-up-$index'),
          tooltip: 'Subir',
          icon: const Icon(Icons.keyboard_arrow_up),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: _canUp ? onMoveUp : null,
        ),
        IconButton(
          key: Key('lobby-reorder-down-$index'),
          tooltip: 'Bajar',
          icon: const Icon(Icons.keyboard_arrow_down),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: _canDown ? onMoveDown : null,
        ),
        ReorderableDragStartListener(
          index: index,
          child: Semantics(
            label: 'Arrastrar para reordenar',
            button: true,
            child: const SizedBox(
              key: Key('lobby-reorder-drag'),
              width: 48,
              height: 48,
              child: Icon(Icons.drag_handle),
            ),
          ),
        ),
      ],
    );
  }
}
