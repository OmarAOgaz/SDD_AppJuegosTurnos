import 'package:flutter/material.dart';

/// Self-editable player name field with per-keystroke sync.
///
/// Seeds its [TextEditingController] once from [initialName] and never
/// re-reads it. Only the local device edits its own row, so any later
/// `LOBBY_STATE` echo is at best a stale ack of an already-superseded
/// value; ignoring it keeps local text/cursor authoritative while
/// [onChanged] still fires on every keystroke, no confirm step needed.
class LobbyNameField extends StatefulWidget {
  const LobbyNameField({
    super.key,
    required this.initialName,
    required this.onChanged,
  });

  final String initialName;
  final ValueChanged<String> onChanged;

  @override
  State<LobbyNameField> createState() => _LobbyNameFieldState();
}

class _LobbyNameFieldState extends State<LobbyNameField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: 'Nombre',
      ),
      onChanged: widget.onChanged,
    );
  }
}
