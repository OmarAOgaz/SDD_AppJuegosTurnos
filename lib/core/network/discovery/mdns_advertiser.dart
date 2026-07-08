import 'dart:io';

import 'package:bonsoir/bonsoir.dart';

import '../../constants/network_constants.dart';

/// Advertises a host room on the LAN via Bonsoir mDNS.
class MdnsAdvertiser {
  BonsoirBroadcast? _broadcast;

  bool get isAdvertising => _broadcast != null;

  Future<void> start({
    required String roomId,
    required String displayName,
    required int port,
  }) async {
    if (!kEnableMdns) {
      return;
    }

    await stop();

    final service = BonsoirService(
      name: '${displayName}_${roomId.substring(0, 8)}',
      type: kMdnsServiceType,
      port: port,
      attributes: {
        'roomId': roomId,
        'displayName': displayName,
        'port': port.toString(),
      },
    );

    _broadcast = BonsoirBroadcast(service: service);
    await _broadcast!.initialize();
    await _broadcast!.start();
  }

  Future<void> stop() async {
    final broadcast = _broadcast;
    _broadcast = null;
    if (broadcast != null) {
      await broadcast.stop();
    }
  }
}

/// Resolves the first non-loopback IPv4 address for manual connect hints.
Future<String?> findLanIPv4() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLinkLocal: false,
  );

  for (final interface in interfaces) {
    for (final address in interface.addresses) {
      if (!address.isLoopback && !address.isLinkLocal) {
        return address.address;
      }
    }
  }
  return null;
}
