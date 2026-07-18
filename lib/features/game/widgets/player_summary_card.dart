import 'package:flutter/material.dart';

import '../../../core/catalogs/color_catalog.dart';
import '../../../core/models/player.dart';
import '../../../core/utils/duration_format.dart';

/// Color-backed per-player stats card for the end-of-match summary.
class PlayerSummaryCard extends StatelessWidget {
  const PlayerSummaryCard({
    super.key,
    required this.player,
  });

  final Player player;

  @override
  Widget build(BuildContext context) {
    final background = ColorCatalog.byId(player.colorId)?.color ?? Colors.grey;
    final onBackground =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark
            ? Colors.white
            : Colors.black;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: onBackground,
        );
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: onBackground,
          fontWeight: FontWeight.w600,
        );
    final avgMs =
        player.turnCount > 0 ? player.totalTurnMs ~/ player.turnCount : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(player.displayName, style: titleStyle),
            const SizedBox(height: 8),
            Text('Turnos: ${player.turnCount}', style: textStyle),
            Text(
              'Tiempo total: ${formatDurationMs(player.totalTurnMs)}',
              style: textStyle,
            ),
            Text('Promedio: ${formatDurationMs(avgMs)}', style: textStyle),
            Text(
              'Tiempo excedido: ${player.exceededTurnCount} '
              '(${formatDurationMs(player.totalExceededMs)})',
              style: textStyle,
            ),
          ],
        ),
      ),
    );
  }
}
