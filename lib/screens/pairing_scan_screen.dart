import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/app_store.dart';
import '../sync/pairing_models.dart';
import '../sync/pairing_transport.dart';
import '../sync/sync_models.dart';

class PairingScanScreen extends StatefulWidget {
  const PairingScanScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<PairingScanScreen> createState() => _PairingScanScreenState();
}

enum _ScanStage { scanning, connecting, waiting, success, error }

class _PairingScanScreenState extends State<PairingScanScreen> {
  final MobileScannerController controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  PairingClientSession? clientSession;
  PairingPendingResponse? pending;
  PairingPeer? connectedPeer;
  _ScanStage stage = _ScanStage.scanning;
  String? errorMessage;
  bool handlingCode = false;

  @override
  void dispose() {
    unawaited(clientSession?.close());
    unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканировать QR-код'),
        actions: [
          if (stage == _ScanStage.scanning)
            IconButton(
              tooltip: 'Ввести код вручную',
              onPressed: _manualEntry,
              icon: const Icon(Icons.keyboard_alt_outlined),
            ),
        ],
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    return switch (stage) {
      _ScanStage.scanning => _scanner(),
      _ScanStage.connecting => const _ProgressView(
        icon: Icons.wifi_find_rounded,
        title: 'Подключаемся к Chronicle Desktop',
        message: 'Телефон и компьютер должны быть в одной локальной сети.',
      ),
      _ScanStage.waiting => _waitingView(),
      _ScanStage.success => _successView(),
      _ScanStage.error => _errorView(),
    };
  }

  Widget _scanner() {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: controller,
          onDetect: (capture) {
            final raw =
                capture.barcodes
                    .map((barcode) => barcode.rawValue)
                    .whereType<String>()
                    .firstOrNull;
            if (raw != null) {
              _connect(raw);
            }
          },
          errorBuilder: (context, error) => _ScannerError(error: error),
        ),
        IgnorePointer(
          child: Center(
            child: Container(
              width: 270,
              height: 270,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 28,
          child: Card(
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.92),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Наведи камеру на QR-код в Chronicle на компьютере.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _manualEntry,
                    icon: const Icon(Icons.keyboard_alt_outlined),
                    label: const Text('Ввести скопированный код'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _waitingView() {
    final value = pending;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                children: [
                  const SizedBox.square(
                    dimension: 34,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Сравни код на обоих устройствах',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    value == null
                        ? '------'
                        : _formatCode(value.confirmationCode),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'На компьютере должен появиться тот же код. Нажми там '
                    '«Коды совпадают».',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  TextButton(onPressed: _reset, child: const Text('Отменить')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _successView() {
    final peer = connectedPeer;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_rounded,
                    size: 62,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Устройство подключено',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    peer == null
                        ? 'Chronicle сохранил доверенный ключ устройства.'
                        : '${peer.displayName} · ${platformDisplayName(peer.platform)}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Готово'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 54,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Не удалось подключить устройство',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage ?? 'Неизвестная ошибка',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Сканировать снова'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _connect(String raw) async {
    if (handlingCode) {
      return;
    }
    handlingCode = true;
    await controller.stop();
    if (mounted) {
      setState(() {
        stage = _ScanStage.connecting;
        errorMessage = null;
      });
    }
    try {
      final session = await widget.store.pairingService.startClient(raw);
      clientSession = session;
      pending = session.pending;
      if (mounted) {
        setState(() => stage = _ScanStage.waiting);
      }
      final result = await widget.store.pairingService.finishClient(session);
      connectedPeer = result.hostPeer;
      await widget.store.refreshSyncFoundation();
      if (mounted) {
        setState(() => stage = _ScanStage.success);
      }
    } on Object catch (error) {
      errorMessage = '$error';
      if (mounted) {
        setState(() => stage = _ScanStage.error);
      }
    } finally {
      handlingCode = false;
    }
  }

  Future<void> _manualEntry() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Код сопряжения'),
            content: TextField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(hintText: 'chronicle://pair/…'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, controller.text),
                child: const Text('Подключить'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (value != null && value.trim().isNotEmpty) {
      await _connect(value);
    }
  }

  Future<void> _reset() async {
    await clientSession?.close();
    clientSession = null;
    pending = null;
    connectedPeer = null;
    errorMessage = null;
    handlingCode = false;
    if (mounted) {
      setState(() => stage = _ScanStage.scanning);
    }
  }
}

class _ProgressView extends StatelessWidget {
  const _ProgressView({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54),
            const SizedBox(height: 18),
            const CircularProgressIndicator(),
            const SizedBox(height: 18),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Камера недоступна: ${error.errorCode.name}. '
          'Разреши Chronicle использовать камеру или введи код вручную.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

String _formatCode(String value) {
  if (value.length != 6) {
    return value;
  }
  return '${value.substring(0, 3)} ${value.substring(3)}';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
