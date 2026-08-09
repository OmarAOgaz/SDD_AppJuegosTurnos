/// Network and discovery constants for LAN multiplayer.
library;

const bool kEnableMdns = true;
const bool kEnableForegroundService = true;

/// Android FGS notification channel id (must stay stable across releases).
const String kFgsChannelId = 'turnos_active_game';

/// Role-neutral FGS notification title / channel name (ES hardcoded).
const String kFgsNotificationTitle = 'Partida activa';

/// Role-neutral FGS notification body for host and client (ES hardcoded).
const String kFgsNotificationBody =
    'Turnos Juegos de mesa — partida en LAN';

/// Role-neutral Android notification channel description (ES hardcoded).
const String kFgsChannelDescription = 'Mantiene la partida activa en LAN';

const String kMdnsServiceType = '_turnos._tcp';
const String kWsPath = '/ws';

const int kHeartbeatIntervalMs = 3000;
const int kHeartbeatTimeoutMs = 8000;
/// Client-drop reconnect window while the local LAN is down / flaky.
const int kReconnectWindowMs = 30000;
/// Host-loss grace when mDNS no longer advertises the in-progress roomId.
const int kHostLossGraceMs = 3000;
/// In-game client recovery: how often to re-probe mDNS while reconnecting.
const int kMdnsProbeIntervalMs = 3000;

const int kGameStateStubVersion = 1;
