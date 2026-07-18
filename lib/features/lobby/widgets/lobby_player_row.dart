import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/audio/sound_preview_service.dart';
import '../../../core/catalogs/color_catalog.dart';
import '../../../core/domain/eligible_picker.dart';
import '../../../core/models/player.dart';
import 'color_picker_sheet.dart';
import 'lobby_name_field.dart';
import 'sound_picker_sheet.dart';

/// Single player row shared by host and client lobby views.
///
/// Same structure for both roles; only the local, connected player's row
/// is editable. The trailing admin slot is host-only and disabled here
/// (reorder lands in a later slice); it is absent for clients.
class LobbyPlayerRow extends StatelessWidget {
  const LobbyPlayerRow({
    super.key,
    required this.player,
    required this.isSelf,
    required this.showHostAdminSlot,
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
                      Text(
                        'Jugador ${player.slotNumber}${isSelf ? " (Tú)" : ""}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const Spacer(),
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
            const IconButton(
              key: Key('lobby-admin-slot'),
              icon: Icon(Icons.drag_handle),
              tooltip: 'Reordenar (próximamente)',
              onPressed: null,
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
