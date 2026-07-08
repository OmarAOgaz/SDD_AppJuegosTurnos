import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/catalogs/color_catalog.dart';
import '../../core/catalogs/sound_catalog.dart';
import '../../core/models/local_player_profile.dart';
import '../../core/providers/profile_providers.dart';

/// Device-local defaults screen (Personalización).
class PersonalizeScreen extends ConsumerStatefulWidget {
  const PersonalizeScreen({
    super.key,
    this.returnHost,
    this.returnPort,
  });

  final String? returnHost;
  final int? returnPort;

  @override
  ConsumerState<PersonalizeScreen> createState() => _PersonalizeScreenState();
}

class _PersonalizeScreenState extends ConsumerState<PersonalizeScreen> {
  final _nameController = TextEditingController();
  List<String> _preferredColors = List<String>.from(
    ColorCatalog.defaultPreferredIds,
  );
  List<String> _preferredSounds = List<String>.from(
    SoundCatalog.defaultPreferredIds,
  );
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _hydrateFromProfile(LocalPlayerProfile profile) {
    if (_initialized) {
      return;
    }
    _nameController.text = profile.defaultDisplayName;
    _preferredColors = List<String>.from(profile.preferredColorIds);
    _preferredSounds = List<String>.from(profile.preferredSoundIds);
    _initialized = true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final profile = LocalPlayerProfile(
      defaultDisplayName: _nameController.text.trim(),
      preferredColorIds: _preferredColors,
      preferredSoundIds: _preferredSounds,
    );
    await ref.read(localPlayerProfileProvider.notifier).save(profile);
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preferencias guardadas')),
    );

    final host = widget.returnHost;
    final port = widget.returnPort;
    if (host != null && port != null && profile.hasUsableDisplayName) {
      context.go(
        '/spike?role=client&host=${Uri.encodeComponent(host)}&port=$port',
      );
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Widget _preferenceRow({
    required String label,
    required List<String> values,
    required List<String> catalogIds,
    required void Function(int index, String? value) onChanged,
    Widget Function(String id)? leading,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (var index = 0; index < 3; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DropdownButtonFormField<String>(
              initialValue: values[index],
              decoration: InputDecoration(
                labelText: 'Preferencia ${index + 1}',
                prefixIcon: leading != null
                    ? leading(values[index])
                    : null,
              ),
              items: catalogIds
                  .map(
                    (id) => DropdownMenuItem(
                      value: id,
                      child: Text(id),
                    ),
                  )
                  .toList(),
              onChanged: (value) => onChanged(index, value),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(localPlayerProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalización'),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (profile) {
          _hydrateFromProfile(profile);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Estos valores se usan al crear o unirte a una partida.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre para mostrar',
                  helperText:
                      'Requerido para unirte a partidas de otros hosts',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 24),
              _preferenceRow(
                label: 'Colores preferidos',
                values: _preferredColors,
                catalogIds: ColorCatalog.allIds(),
                leading: (id) {
                  final color = ColorCatalog.byId(id)?.color ?? Colors.grey;
                  return CircleAvatar(radius: 10, backgroundColor: color);
                },
                onChanged: (index, value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _preferredColors[index] = value);
                },
              ),
              const SizedBox(height: 16),
              _preferenceRow(
                label: 'Sonidos preferidos',
                values: _preferredSounds,
                catalogIds: SoundCatalog.allIds(),
                onChanged: (index, value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _preferredSounds[index] = value);
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Guardando…' : 'Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }
}
