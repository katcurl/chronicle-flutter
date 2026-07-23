import 'package:chronicle/sync/lan_address_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('physical Wi-Fi address is preferred over a VPN address', () {
    final ordered = orderLanIpv4Candidates(const <LanIpv4Candidate>[
      LanIpv4Candidate(address: '10.0.0.2', interfaceName: 'tun0'),
      LanIpv4Candidate(address: '10.0.0.24', interfaceName: 'wlan0'),
    ]);

    expect(ordered, <String>['10.0.0.24', '10.0.0.2']);
  });

  test('duplicate addresses are removed after ordering', () {
    final ordered = orderLanIpv4Candidates(const <LanIpv4Candidate>[
      LanIpv4Candidate(address: '192.168.1.5', interfaceName: 'Wi-Fi'),
      LanIpv4Candidate(address: '192.168.1.5', interfaceName: 'wlan0'),
    ]);

    expect(ordered, <String>['192.168.1.5']);
  });
}
