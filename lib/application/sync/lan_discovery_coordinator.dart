import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../reliability/reliability_models.dart';
import '../../sync/lan_auto_sync_models.dart';
import '../../sync/lan_auto_sync_service.dart';
import '../../sync/lan_auto_sync_transport.dart';
import '../../sync/lan_sync_models.dart';
import '../../sync/sync_models.dart';
import 'sync_coordinator.dart';

final class LanDiscoveryCoordinator {
  LanDiscoveryCoordinator({
    required LanAutoSyncService autoSyncService,
    required SyncCoordinator syncCoordinator,
    required bool enabled,
    required bool Function() appReady,
    required Object? Function() loadError,
    required SyncReliabilityRecorder recordReliability,
    required void Function() notifyListeners,
  }) : _autoSyncService = autoSyncService,
       _syncCoordinator = syncCoordinator,
       _enabled = enabled,
       _appReady = appReady,
       _loadError = loadError,
       _recordReliability = recordReliability,
       _notifyListeners = notifyListeners;

  final LanAutoSyncService _autoSyncService;
  final SyncCoordinator _syncCoordinator;
  final bool _enabled;
  final bool Function() _appReady;
  final Object? Function() _loadError;
  final SyncReliabilityRecorder _recordReliability;
  final void Function() _notifyListeners;

  final Map<String, LanDiscoveredPeer> _peers = <String, LanDiscoveredPeer>{};
  final Map<String, DateTime> _lastAutoSyncAttempt = <String, DateTime>{};
  final Map<String, String> _peerErrors = <String, String>{};
  Timer? _presenceTimer;
  LanAutoSyncNode? _node;
  StreamSubscription<LanDiscoveredPeer>? _peerSubscription;
  StreamSubscription<LanSyncReport>? _hostReportSubscription;

  bool discoveryActive = false;
  String discoveryStatus = 'Обнаружение ещё не запущено';
  String? autoSyncError;
  bool get running => _node != null;

  bool isPeerOnline(String deviceId) {
    final peer = _peers[deviceId];
    return peer != null && peer.isOnlineAt(DateTime.now());
  }

  String? peerEndpoint(String deviceId) => _peers[deviceId]?.endpoint;

  String? peerError(String deviceId) => _peerErrors[deviceId];

  Future<void> handleAppResumed() async {
    if (!_enabled || _loadError() != null || !_appReady()) {
      return;
    }
    final node = _node;
    if (node == null) {
      await restart();
      return;
    }
    await node.announceNow();
  }

  Future<void> refreshDiscovery() async {
    final node = _node;
    if (node == null) {
      await restart();
      return;
    }
    discoveryStatus = 'Ищем доверенные устройства…';
    autoSyncError = null;
    _notifyListeners();
    await node.announceNow();
  }

  Future<LanSyncReport> syncWithTrustedDevice(String peerDeviceId) async {
    final discovered = _peers[peerDeviceId];
    if (discovered == null || !discovered.isOnlineAt(DateTime.now())) {
      throw StateError(
        'Устройство не найдено в локальной сети. Открой Chronicle на обоих '
        'устройствах, проверь общий Wi-Fi и доступ VPN к локальной сети.',
      );
    }
    return _syncDiscoveredPeer(discovered, automatic: false);
  }

