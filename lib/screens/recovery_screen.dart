import 'package:flutter/material.dart';

import '../recovery/recovery_models.dart';
import '../recovery/recovery_service.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({
    super.key,
    required this.service,
    required this.initialInspection,
    required this.onRetry,
    required this.onRestore,
    this.technicalCode,
  });

  final RecoveryService service;
  final RecoveryInspection initialInspection;
  final Future<void> Function() onRetry;
  final Future<void> Function(RecoveryCandidate candidate) onRestore;
  final String? technicalCode;

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  late RecoveryInspection _inspection = widget.initialInspection;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshCatalog();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Icon(
                  Icons.health_and_safety_rounded,
                  size: 60,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Режим восстановления Chronicle',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Обычный запуск остановлен, чтобы не изменить исходные '
                  'данные. Сначала экспортируйте аварийную копию, затем '
                  'выберите только проверенный вариант восстановления.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                if (widget.technicalCode != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Код этапа: ${widget.technicalCode}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 24),
                if (_inspection.candidates.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Повреждения в read-only проверке не обнаружены. '
                        'Можно повторить обычное открытие.',
                      ),
                    ),
                  )
                else
                  for (final candidate in _inspection.candidates)
                    _CandidateCard(
                      candidate: candidate,
                      busy: _busy,
                      onRestore:
                          candidate.canRestore
                              ? () => _confirmRestore(candidate)
                              : null,
                    ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : _retry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Повторить безопасную проверку'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _export,
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('Экспортировать базу и журнал'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Card(
                  child: ExpansionTile(
                    title: const Text('Инструкция по восстановлению'),
                    leading: const Icon(Icons.menu_book_outlined),
                    childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    children: const [
                      Text(
                        '1. Экспортируйте базу и технический журнал в отдельную '
                        'папку.\n'
                        '2. Скопируйте эту папку на другой диск.\n'
                        '3. Если доступна резервная копия с подтверждёнными '
                        'контрольными суммами, проверьте её дату и выберите '
                        '«Восстановить».\n'
                        '4. Не удаляйте файлы chronicle.sqlite, -wal и -shm '
                        'вручную: они могут содержать последние изменения.\n'
                        '5. Если проверенной копии нет, сохраните экспорт и '
                        'обратитесь к разработчику — исходные файлы Chronicle '
                        'останутся нетронутыми.',
                      ),
                    ],
                  ),
                ),
                if (_busy) ...[
                  const SizedBox(height: 18),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshCatalog() async {
    try {
      final inspection = await widget.service.inspect();
      if (!mounted) return;
      setState(() => _inspection = inspection);
    } on Object {
      // The initial, already sanitized result remains visible.
    }
  }

  Future<void> _retry() async {
    setState(() => _busy = true);
    try {
      await widget.onRetry();
      if (mounted) {
        await _refreshCatalog();
      }
    } on Object {
      _showFailure('Безопасное открытие снова не удалось.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final path = await widget.service.exportRawDatabase();
      if (!mounted || path.isEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Аварийная копия сохранена: $path')),
      );
    } on Object {
      _showFailure('Не удалось экспортировать аварийную копию.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _confirmRestore(RecoveryCandidate candidate) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Восстановить проверенную копию?'),
                content: Text(
                  '${candidate.title}\n\n'
                  'Текущая SQLite будет сохранена в Recovery перед заменой.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Отмена'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Восстановить'),
                  ),
                ],
              ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.onRestore(candidate);
    } on Object {
      _showFailure(
        'Восстановление остановлено. Исходные данные и staged-маркер '
        'сохранены для следующей безопасной попытки.',
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showFailure(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.busy,
    this.onRestore,
  });

  final RecoveryCandidate candidate;
  final bool busy;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (candidate.severity) {
      RecoverySeverity.blocking => colorScheme.error,
      RecoverySeverity.warning => colorScheme.tertiary,
      RecoverySeverity.information => colorScheme.primary,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_iconFor(candidate.kind), color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(candidate.description),
                  if (candidate.modifiedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Дата: ${candidate.modifiedAt!.toLocal()}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (candidate.byteLength != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Размер: ${candidate.byteLength} байт',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            if (onRestore != null) ...[
              const SizedBox(width: 12),
              FilledButton(
                onPressed: busy ? null : onRestore,
                child: const Text('Восстановить'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

IconData _iconFor(RecoveryCandidateKind kind) => switch (kind) {
  RecoveryCandidateKind.activeDatabase => Icons.storage_rounded,
  RecoveryCandidateKind.previousDatabase => Icons.history_rounded,
  RecoveryCandidateKind.stagedRestore => Icons.pending_actions_rounded,
  RecoveryCandidateKind.automaticBackup => Icons.backup_rounded,
  RecoveryCandidateKind.emergencyBackup => Icons.emergency_rounded,
  RecoveryCandidateKind.attachmentIntegrity => Icons.attachment_rounded,
  RecoveryCandidateKind.startupFailure => Icons.error_outline_rounded,
};
