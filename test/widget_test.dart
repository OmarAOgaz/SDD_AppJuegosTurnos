import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turnos_juegos/app/app.dart';
import 'package:turnos_juegos/core/models/discovered_room.dart';
import 'package:turnos_juegos/core/network/discovery/mdns_browser.dart';
import 'package:turnos_juegos/core/network/manual_endpoint_store.dart';
import 'package:turnos_juegos/core/providers/network_providers.dart';

class _FakeMdnsBrowser extends MdnsBrowser {
  @override
  Future<void> start() async {}

  @override
  Stream<List<DiscoveredRoom>> get roomsStream => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('TurnosApp renders home', (tester) async {
    final store = await ManualEndpointStore.create();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mdnsBrowserProvider.overrideWith((ref) => _FakeMdnsBrowser()),
          manualEndpointStoreProvider.overrideWith((ref) async => store),
        ],
        child: const TurnosApp(),
      ),
    );
    await tester.pump();
    expect(find.text('Turnos Juegos de mesa'), findsOneWidget);
  });
}
