import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/app_store.dart';
import '../sync/lan_sync_models.dart';
import '../sync/lan_sync_transport.dart';
import '../sync/sync_models.dart';
import '../widgets/desktop_navigation.dart';

class SyncHostScreen extends StatefulWidget {
  const SyncHostScreen({super.key, required this.store, required this.device});

  final AppStore store;
  final TrustedDevice device;

  @override
  State<SyncHostScreen> createState() => _SyncHostScreenState();
}

class _SyncHostScreenState extends State<SyncHostScreen> {
  LanSyncHostSession? session;
  StreamSubscription<LanSyncReport>? reportSubscription;
  Timer? countdownTimer;
  String? selectedAddress;
  LanSyncReport? report;
  Object? error;
  bool starting = true;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final value = await widget.store.startLanSyncHost(widget.device.deviceId);
      if (!mounted) {
        await value.close();
        return;
      }
      session = value;
      selectedAddress = value.addresses.first;
      reportSubscription = value.reports.listen((event) async {
        report = report == null ? event : report!.merge(event);
        await widget.store.refreshAfterLanSync(report: report);
        if (mounted) {
          setState(() {});
        }
      });
      countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {});
        }
      });
    } on Object catch (caught) {
      error = caught;
    } finally {
      if (mounted) {
        setState(() => starting = false);
      }
    }
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    reportSubscription?.cancel();
    unawaited(session?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EscapeToClose(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Синхронизация · ${widget.device.displayName}'),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(child: EscapeKeyHint()),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 660),
                child: _body(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (starting) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(34),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final value = session;
    final address = selectedAddress;
    if (error != null || value == null || address == null) {
      return _ErrorCard(
        message: '$error',
        onRetry: () async {
          await session?.close();
          reportSubscription?.cancel();
          countdownTimer?.cancel();
          setState(() {
            starting = true;
            error = null;
            session = null;
            report = null;
          });
          await _start();
        },
      );
    }

    final currentReport = report;
    if (currentReport != null && !currentReport.hasMore) {
      return _SuccessCard(report: currentReport);
    }

    final offer = value.offerFor(address);
    final remaining = offer.expiresAt.difference(DateTime.now());
    final expired = remaining.isNegative;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  currentReport == null
                      ? 'Отсканируй код на связанном устройстве'
                      : 'Передаём следующие пакеты…',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Код подходит только для ${widget.device.displayName}. '
                  'Оба устройства должны быть в одной локальной сети.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: QrImageView(
                      data: offer.encode(),
                      size: 270,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
                  ),
                ),
                if (value.addresses.length > 1) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedAddress,
                    decoration: const InputDecoration(
                      labelText: 'Адрес компьютера в локальной сети',
                    ),
                    items: value.addresses
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(growable: false),
                    onChanged:
                        expired
                            ? null
                            : (item) {
                              if (item != null) {
                                setState(() => selectedAddress = item);
                              }
                            },
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      expired ? Icons.timer_off_outlined : Icons.timer_outlined,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      expired
                          ? 'Код истёк — открой экран заново'
                          : 'Действует ещё ${_durationText(remaining)}',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed:
                      expired
                          ? null
                          : () async {
                            await Clipboard.setData(
                              ClipboardData(text: offer.encode()),
                            );
                            if (!mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Код синхронизации скопирован'),
                              ),
                            );
                          },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Скопировать код вручную'),
                ),
                if (currentReport != null) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 10),
                  Text(
                    'Передано: ${currentReport.sentCount} · '
                    'получено: ${currentReport.receivedCount}',
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _SecurityNotice(),
      ],
    );
  }
}

class _SuccessCard extends StatelessWidget {
  const _SuccessCard({required this.report});

  final LanSyncReport report;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Icon(Icons.sync_rounded, size: 64, color: colors.primary),
            const SizedBox(height: 16),
            Text(
              'Синхронизация завершена',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              report.appliedCount == 0
                  ? 'Оба устройства уже были синхронизированы.'
                  : 'Новые данные применены и сохранены локально.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _Metric(label: 'Передано', value: report.sentCount),
                _Metric(label: 'Получено', value: report.receivedCount),
                _Metric(label: 'Применено', value: report.appliedCount),
                _Metric(label: 'Пакетов', value: report.roundCount),
              ],
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Готово'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}

class _SecurityNotice extends StatelessWidget {
  const _SecurityNotice();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: colors.onSecondaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Каждый пакет подписывается ключом устройства. Chronicle '
              'принимает данные только от уже связанного устройства и '
              'повторно проверяет его открытый ключ.',
              style: TextStyle(color: colors.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          children: [
            Icon(
              Icons.sync_problem_rounded,
              size: 54,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 14),
            Text(
              'Не удалось начать синхронизацию',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

String _durationText(Duration duration) {
  final seconds = duration.inSeconds.clamp(0, 5999);
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  return '$minutes:${rest.toString().padLeft(2, '0')}';
}
