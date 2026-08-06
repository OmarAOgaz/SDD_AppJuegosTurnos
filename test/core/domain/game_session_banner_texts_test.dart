import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/domain/game_session_banner_texts.dart';
import 'package:turnos_juegos/core/models/player.dart';

Player _player({
  required String id,
  required String name,
  required bool connected,
  String colorId = 'color_1',
}) {
  return Player(
    playerId: id,
    displayName: name,
    colorId: colorId,
    soundId: 's1',
    deviceId: 'd-$id',
    connected: connected,
  );
}

void main() {
  group('GameSessionBannerTexts.resolve', () {
    test('local reconnect only', () {
      final texts = GameSessionBannerTexts.resolve(
        showLocalReconnect: true,
        seatedPlayers: [
          _player(id: 'p1', name: 'Ana', connected: true),
        ],
        localPlayerId: 'p2',
      );
      expect(texts.reconnectMessage, GameSessionBannerTexts.localReconnectMessage);
      expect(texts.disconnectedPeers, isEmpty);
    });

    test('single peer disconnect returns player entry', () {
      final luis = _player(id: 'p2', name: 'Luis', connected: false);
      final texts = GameSessionBannerTexts.resolve(
        showLocalReconnect: false,
        seatedPlayers: [
          _player(id: 'p1', name: 'Ana', connected: true),
          luis,
        ],
      );
      expect(texts.reconnectMessage, isNull);
      expect(texts.disconnectedPeers, [luis]);
    });

    test('two peers disconnect', () {
      final texts = GameSessionBannerTexts.resolve(
        showLocalReconnect: false,
        seatedPlayers: [
          _player(id: 'p1', name: 'Ana', connected: false),
          _player(id: 'p2', name: 'Luis', connected: false),
        ],
      );
      expect(texts.disconnectedPeers, hasLength(2));
    });

    test('many peers disconnect lists each player', () {
      final texts = GameSessionBannerTexts.resolve(
        showLocalReconnect: false,
        seatedPlayers: [
          _player(id: 'p1', name: 'A', connected: false),
          _player(id: 'p2', name: 'B', connected: false),
          _player(id: 'p3', name: 'C', connected: false),
        ],
      );
      expect(texts.disconnectedPeers, hasLength(3));
    });

    test('excludes local seat from peer banner while reconnecting', () {
      final texts = GameSessionBannerTexts.resolve(
        showLocalReconnect: true,
        seatedPlayers: [
          _player(id: 'p1', name: 'Host', connected: true),
          _player(id: 'p2', name: 'Yo', connected: false),
        ],
        localPlayerId: 'p2',
        excludeLocalFromPeerDisconnect: true,
      );
      expect(texts.reconnectMessage, isNotNull);
      expect(texts.disconnectedPeers, isEmpty);
    });
  });

  group('GameSessionBannerTexts.disconnectedPeersKey', () {
    test('stable for same ids regardless of order', () {
      final a = _player(id: 'p2', name: 'B', connected: false);
      final b = _player(id: 'p1', name: 'A', connected: false);
      expect(
        GameSessionBannerTexts.disconnectedPeersKey([a, b]),
        GameSessionBannerTexts.disconnectedPeersKey([b, a]),
      );
    });
  });
}
