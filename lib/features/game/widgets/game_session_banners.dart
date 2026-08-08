import 'package:flutter/material.dart';

import '../../../core/catalogs/color_catalog.dart';
import '../../../core/domain/game_session_banner_texts.dart';
import '../../../core/models/player.dart';

/// Finder for the local reconnect banner row in widget tests.
@visibleForTesting
const gameSessionReconnectBannerKey = Key('gameSessionReconnectBanner');

/// Finder for the peer disconnect banner row in widget tests.
@visibleForTesting
const gameSessionPeerDisconnectBannerKey = Key('gameSessionPeerDisconnectBanner');

/// Dismiss control on the peer-disconnect banner.
@visibleForTesting
const gameSessionPeerDisconnectTextKey = Key('gameSessionPeerDisconnectText');

/// Dismiss control on the peer-disconnect banner.
@visibleForTesting
const gameSessionPeerDismissButtonKey = Key('gameSessionPeerDismissButton');

/// In-game status strip for local reconnect and peer disconnect notices.
class GameSessionBanners extends StatelessWidget {
  const GameSessionBanners({
    super.key,
    required this.texts,
    this.onDismissPeerBanner,
  });

  final GameSessionBannerTexts texts;
  final VoidCallback? onDismissPeerBanner;

  @override
  Widget build(BuildContext context) {
    if (texts.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Material(
      elevation: 1,
      color: theme.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (texts.reconnectMessage != null)
              _BannerRow(
                key: gameSessionReconnectBannerKey,
                icon: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
                message: Text(texts.reconnectMessage!),
              ),
            if (texts.disconnectedPeers.isNotEmpty)
              _DismissiblePeerBanner(
                key: gameSessionPeerDisconnectBannerKey,
                peers: texts.disconnectedPeers,
                onDismiss: onDismissPeerBanner,
              ),
          ],
        ),
      ),
    );
  }
}

class _DismissiblePeerBanner extends StatelessWidget {
  const _DismissiblePeerBanner({
    super.key,
    required this.peers,
    required this.onDismiss,
  });

  final List<Player> peers;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final row = _PeerDisconnectBannerRow(
      peers: peers,
      onDismiss: onDismiss,
    );
    if (onDismiss == null) {
      return row;
    }
    return Dismissible(
      key: ValueKey(
        'peerDisconnect:${GameSessionBannerTexts.disconnectedPeersKey(peers)}',
      ),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => onDismiss!(),
      child: row,
    );
  }
}

class _PeerDisconnectBannerRow extends StatelessWidget {
  const _PeerDisconnectBannerRow({
    required this.peers,
    required this.onDismiss,
  });

  final List<Player> peers;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.portable_wifi_off_outlined,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PeerDisconnectRichText(peers: peers),
          ),
          if (onDismiss != null)
            IconButton(
              key: gameSessionPeerDismissButtonKey,
              icon: const Icon(Icons.close),
              tooltip: 'Cerrar',
              onPressed: onDismiss,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _PeerDisconnectRichText extends StatelessWidget {
  const _PeerDisconnectRichText({required this.peers});

  final List<Player> peers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: _buildSpans(baseStyle),
      ),
      key: gameSessionPeerDisconnectTextKey,
    );
  }

  List<InlineSpan> _buildSpans(TextStyle? baseStyle) {
    final spans = <InlineSpan>[];
    for (var i = 0; i < peers.length; i++) {
      if (i > 0) {
        if (i == peers.length - 1) {
          spans.add(TextSpan(text: ' y ', style: baseStyle));
        } else {
          spans.add(TextSpan(text: ', ', style: baseStyle));
        }
      }
      final player = peers[i];
      final seatColor = ColorCatalog.byId(player.colorId)?.color;
      spans.add(
        TextSpan(
          text: GameSessionBannerTexts.playerLabel(player),
          style: baseStyle?.copyWith(
            color: seatColor ?? baseStyle.color,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    spans.add(TextSpan(text: ' sin conexión', style: baseStyle));
    return spans;
  }
}

class _BannerRow extends StatelessWidget {
  const _BannerRow({
    super.key,
    required this.icon,
    required this.message,
  });

  final Widget icon;
  final Widget message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 12),
          Expanded(child: message),
        ],
      ),
    );
  }
}
