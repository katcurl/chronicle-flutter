import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/app_store.dart';
import '../sync/pairing_models.dart';
import '../sync/pairing_transport.dart';
import '../sync/sync_models.dart';

class PairingHostScreen extends StatefulWidget {
  const PairingHostScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<PairingHostScreen> createState() => _PairingHostScreenState();
}

class _PairingHostScreenState extends State<PairingHostScreen> {
  PairingHostSession? session;
  PairingIncomingRequest? incoming;
  StreamSubscription<PairingIncomingRequest>? requestSubscription;
  Timer? countdownTimer;
  String? selectedAddress;
  Object? error;
  bool starting = true;
  bool approving = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final value = await widget.store.pairingService.startHost();
      if (!mounted) {
        await value.close();
        return;
      }
      session = value;
      selectedAddress = value.addresses.first;
      requestSubscription = value.requests.listen((request) {
        if (mounted) {
          setState(() => incoming = request);
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
    requestSubscription?.cancel();
    unawaited(session?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Показать QR-код')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: _body(),
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
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (error != null || session == null || selectedAddress == null) {
      return _ErrorCard(
        message: '$error',
        onRetry: () {
          setState(() {
            starting = true;
            error = null;
          });
          _start();
        },
      );
    }

    final value = session!;
    final offer = value.offerFor(selectedAddress!);
    final request = incoming;
    final remaining = offer.expiresAt.difference(DateTime.now());
    final expired = remaining.isNegative;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Text(
                  request == null
                      ? 'Сканируй этот код телефоном'
                      : 'Запрос получен',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Оба устройства должны быть подключены к одной Wi‑Fi-сети. '
                  'При запросе Windows разреши Chronicle доступ к частным сетям.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                if (request == null) ...[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: QrImageView(
                        data: offer.encode(),
                        size: 260,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (value.addresses.length > 1)
                    DropdownButtonFormField<String>(
                      initialValue: selectedAddress,
                      decoration: const InputDecoration(
                        labelText: 'Адрес компьютера в локальной сети',
                      ),
                      items: value.addresses
                          .map(
                            (address) => DropdownMenuItem(
                              value: address,
                              child: Text(address),
                            ),
                          )
                          .toList(growable: false),
                      onChanged:
                          expired
                              ? null
                              : (address) {
                                if (address != null) {
                                  setState(() => selectedAddress = address);
                                }
                              },
                    ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        expired
                            ? Icons.timer_off_outlined
                            : Icons.timer_outlined,
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
                  const SizedBox(height: 10),
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
                                  content: Text('Код сопряжения скопирован'),
                                ),
                              );
                            },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Скопировать код вручную'),
                  ),
                ] else
                  _IncomingRequestCard(
                    request: request,
                    approving: approving,
                    onApprove: _approve,
                    onDeny: _deny,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _SecurityNotice(),
      ],
    );
  }

  Future<void> _approve() async {
    final request = incoming;
    final host = session;
    if (request == null || host == null || approving) {
      return;
    }
    setState(() => approving = true);
    try {
      await host.approve(request.requestId);
      await widget.store.refreshSyncFoundation();
    } on Object catch (caught) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось подтвердить: $caught')),
      );
    } finally {
      if (mounted) {
        setState(() => approving = false);
      }
    }
  }

  Future<void> _deny() async {
    final request = incoming;
    final host = session;
    if (request == null || host == null) {
      return;
    }
    await host.deny(request.requestId);
  }
}

class _IncomingRequestCard extends StatelessWidget {
  const _IncomingRequestCard({
    required this.request,
    required this.approving,
    required this.onApprove,
    required this.onDeny,
  });

  final PairingIncomingRequest request;
  final bool approving;
  final VoidCallback onApprove;
  final VoidCallback onDeny;

  @override
  Widget build(BuildContext context) {
    final completed = request.state == PairingRequestState.completed;
    final approved = request.state == PairingRequestState.approved;
    final denied = request.state == PairingRequestState.denied;

    return Column(
      children: [
        CircleAvatar(
          radius: 34,
          child: Icon(_platformIcon(request.peer.platform), size: 34),
        ),
        const SizedBox(height: 12),
        Text(
          request.peer.displayName,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '${platformDisplayName(request.peer.platform)} · ID ${request.peer.shortId}',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Text(
          completed
              ? 'Устройство подключено'
              : denied
              ? 'Запрос отклонён'
              : approved
              ? 'Подтверждено. Ждём завершения на телефоне…'
              : 'Сравни код с кодом на телефоне',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        SelectableText(
          _formatCode(request.confirmationCode),
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 5,
          ),
        ),
        const SizedBox(height: 18),
        if (request.state == PairingRequestState.pending)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton(
                onPressed: approving ? null : onDeny,
                child: const Text('Отклонить'),
              ),
              FilledButton.icon(
                onPressed: approving ? null : onApprove,
                icon:
                    approving
                        ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.verified_user_outlined),
                label: const Text('Коды совпадают'),
              ),
            ],
          )
        else if (completed)
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Готово'),
          ),
      ],
    );
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
          Icon(Icons.lock_outline_rounded, color: colors.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'QR-код одноразовый и действует пять минут. Chronicle проверяет '
              'Ed25519-подписи обоих устройств и сохраняет только открытый ключ '
              'связанного устройства.',
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
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 14),
            Text(
              'Не удалось запустить сопряжение',
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

String _formatCode(String value) {
  if (value.length != 6) {
    return value;
  }
  return '${value.substring(0, 3)} ${value.substring(3)}';
}

IconData _platformIcon(String platform) {
  return switch (platform.toLowerCase()) {
    'android' || 'ios' => Icons.smartphone_rounded,
    'windows' || 'linux' || 'macos' => Icons.computer_rounded,
    _ => Icons.devices_rounded,
  };
}
