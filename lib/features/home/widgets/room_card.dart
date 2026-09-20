import 'package:flutter/material.dart';

import '../../../core/catalogs/color_catalog.dart';
import '../../../core/models/discovered_room.dart';

/// Null/blank/unknown `hostColorId` → Naranja `color_5` (`#FB8C00`).
Color resolveHostCardColor(String? hostColorId) {
  final id = hostColorId?.trim();
  if (id == null || id.isEmpty) {
    return ColorCatalog.byId('color_5')!.color;
  }
  return ColorCatalog.byId(id)?.color ?? ColorCatalog.byId('color_5')!.color;
}

/// Host-colored Partidas card with `Reanudar` when resumable.
class RoomCard extends StatelessWidget {
  const RoomCard({
    super.key,
    required this.room,
    this.onTap,
  });

  final DiscoveredRoom room;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fill = resolveHostCardColor(room.hostColorId);
    final onFill = ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Card(
      key: ValueKey('room-${room.roomId}'),
      color: fill,
      child: ListTile(
        title: Text(
          room.displayName,
          style: TextStyle(color: onFill),
        ),
        trailing: room.isResumable
            ? Chip(
                label: Text('Reanudar', style: TextStyle(color: onFill)),
                visualDensity: VisualDensity.compact,
                backgroundColor: fill,
                side: BorderSide(color: onFill),
              )
            : Icon(Icons.chevron_right, color: onFill),
        onTap: onTap,
      ),
    );
  }
}
