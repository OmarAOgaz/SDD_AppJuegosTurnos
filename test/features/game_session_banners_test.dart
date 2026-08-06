import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/catalogs/color_catalog.dart';
import 'package:turnos_juegos/core/domain/game_session_banner_texts.dart';
import 'package:turnos_juegos/core/models/player.dart';
import 'package:turnos_juegos/features/game/widgets/game_session_banners.dart';

Player _player({
  required String id,
  required String name,
  required String colorId,
}) {
  return Player(
    playerId: id,
    displayName: name,
    colorId: colorId,
    soundId: 's1',
    deviceId: 'd-$id',
    connected: false,
  );
}

void main() {
  testWidgets('shows reconnect and peer disconnect banners', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameSessionBanners(
            texts: GameSessionBannerTexts(
              reconnectMessage: GameSessionBannerTexts.localReconnectMessage,
              disconnectedPeers: [
                _player(id: 'p2', name: 'Luis', colorId: 'color_2'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(gameSessionReconnectBannerKey), findsOneWidget);
    expect(find.byKey(gameSessionPeerDisconnectBannerKey), findsOneWidget);
    expect(find.text(GameSessionBannerTexts.localReconnectMessage), findsOneWidget);
    expect(find.textContaining('Luis'), findsOneWidget);
    expect(find.textContaining('sin conexión'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('peer name uses seat color in rich text', (tester) async {
    const colorId = 'color_3';
    final seatColor = ColorCatalog.byId(colorId)!.color;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameSessionBanners(
            texts: GameSessionBannerTexts(
              disconnectedPeers: [
                _player(id: 'p1', name: 'Ana', colorId: colorId),
              ],
            ),
            onDismissPeerBanner: () {},
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.byKey(gameSessionPeerDisconnectTextKey));
    expect(text.textSpan, isNotNull);

    TextSpan? findSpan(InlineSpan span, String label) {
      if (span is TextSpan) {
        if (span.text == label) {
          return span;
        }
        for (final child in span.children ?? const <InlineSpan>[]) {
          final match = findSpan(child, label);
          if (match != null) {
            return match;
          }
        }
      }
      return null;
    }

    final anaSpan = findSpan(text.textSpan!, 'Ana');
    expect(anaSpan, isNotNull);
    expect(anaSpan!.style?.color, seatColor);
  });

  testWidgets('dismiss button hides peer banner via callback', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameSessionBanners(
            texts: GameSessionBannerTexts(
              disconnectedPeers: [
                _player(id: 'p2', name: 'Luis', colorId: 'color_1'),
              ],
            ),
            onDismissPeerBanner: () => dismissed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(gameSessionPeerDismissButtonKey));
    await tester.pump();
    expect(dismissed, isTrue);
  });

  testWidgets('swipe dismisses peer banner', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameSessionBanners(
            texts: GameSessionBannerTexts(
              disconnectedPeers: [
                _player(id: 'p2', name: 'Luis', colorId: 'color_1'),
              ],
            ),
            onDismissPeerBanner: () => dismissed = true,
          ),
        ),
      ),
    );

    await tester.drag(
      find.byKey(gameSessionPeerDisconnectBannerKey),
      const Offset(400, 0),
    );
    await tester.pumpAndSettle();
    expect(dismissed, isTrue);
  });

  testWidgets('renders nothing when texts empty', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GameSessionBanners(
            texts: GameSessionBannerTexts(),
          ),
        ),
      ),
    );

    expect(find.byKey(gameSessionReconnectBannerKey), findsNothing);
    expect(find.byKey(gameSessionPeerDisconnectBannerKey), findsNothing);
  });
}