  Future<void> restart() async {
    await stop(notify: false);
    final preferences = _syncCoordinator.syncPreferences;
    final trustedDevices = _syncCoordinator.trustedDevices;
    if (!_enabled ||
        kIsWeb ||
        _loadError() != null ||
        !_appReady() ||
        !preferences.discoverOnLocalNetwork ||
        trustedDevices.isEmpty) {
      discoveryActive = false;
      discoveryStatus =
          trustedDevices.isEmpty
              ? 'Сначала подключи доверенное устройство'
              : 'Обнаружение в локальной сети выключено';
      _notifyListeners();
      return;
    }

    await _recordReliability(
      stage: ReliabilityStage.discovery,
      level: ReliabilityLevel.info,
      message: 'Запуск обнаружения доверенных устройств в локальной сети.',
    );
    try {
      final node = await _autoSyncService.start(
        incomingAutoSyncEnabled:
            () async => _syncCoordinator.syncPreferences.autoSyncEnabled,
        localNetworkOnly: preferences.localNetworkOnly,
        onRemoteApplied: (_) => _syncCoordinator.refreshAfterLanSync(),
      );
      _node = node;
      _peerSubscription = node.peers.listen(
        _rememberPeer,
        onError: (Object error) {
          autoSyncError = error.toString();
          discoveryStatus = 'Ошибка обнаружения';
          unawaited(
            _recordReliability(
              stage: ReliabilityStage.discovery,
              level: ReliabilityLevel.error,
              message: 'Ошибка потока локального обнаружения.',
              details: <String, Object?>{
                'error': SyncCoordinator.friendlyLanError(error),
              },
            ),
          );
          _notifyListeners();
        },
      );
      _hostReportSubscription = node.reports.listen((report) {
        unawaited(_syncCoordinator.refreshAfterLanSync(report: report));
      });
      _presenceTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _expirePeers(),
      );
      discoveryActive = true;
      discoveryStatus = 'Ищем доверенные устройства…';
      autoSyncError = null;
      _notifyListeners();
      await node.announceNow();
      await _recordReliability(
        stage: ReliabilityStage.discovery,
        level: ReliabilityLevel.success,
        message: 'Локальное обнаружение запущено.',
        details: const <String, Object?>{'udpPort': 45891},
      );
    } on Object catch (error) {
      discoveryActive = false;
      discoveryStatus = 'Не удалось запустить обнаружение';
      autoSyncError = SyncCoordinator.friendlyLanError(error);
      await _recordReliability(
        stage: ReliabilityStage.discovery,
        level: ReliabilityLevel.error,
        message: 'Не удалось запустить локальное обнаружение.',
        details: <String, Object?>{'error': autoSyncError},
      );
      _notifyListeners();
    }
  }

  Future<void> announceIfEnabled() async {
    if (_syncCoordinator.syncPreferences.autoSyncEnabled) {
      await _node?.announceNow();
    }
  }

  void removePeer(String deviceId) {
    _peers.remove(deviceId);
    _peerErrors.remove(deviceId);
  }

  Future<void> stop({bool notify = true}) async {
    _presenceTimer?.cancel();
    _presenceTimer = null;
    await _peerSubscription?.cancel();
    _peerSubscription = null;
    await _hostReportSubscription?.cancel();
    _hostReportSubscription = null;
    final node = _node;
    _node = null;
    if (node != null) {
      await node.close();
    }
    _peers.clear();
    discoveryActive = false;
    if (notify) {
      _notifyListeners();
    }
  }

  Future<void> dispose() => stop(notify: false);

  void _rememberPeer(LanDiscoveredPeer peer) {
    final trusted = _syncCoordinator.trustedDevices.where(
      (device) => device.deviceId == peer.peer.deviceId && device.isActive,
    );
    if (trusted.isEmpty) {
      return;
    }
    final previous = _peers[peer.peer.deviceId];
    final now = DateTime.now();
    final wasOnline = previous?.isOnlineAt(now) ?? false;
    final endpointChanged = previous?.endpoint != peer.endpoint;
    _peers[peer.peer.deviceId] = peer;
    _peerErrors.remove(peer.peer.deviceId);
    discoveryStatus = 'Доверенное устройство найдено';
    if (!wasOnline || endpointChanged) {
      unawaited(
        _recordReliability(
          stage: ReliabilityStage.discovery,
          level: ReliabilityLevel.success,
          message: 'Доверенное устройство обнаружено в локальной сети.',
          peerDeviceId: peer.peer.deviceId,
          details: <String, Object?>{'endpoint': peer.endpoint},
        ),
      );
      _notifyListeners();
    }
    _maybeAutoSync(peer);
  }

  void _maybeAutoSync(LanDiscoveredPeer peer) {
    if (!_syncCoordinator.syncPreferences.autoSyncEnabled ||
        _syncCoordinator.lanSyncBusy) {
      return;
    }
    final identity = _syncCoordinator.deviceIdentity;
    if (identity == null ||
        identity.deviceId.compareTo(peer.peer.deviceId) >= 0) {
      return;
    }
    TrustedDevice? trusted;
    for (final device in _syncCoordinator.trustedDevices) {
      if (device.deviceId == peer.peer.deviceId) {
        trusted = device;
        break;
      }
    }
    if (trusted == null || !trusted.autoSyncEnabled) {
      return;
    }
    final now = DateTime.now();
    final lastAttempt = _lastAutoSyncAttempt[peer.peer.deviceId];
    if (lastAttempt != null &&
        now.difference(lastAttempt) < const Duration(seconds: 20)) {
      return;
    }
    _lastAutoSyncAttempt[peer.peer.deviceId] = now;
    unawaited(_runAutomaticSync(peer));
  }

  Future<void> _runAutomaticSync(LanDiscoveredPeer peer) async {
    try {
      await _syncDiscoveredPeer(peer, automatic: true);
    } on Object {
      // Later discovery announcements drive bounded automatic retries.
    }
  }

  Future<LanSyncReport> _syncDiscoveredPeer(
    LanDiscoveredPeer peer, {
    required bool automatic,
  }) async {
    if (_syncCoordinator.lanSyncBusy) {
      throw StateError('Синхронизация уже выполняется.');
    }
    final node = _node;
    if (node == null) {
      throw StateError('Обнаружение в локальной сети ещё не запущено.');
    }

    _syncCoordinator.lanSyncBusy = true;
    _syncCoordinator.lanSyncPeerDeviceId = peer.peer.deviceId;
    autoSyncError = null;
    _peerErrors.remove(peer.peer.deviceId);
    discoveryStatus =
        automatic ? 'Автоматическая синхронизация…' : 'Синхронизация…';
    _notifyListeners();
    await _recordReliability(
      stage: ReliabilityStage.connection,
      level: ReliabilityLevel.info,
      message:
          automatic
              ? 'Запущена автоматическая LAN-синхронизация.'
              : 'Запущена LAN-синхронизация без QR-кода.',
      peerDeviceId: peer.peer.deviceId,
      details: <String, Object?>{'endpoint': peer.endpoint},
    );
    try {
      final report = await _autoSyncService.syncWithDiscoveredPeer(
        node: node,
        discoveredPeer: peer,
        onRemoteApplied: (_) => _syncCoordinator.refreshAfterLanSync(),
      );
      await _syncCoordinator.refreshAfterLanSync(report: report);
      discoveryStatus = 'Синхронизация завершена';
      await _syncCoordinator.recordSyncSuccess(
        report,
        peerDeviceId: peer.peer.deviceId,
        automatic: automatic,
      );
      return report;
    } on Object catch (error) {
      final message = SyncCoordinator.friendlyLanError(error);
      autoSyncError = message;
      _peerErrors[peer.peer.deviceId] = message;
      discoveryStatus = 'Синхронизация не выполнена';
      await _recordReliability(
        stage: ReliabilityStage.connection,
        level: ReliabilityLevel.error,
        message:
            automatic
                ? 'Автоматическая LAN-синхронизация не выполнена.'
                : 'LAN-синхронизация без QR-кода не выполнена.',
        peerDeviceId: peer.peer.deviceId,
        details: <String, Object?>{'endpoint': peer.endpoint, 'error': message},
      );
      rethrow;
    } finally {
      _syncCoordinator.lanSyncBusy = false;
      _syncCoordinator.lanSyncPeerDeviceId = null;
      _notifyListeners();
    }
  }

  void _expirePeers() {
    final now = DateTime.now();
    final before = _peers.length;
    _peers.removeWhere(
      (_, peer) =>
          now.difference(peer.lastSeenAt) > const Duration(seconds: 20),
    );
    if (_peers.length != before) {
      discoveryStatus =
          _peers.isEmpty
              ? 'Доверенные устройства не найдены'
              : 'Доверенное устройство найдено';
      _notifyListeners();
    }
  }
}
