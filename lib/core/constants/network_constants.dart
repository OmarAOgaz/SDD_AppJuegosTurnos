/// Network and discovery constants for LAN multiplayer.
library;

const bool kEnableMdns = true;
const bool kEnableForegroundService = true;

const String kMdnsServiceType = '_turnos._tcp';
const String kWsPath = '/ws';

const int kHeartbeatIntervalMs = 3000;
const int kHeartbeatTimeoutMs = 8000;
const int kReconnectWindowMs = 30000;

const int kGameStateStubVersion = 1;
