import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turnos_juegos/app/app.dart';
import 'package:turnos_juegos/core/models/discovered_room.dart';
import 'package:turnos_juegos/core/network/discovery/mdns_browser.dart';
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
    SharedPreferences.setMockInitialValues({
      'manual_lan_endpoints': ['stale'],
    });
  });

  testWidgets('TurnosApp renders home', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mdnsBrowserProvider.overrideWith((ref) => _FakeMdnsBrowser()),
        ],
        child: const TurnosApp(),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Turnos Juegos de mesa'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('manual_lan_endpoints'), isFalse);

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.dark);
    expect(materialApp.theme, isNull);
    expect(materialApp.darkTheme, isNotNull);
    expect(materialApp.darkTheme!.brightness, Brightness.dark);
    expect(materialApp.darkTheme!.colorScheme.brightness, Brightness.dark);
    expect(materialApp.darkTheme!.useMaterial3, isTrue);

    final homeContext = tester.element(find.text('Turnos Juegos de mesa'));
    expect(Theme.of(homeContext).brightness, Brightness.dark);
    expect(Theme.of(homeContext).colorScheme.brightness, Brightness.dark);

    expect(find.byType(Switch), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.textContaining('theme', findRichText: true), findsNothing);
    expect(find.textContaining('Tema', findRichText: true), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
