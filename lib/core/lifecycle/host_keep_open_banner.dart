import 'package:flutter/material.dart';

/// iOS host policy banner — keep app open during IN_GAME.
class HostKeepOpenBanner {
  HostKeepOpenBanner._();

  static MaterialBanner materialBanner({
    required VoidCallback onDismiss,
  }) {
    return MaterialBanner(
      content: const Text(
        'En iPhone, mantén la app abierta mientras seas host de la partida.',
      ),
      leading: const Icon(Icons.info_outline),
      actions: [
        TextButton(
          onPressed: onDismiss,
          child: const Text('OK'),
        ),
      ],
    );
  }
}
