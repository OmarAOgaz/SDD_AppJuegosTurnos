import 'package:flutter/material.dart';

/// iOS host policy banner — keep app open during IN_GAME.
class HostKeepOpenBanner extends StatelessWidget {
  const HostKeepOpenBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      content: const Text(
        'En iPhone, mantén la app abierta mientras seas host de la partida.',
      ),
      leading: const Icon(Icons.info_outline),
      actions: [
        TextButton(
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
