import 'package:flutter/material.dart';

import '../../../core/audio/sound_preview_service.dart';
import '../../../core/catalogs/sound_catalog.dart';
import '../../../core/domain/eligible_picker.dart';
import 'catalog_option_tile.dart';

/// Bottom sheet of all eight sounds; commits only after preview starts.
class SoundPickerSheet extends StatefulWidget {
  const SoundPickerSheet({
    super.key,
    required this.options,
    required this.currentSoundId,
    required this.previewService,
    required this.onCommitted,
  });

  final List<PickerOption> options;
  final String? currentSoundId;
  final SoundPreviewService previewService;
  final ValueChanged<String> onCommitted;

  static Future<void> show(
    BuildContext context, {
    required List<PickerOption> options,
    required String? currentSoundId,
    required SoundPreviewService previewService,
    required ValueChanged<String> onCommitted,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => SoundPickerSheet(
          options: options,
          currentSoundId: currentSoundId,
          previewService: previewService,
          onCommitted: onCommitted,
        ),
      );

  @override
  State<SoundPickerSheet> createState() => _SoundPickerSheetState();
}

class _SoundPickerSheetState extends State<SoundPickerSheet> {
  String? _errorMessage;

  Future<void> _tap(String id) async {
    setState(() => _errorMessage = null);
    final result = await widget.previewService.preview(id);
    if (!mounted) return;
    if (result is SoundPreviewStarted) {
      widget.onCommitted(id);
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      return;
    }
    if (result is! SoundPreviewFailure) return;
    if (result.error == SoundPreviewError.cancelled) {
      // Replaced by a newer tap; leave UI for the in-flight successor.
      return;
    }
    setState(() {
      _errorMessage = 'No se pudo reproducir el sonido';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          if (_errorMessage != null)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _errorMessage!,
                  key: const Key('sound-preview-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          for (final o in widget.options)
            CatalogOptionTile(
              key: Key('sound-option-${o.id}'),
              option: o,
              label: SoundCatalog.byId(o.id)?.displayName ?? o.id,
              isSelected: o.id == widget.currentSoundId,
              leading: const Icon(Icons.volume_up),
              onSelected: () => _tap(o.id),
            ),
        ],
      ),
    );
  }
}
