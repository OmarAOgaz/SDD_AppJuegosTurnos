import 'dart:async';

import 'package:bonsoir/bonsoir.dart';

import '../../constants/network_constants.dart';
import '../../domain/room_discovery.dart';
import '../../models/discovered_room.dart';

/// Browses `_turnos._tcp` services and emits resolved [DiscoveredRoom] entries.
class MdnsBrowser {
  MdnsBrowser();

  BonsoirDiscovery? _discovery;
  final StreamController<List<DiscoveredRoom>> _roomsController =
      StreamController<List<DiscoveredRoom>>.broadcast();

  final Map<String, DiscoveredRoom> _roomsById = {};
  final Map<String, String> _serviceKeyToRoomId = {};

  Stream<List<DiscoveredRoom>> get roomsStream => _roomsController.stream;

  List<DiscoveredRoom> get currentRooms => List.unmodifiable(_roomsById.values);

  bool get isBrowsing => _discovery != null;

  Future<void> start() async {
    if (!kEnableMdns) {
      _emit();
      return;
    }

    await stop();

    _discovery = BonsoirDiscovery(
      type: kMdnsServiceType,
    );
    await _discovery!.initialize();

    _discovery!.eventStream!.listen(_onDiscoveryEvent);
    await _discovery!.start();
  }

  Future<void> stop() async {
    final discovery = _discovery;
    _discovery = null;
    if (discovery != null) {
      await discovery.stop();
    }
  }

  void dispose() {
    unawaited(stop());
    unawaited(_roomsController.close());
  }

  void _onDiscoveryEvent(BonsoirDiscoveryEvent event) {
    if (event is BonsoirDiscoveryServiceFoundEvent) {
      event.service.resolve(_discovery!.serviceResolver);
      return;
    }

    if (event is BonsoirDiscoveryServiceResolvedEvent) {
      final room = _mapService(event.service);
      if (room != null) {
        _roomsById[room.roomId] = room;
        _serviceKeyToRoomId[mdnsServiceKey(
          name: event.service.name,
          type: event.service.type,
        )] = room.roomId;
        _emit();
      }
      return;
    }

    if (event is BonsoirDiscoveryServiceLostEvent) {
      removeRoomsLostWithService(
        roomsById: _roomsById,
        serviceKeyToRoomId: _serviceKeyToRoomId,
        serviceName: event.service.name,
        serviceType: event.service.type,
        roomIdFromAttributes: event.service.attributes['roomId'],
        lostHostIp: _resolveHostIp(event.service),
        lostPort: event.service.port,
      );
      _emit();
    }
  }

  DiscoveredRoom? _mapService(BonsoirService service) {
    return mapMdnsTxtToDiscoveredRoom(
      attributes: service.attributes,
      hostIp: _resolveHostIp(service),
      servicePort: service.port,
      serviceName: service.name,
    );
  }

  String? _resolveHostIp(BonsoirService service) {
    final host = service.hostAddress;
    if (host != null && host.isNotEmpty && !host.endsWith('.local')) {
      return host;
    }

    for (final address in service.hostAddresses) {
      if (address.isNotEmpty && !address.endsWith('.local')) {
        return address;
      }
    }

    final hostname = service.hostname;
    if (hostname != null && hostname.isNotEmpty && !hostname.endsWith('.local')) {
      return hostname;
    }

    return null;
  }

  void _emit() {
    if (!_roomsController.isClosed) {
      _roomsController.add(currentRooms);
    }
  }
}
