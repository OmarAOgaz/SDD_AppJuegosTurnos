import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../lifecycle/client_sync_state.dart';
import '../models/ws_envelope.dart';
import '../network/device_id_store.dart';
import '../network/discovery/mdns_browser.dart';
import '../network/game_socket_client.dart';
import '../network/manual_endpoint_store.dart';
import '../network/room_list_merger.dart';
import '../../server/host_room_controller.dart';

final hostRoomControllerProvider = Provider<HostRoomController>((ref) {
  final controller = HostRoomController();
  ref.onDispose(controller.dispose);
  return controller;
});

final manualEndpointStoreProvider = FutureProvider<ManualEndpointStore>((ref) {
  return ManualEndpointStore.create();
});

final deviceIdProvider = FutureProvider<String>((ref) async {
  final store = await DeviceIdStore.create();
  return store.getOrCreate();
});

final mdnsBrowserProvider = Provider<MdnsBrowser>((ref) {
  final browser = MdnsBrowser();
  ref.onDispose(browser.dispose);
  return browser;
});

final roomListMergerProvider = Provider<RoomListMerger>((ref) {
  return const RoomListMerger();
});

final gameSocketClientProvider = Provider<GameSocketClient?>((ref) {
  final deviceId = ref.watch(deviceIdProvider).valueOrNull;
  if (deviceId == null) {
    return null;
  }

  final link = ref.keepAlive();
  final client = GameSocketClient(deviceId: deviceId);
  ref.onDispose(() {
    client.dispose();
    link.close();
  });
  return client;
});

class ClientSyncNotifier extends StateNotifier<ClientSyncState> {
  ClientSyncNotifier() : super(const ClientSyncState());

  void onPaused() {
    state = state.onBackground();
  }

  void onResumed() {
    state = state.onForeground();
  }

  void applyEnvelope(WsEnvelope envelope) {
    state = state.applyEnvelope(envelope);
  }

  void reset() {
    state = const ClientSyncState();
  }
}

final clientSyncProvider =
    StateNotifierProvider<ClientSyncNotifier, ClientSyncState>((ref) {
  return ClientSyncNotifier();
});
