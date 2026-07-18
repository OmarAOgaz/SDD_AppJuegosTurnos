import 'package:flutter/material.dart';

import '../../../core/catalogs/color_catalog.dart';
import '../../../core/domain/eligible_picker.dart';
import 'catalog_option_tile.dart';

/// Bottom sheet of all eight colors; taken ones stay visible and disabled.
class ColorPickerSheet extends StatelessWidget {
  const ColorPickerSheet({
    super.key,
    required this.options,
    required this.currentColorId,
    required this.onSelected,
  });

  final List<PickerOption> options;
  final String? currentColorId;
  final ValueChanged<String> onSelected;

  static Future<void> show(
    BuildContext context, {
    required List<PickerOption> options,
    required String? currentColorId,
    required ValueChanged<String> onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (_) => ColorPickerSheet(
        options: options,
        currentColorId: currentColorId,
        onSelected: onSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final option in options)
            CatalogOptionTile(
              key: Key('color-option-${option.id}'),
              option: option,
              label: ColorCatalog.byId(option.id)?.displayName ?? option.id,
              isSelected: option.id == currentColorId,
              leading: CircleAvatar(
                backgroundColor: ColorCatalog.byId(option.id)?.color,
              ),
              onSelected: () {
                onSelected(option.id);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }
}
