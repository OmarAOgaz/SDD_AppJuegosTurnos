/// Network and discovery constants for LAN multiplayer.
library;

const bool kEnableMdns = true;
const bool kEnableForegroundService = true;

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
