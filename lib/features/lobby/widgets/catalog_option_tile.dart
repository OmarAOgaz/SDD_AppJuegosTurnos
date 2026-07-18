import 'package:flutter/material.dart';

import '../../../core/domain/eligible_picker.dart';

/// Selectable catalog row. Taken options stay visible, struck through,
/// disabled, and announced unavailable (spec: accessible option sheets).
class CatalogOptionTile extends StatelessWidget {
  const CatalogOptionTile({
    super.key,
    required this.option,
    required this.label,
    required this.onSelected,
    this.leading,
    this.isSelected = false,
    this.interactionEnabled = true,
  });

  final PickerOption option;
  final String label;
  final VoidCallback onSelected;
  final Widget? leading;
  final bool isSelected;

  /// When false, the tile is non-interactive even if the option is free
  /// (e.g. sound preview pending lock). Taken options stay non-interactive.
  final bool interactionEnabled;

  static const double minTouchTarget = 48;

  @override
  Widget build(BuildContext context) {
    final isTaken = option.isTaken;
    final isInteractive = interactionEnabled && !isTaken;
    return Semantics(
      container: true,
      label: isTaken ? '$label, no disponible' : label,
      button: true,
      enabled: isInteractive,
      selected: isSelected,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minTouchTarget),
          child: ListTile(
            leading: leading,
            title: Text(
              label,
              style: isTaken
                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                  : null,
            ),
            trailing: isSelected ? const Icon(Icons.check) : null,
            enabled: isInteractive,
            onTap: isInteractive ? onSelected : null,
          ),
        ),
      ),
    );
  }
}
