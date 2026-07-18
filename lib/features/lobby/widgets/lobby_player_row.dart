import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/audio/sound_preview_service.dart';
import '../../../core/catalogs/color_catalog.dart';
import '../../../core/domain/eligible_picker.dart';
import '../../../core/models/player.dart';
import 'color_picker_sheet.dart';
import 'lobby_name_field.dart';
import 'lobby_reorder_controls.dart';
import 'sound_picker_sheet.dart';

/// Shared host/client player row. Only the local connected seat is editable.
/// Host-only reorder controls render when [showHostAdminSlot] is true.
class LobbyPlayerRow extends StatelessWidget {
  const LobbyPlayerRow({
    super.key,
    required this.player,
    required this.isSelf,
    required this.showHostAdminSlot,
    this.reorderIndex = 0,
    this.reorderCount = 1,
    this.onMoveUp,
    this.onMoveDown,
    this.onNameChanged,
    this.onColorChanged,
    this.onSoundChanged,
    this.takenColorIds = const {},
    this.takenSoundIds = const {},
    this.previewService,
  });

  final Player player;
  final bool isSelf;
  final bool showHostAdminSlot;
  final int reorderIndex;
  final int reorderCount;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final ValueChanged<String>? onNameChanged;
  final ValueChanged<String>? onColorChanged;
  final ValueChanged<String>? onSoundChanged;
  final Set<String> takenColorIds;
  final Set<String> takenSoundIds;
  final SoundPreviewService? previewService;

  bool get _isEditable => isSelf && player.connected && onNameChanged != null;
  bool get _ownRowControlsVisible => isSelf && player.connected;

  @override
  Widget build(BuildContext context) {
    final background = ColorCatalog.byId(player.colorId)?.color ?? Colors.grey;
    final onBackground =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark
            ? Colors.white
            : Colors.black;

    // Color/Sound sit under the name so host admin controls (3×48) fit on
    // narrow phones without crushing the label row.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Opacity(
              opacity: player.connected ? 1 : 0.6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Jugador ${player.slotNumber}${isSelf ? " (Tú)" : ""}',
                          style: Theme.of(context).textTheme.labelLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: player.connected ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(player.connected ? 'Conectado' : 'Desconectado'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _isEditable
                        ? LobbyNameField(
                            initialName: player.displayName,
                            onChanged: onNameChanged!,
                          )
                        : Text(
                            player.displayName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: onBackground),
                          ),
                  ),
                  if (_ownRowControlsVisible) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        OutlinedButton(
                          key: const Key('lobby-color-button'),
                          onPressed: onColorChanged == null
                              ? null
                              : () => _openColorPicker(context),
                          child: const Text('Color'),
                        ),
                        IconButton(
                          key: const Key('lobby-sound-button'),
                          tooltip: 'Sonido',
                          icon: const Icon(Icons.volume_up),
                          onPressed:
                              onSoundChanged == null || previewService == null
                                  ? null
                                  : () => _openSoundPicker(context),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (showHostAdminSlot)
            LobbyReorderControls(
              key: const Key('lobby-admin-slot'),
              index: reorderIndex,
              itemCount: reorderCount,
              onMoveUp: onMoveUp,
              onMoveDown: onMoveDown,
            ),
        ],
      ),
    );
  }

  void _openColorPicker(BuildContext context) {
    unawaited(
      ColorPickerSheet.show(
        context,
        options: colorPickerOptions(
          takenColorIds: takenColorIds,
          ownColorId: player.colorId,
        ),
        currentColorId: player.colorId,
        onSelected: onColorChanged!,
      ),
    );
  }

  void _openSoundPicker(BuildContext context) {
    unawaited(
      SoundPickerSheet.show(
        context,
        options: soundPickerOptions(
          takenSoundIds: takenSoundIds,
          ownSoundId: player.soundId,
        ),
        currentSoundId: player.soundId,
        previewService: previewService!,
        onCommitted: onSoundChanged!,
      ),
    );
  }
}
