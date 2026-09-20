import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turnos_juegos/core/constants/network_constants.dart';
import 'package:turnos_juegos/core/models/discovered_room.dart';
import 'package:turnos_juegos/core/models/game_room.dart';
import 'package:turnos_juegos/core/models/local_player_profile.dart';
import 'package:turnos_juegos/core/models/player.dart';
import 'package:turnos_juegos/core/network/discovery/mdns_browser.dart';
import 'package:turnos_juegos/core/network/game_resume_store.dart';
import 'package:turnos_juegos/core/providers/network_providers.dart';
import 'package:turnos_juegos/core/providers/profile_providers.dart';
import 'package:turnos_juegos/features/home/home_screen.dart';
import 'package:turnos_juegos/server/host_room_controller.dart';

class _FakeMdns extends MdnsBrowser {
  _FakeMdns([this.rooms = const []]);
  final List<DiscoveredRoom> rooms;
  final _c = StreamController<List<DiscoveredRoom>>.broadcast();
  @override
  Stream<List<DiscoveredRoom>> get roomsStream => _c.stream;
  @override
  Future<void> start() async => _c.add(rooms);
  @override
  void dispose() => unawaited(_c.close());
}

class _FakeHost extends HostRoomController {
  GameRoom? started;
  var calls = 0;
  @override
  GameRoom? get room => started;
  @override
  Future<GameRoom> startRoom({
    String? displayName,
    required String hostDeviceId,
    LocalPlayerProfile? profile,
  }) async {
    calls++;
    started = GameRoom(
      roomId: 'hosted-1',
      displayName: displayName ?? 'Sala',
      hostPlayerId: 'host-1',
      slots: ['host-1'],
      playersById: {
        'host-1': Player(
          playerId: 'host-1',
          displayName: 'Jugador',
          colorId: 'color_1',
          soundId: 'sound_1',
          deviceId: hostDeviceId,
        ),
      },
    );
    return started!;
  }
}

class _FixedProfile extends LocalPlayerProfileNotifier {
  @override
  Future<LocalPlayerProfile> build() async => LocalPlayerProfile.defaults();
}

DiscoveredRoom _r(String id, String name, String? color,
    {String host = '10.0.0.1', int port = 8080}) {
  return DiscoveredRoom(
      roomId: id,
      displayName: name,
      hostIp: host,
      port: port,
      hostColorId: color);
}

Widget _app({
  MdnsBrowser? browser,
  HostRoomController? host,
  GameResumeStore? store,
}) {
  return ProviderScope(
    overrides: [
      mdnsBrowserProvider.overrideWith((ref) => browser ?? _FakeMdns()),
      hostRoomControllerProvider.overrideWith((ref) => host ?? _FakeHost()),
      deviceIdProvider.overrideWith((ref) async => 'device-test'),
      localPlayerProfileProvider.overrideWith(_FixedProfile.new),
      if (store != null)
        gameResumeStoreProvider.overrideWith((ref) async => store),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: '/lobby',
            builder: (_, s) => Scaffold(
              body: Text('seated-lobby-${s.uri.queryParameters['role'] ?? ''}'),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _pumpHome(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Crear partida seats the user as host', (tester) async {
    final host = _FakeHost();
    await _pumpHome(tester, _app(host: host));
    await tester.tap(find.text('Crear partida'));
    await tester.pumpAndSettle();
    expect(host.calls, 1);
    expect(host.started?.hostPlayerId, 'host-1');
    expect(find.text('seated-lobby-host'), findsOneWidget);
  });

  testWidgets('empty Partidas has no manual IP control', (tester) async {
    await _pumpHome(tester, _app());
    expect(find.text('Crear partida'), findsOneWidget);
    expect(find.text('Partidas'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(find.text('Add manual IP'), findsNothing);
  });

  testWidgets('resumable room is listed first', (tester) async {
    final store = GameResumeStore(await SharedPreferences.getInstance());
    await store.save(
      const GameResumeEntry(
        roomId: 'resume-room',
        playerId: 'p1',
        deviceId: 'd1',
        host: '10.0.0.9',
        port: 9,
      ),
    );
    await _pumpHome(
      tester,
      _app(
        browser: _FakeMdns([
          _r('other-room', 'Alpha', 'color_2'),
          _r('resume-room', 'Zulu', 'color_1', host: '10.0.0.9', port: 9),
        ]),
        store: store,
      ),
    );
    final cards = tester.widgetList<Card>(find.byType(Card)).toList();
    expect(cards.first.key, const ValueKey('room-resume-room'));
    expect(find.text('Reanudar'), findsOneWidget);
  });

  testWidgets('color_2 fill vs unknown Naranja still tappable', (tester) async {
    await _pumpHome(
      tester,
      _app(
        browser: _FakeMdns([
          _r('blue', 'Azul host', 'color_2'),
          _r('mystery', 'Mystery', 'not-a-color'),
        ]),
      ),
    );
    expect(
      tester.widget<Card>(find.byKey(const ValueKey('room-blue'))).color,
      const Color(0xFF1E88E5),
    );
    expect(
      tester.widget<Card>(find.byKey(const ValueKey('room-mystery'))).color,
      const Color(0xFFFB8C00),
    );
    await tester.tap(find.byKey(const ValueKey('room-mystery')));
    await tester.pumpAndSettle();
    expect(find.text('seated-lobby-client'), findsOneWidget);
  });

  testWidgets('kEnableMdns false: no browse and Partidas empty', (tester) async {
    debugMdnsEnabledOverride = false;
    addTearDown(() => debugMdnsEnabledOverride = null);
    final browser = MdnsBrowser();
    addTearDown(browser.dispose);

    await _pumpHome(
      tester,
      _app(
        browser: browser,
      ),
    );
    await tester.pumpAndSettle();

    expect(browser.isBrowsing, isFalse);
    expect(browser.currentRooms, isEmpty);
    expect(find.text('Partidas'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
  });
}
