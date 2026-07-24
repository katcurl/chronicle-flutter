import 'dart:io';

class LanIpv4Candidate {
  const LanIpv4Candidate({required this.address, required this.interfaceName});

  final String address;
  final String interfaceName;
}

Future<List<String>> localLanIpv4Addresses({
  bool localNetworkOnly = true,
}) async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
    includeLinkLocal: true,
  );
  final candidates = <LanIpv4Candidate>[];
  for (final interface in interfaces) {
    if (localNetworkOnly && _interfaceRank(interface.name) >= 4) {
      continue;
    }
    for (final address in interface.addresses) {
      if (!address.isLoopback &&
          address.type == InternetAddressType.IPv4 &&
          (!localNetworkOnly || isLocalOnlyIpv4(address.address))) {
        candidates.add(
          LanIpv4Candidate(
            address: address.address,
            interfaceName: interface.name,
          ),
        );
      }
    }
  }
  return orderLanIpv4Candidates(candidates);
}

bool isLocalOnlyIpv4(String value) {
  if (value.startsWith('10.') ||
      value.startsWith('192.168.') ||
      value.startsWith('169.254.')) {
    return true;
  }
  final parts = value.split('.');
  if (parts.length != 4 || parts.first != '172') {
    return false;
  }
  final second = int.tryParse(parts[1]);
  return second != null && second >= 16 && second <= 31;
}

List<String> orderLanIpv4Candidates(Iterable<LanIpv4Candidate> candidates) {
  final sorted =
      candidates.toList()..sort((left, right) {
        final interfaceRank = _interfaceRank(
          left.interfaceName,
        ).compareTo(_interfaceRank(right.interfaceName));
        if (interfaceRank != 0) {
          return interfaceRank;
        }
        final addressRank = _addressRank(
          left.address,
        ).compareTo(_addressRank(right.address));
        return addressRank != 0
            ? addressRank
            : left.address.compareTo(right.address);
      });
  return sorted.map((candidate) => candidate.address).toSet().toList();
}

int _interfaceRank(String value) {
  final name = value.toLowerCase();
  const virtualMarkers = <String>[
    'vpn',
    'tun',
    'tap',
    'wireguard',
    'wsl',
    'vethernet',
    'virtualbox',
    'vmware',
    'hyper-v',
    'docker',
    'tailscale',
    'zerotier',
    'hiddify',
  ];
  if (virtualMarkers.any(name.contains)) {
    return 4;
  }
  if (name.contains('wi-fi') ||
      name.contains('wifi') ||
      name.contains('wlan')) {
    return 0;
  }
  if (name.contains('ethernet') || name == 'eth0' || name.startsWith('en')) {
    return 1;
  }
  return 2;
}

int _addressRank(String value) {
  if (value.startsWith('192.168.')) {
    return 0;
  }
  if (value.startsWith('10.')) {
    return 1;
  }
  final parts = value.split('.');
  if (parts.length == 4 && parts.first == '172') {
    final second = int.tryParse(parts[1]) ?? 0;
    if (second >= 16 && second <= 31) {
      return 2;
    }
  }
  return 3;
}
