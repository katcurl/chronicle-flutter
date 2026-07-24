import 'pairing_crypto.dart';
import 'pairing_models.dart';

class PairingHostSession {
  PairingHostSession._();

  static Future<PairingHostSession> start({
    required LocalPairingIdentity local,
    required PairingCrypto crypto,
    required Future<void> Function(PairingPeer peer) onTrust,
    bool localNetworkOnly = true,
  }) {
    throw UnsupportedError(
      'QR-сопряжение доступно в нативных Android и desktop-сборках.',
    );
  }

  List<String> get addresses => const [];
  Stream<PairingIncomingRequest> get requests => const Stream.empty();
  PairingOffer offerFor(String address) => throw UnsupportedError('');
  Future<void> approve(String requestId) => throw UnsupportedError('');
  Future<void> deny(String requestId) => throw UnsupportedError('');
  Future<void> close() async {}
}

class PairingClientSession {
  PairingClientSession._();

  static Future<PairingClientSession> start({
    required PairingOffer offer,
    required LocalPairingIdentity local,
    required PairingCrypto crypto,
    bool localNetworkOnly = true,
  }) {
    throw UnsupportedError('QR-сопряжение доступно в нативной Android-сборке.');
  }

  PairingPendingResponse get pending => throw UnsupportedError('');
  Future<PairingClientResult> waitForApproval() => throw UnsupportedError('');
  Future<void> complete() async {}
  Future<void> close() async {}
}
