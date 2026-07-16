import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/app_store.dart';
import '../sync/lan_sync_models.dart';
import '../sync/sync_models.dart';
import '../widgets/desktop_navigation.dart';

class SyncScanScreen extends StatefulWidget {
  const SyncScanScreen({super.key, required this.store, required this.device});

  final AppStore store;
  final TrustedDevice device;

  @override
  State<SyncScanScreen> createState() => _SyncScanScreenState();
}

enum _SyncScanStage { scanning, syncing, success, error }

class _SyncScanScreenState extends State<SyncScanScreen> {
  final MobileScannerController controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  _SyncScanStage stage = _SyncScanStage.scanning;
  LanSyncReport? report;
  String? errorMessage;
  bool handlingCode = false;

  @override
  void dispose() {
    unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EscapeToClose(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Синхронизация · ${widget.device.displayName}'),
          actions: [
            if (stage == _SyncScanStage.scanning)
              IconButton(
                tooltip: 'Ввести код вручную',
                onPressed: _manualEntry,
                icon: const Icon(Icons.keyboard_alt_outlined),
              ),
          ],
        ),
        body: SafeArea(child: _body()),
      ),
    );
  }

  Widget _body() {
    return switch (stage) {
      _SyncScanStage.scanning => _scanner(),
      _SyncScanStage.syncing => _progressView(),
      _SyncScanStage.success => _successView(),
      _SyncScanStage.error => _errorView(),
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
              _sync(raw);
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
                  Text(
                    'Открой синхронизацию с ${widget.device.displayName} '
                    'на компьютере и наведи камеру на QR-код.',
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

  Widget _progressView() {
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
                  const Icon(Icons.sync_rounded, size: 56),
                  const SizedBox(height: 18),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 18),
                  Text(
                    'Синхронизируем данные',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Chronicle передаёт журнал небольшими пакетами, проверяет '
                    'подписи и применяет только новые изменения.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _successView() {
    final value = report!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Синхронизация завершена',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value.appliedCount == 0
                        ? 'Новых изменений не было.'
                        : 'Новые данные применены и сохранены.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      Chip(label: Text('Передано: ${value.sentCount}')),
                      Chip(label: Text('Получено: ${value.receivedCount}')),
                      Chip(label: Text('Применено: ${value.appliedCount}')),
                      Chip(label: Text('Пакетов: ${value.roundCount}')),
                    ],
                  ),
                  if (value.duplicateCount > 0 || value.staleCount > 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Пропущено повторов: ${value.duplicateCount}, '
                      'устаревших версий: ${value.staleCount}.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 22),
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
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sync_problem_rounded,
                    size: 56,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Не удалось синхронизировать',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
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

  Future<void> _sync(String raw) async {
    if (handlingCode) {
      return;
    }
    handlingCode = true;
    await controller.stop();
    if (mounted) {
      setState(() {
        stage = _SyncScanStage.syncing;
        errorMessage = null;
      });
    }
    try {
      final value = await widget.store.syncFromLanOffer(
        raw,
        expectedPeerDeviceId: widget.device.deviceId,
      );
      if (mounted) {
        setState(() {
          report = value;
          stage = _SyncScanStage.success;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          errorMessage = '$error';
          stage = _SyncScanStage.error;
        });
      }
    } finally {
      handlingCode = false;
    }
  }

  Future<void> _manualEntry() async {
    final textController = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Код синхронизации'),
            content: TextField(
              controller: textController,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(hintText: 'chronicle://sync/…'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.pop(dialogContext, textController.text),
                child: const Text('Синхронизировать'),
              ),
            ],
          ),
    );
    textController.dispose();
    if (value != null && value.trim().isNotEmpty) {
      await _sync(value);
    }
  }

  Future<void> _reset() async {
    report = null;
    errorMessage = null;
    handlingCode = false;
    if (mounted) {
      setState(() => stage = _SyncScanStage.scanning);
      await controller.start();
    }
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
