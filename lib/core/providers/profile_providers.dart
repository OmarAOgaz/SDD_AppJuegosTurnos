import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/local_player_profile.dart';
import '../repositories/player_profile_repository.dart';

final playerProfileRepositoryProvider =
    FutureProvider<PlayerProfileRepository>((ref) async {
  return PlayerProfileRepository.create();
});

final localPlayerProfileProvider =
    AsyncNotifierProvider<LocalPlayerProfileNotifier, LocalPlayerProfile>(
  LocalPlayerProfileNotifier.new,
);

class LocalPlayerProfileNotifier extends AsyncNotifier<LocalPlayerProfile> {
  @override
  Future<LocalPlayerProfile> build() async {
    final repository = await ref.watch(playerProfileRepositoryProvider.future);
    return repository.load();
  }

  Future<void> save(LocalPlayerProfile profile) async {
    final repository = await ref.read(playerProfileRepositoryProvider.future);
    await repository.save(profile);
    state = AsyncData(profile);
  }
}
