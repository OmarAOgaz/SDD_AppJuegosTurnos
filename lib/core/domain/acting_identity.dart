import '../models/player.dart';

/// Who this device is acting as for cue, warning, overtime, ripple, and sound.
///
/// Implicit proxy: the acting host controls a disconnected active seat.
/// [isActingAs] is never true for the host's own seat ([isOwn] wins).
class ActingIdentity {
  const ActingIdentity({
    required this.isOwn,
    required this.isActingAs,
    this.colorId,
    this.soundId,
  });

  /// Local seat is the active player.
  final bool isOwn;

  /// Host is passing for a disconnected active seat that is not local.
  final bool isActingAs;

  /// Palette for cue / warning / overtime / ripple / sound.
  final String? colorId;
  final String? soundId;

  /// This device should treat the turn as locally actionable.
  bool get isDeviceActing => isOwn || isActingAs;
}

/// Resolves [ActingIdentity] from local seat, current host, and active seat.
///
/// Color/sound come from the acted-as seat while [ActingIdentity.isActingAs];
/// otherwise from the local seat.
ActingIdentity resolveActingIdentity({
  required String? localPlayerId,
  required String? hostPlayerId,
  required Player? localPlayer,
  required Player? activePlayer,
}) {
  final isOwn = localPlayerId != null &&
      activePlayer != null &&
      localPlayerId == activePlayer.playerId;
  final isActingAs = localPlayerId != null &&
      localPlayerId == hostPlayerId &&
      activePlayer != null &&
      !activePlayer.connected &&
      !isOwn;
  final palette = isActingAs ? activePlayer : localPlayer;
  return ActingIdentity(
    isOwn: isOwn,
    isActingAs: isActingAs,
    colorId: palette?.colorId,
    soundId: palette?.soundId,
  );
}
