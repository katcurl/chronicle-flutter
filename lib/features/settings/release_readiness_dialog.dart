import 'dart:async';

import 'package:flutter/material.dart';

import '../../reliability/release_readiness.dart';
import '../../services/app_store.dart';

class ReleaseReadinessDialog extends StatefulWidget {
  const ReleaseReadinessDialog({super.key, required this.store});

  final AppStore store;

  static Future<void> show(BuildContext context, {required AppStore store}) {
    return showDialog<void>(
      context: context,
      builder: (context) => ReleaseReadinessDialog(store: store),
    );
  }

  @override
  State<ReleaseReadinessDialog> createState() =>
      _ReleaseReadinessDialogState();
}

class _ReleaseReadinessDialogState extends State<ReleaseReadinessDialog> {
  ReleaseReadinessReport? _report;
  Object? _error;
  bool _busy = true;
  bool _backupBusy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    if (mounted) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }
    try {
      final report = await widget.store.runReleaseReadinessAudit();
      if (!mounted) {
        return;
      }
      setState(() => _report = report);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _createBackup() async {
    setState(() => _backupBusy = true);
    try {
      final result = await widget.store.createInternalSafetyBackup();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == null
                ? 'Страховочная копия сейчас недоступна.'
                : 'Страховочная копия создана.',
          ),
        ),
      );
      await _run();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось создать копию: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _backupBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.verified_user_outlined),
          SizedBox(width: 12),
          Expanded(child: Text('Надёжность Chronicle 1.0')),
        ],
      ),
      content: SizedBox(
        width: 760,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 650),
          child: _busy && _report == null
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _report == null
              ? _ErrorState(error: _error!, onRetry: _run)
              : ListView(
                  shrinkWrap: true,
                  children: [
                    _OverviewBanner(report: _report!),
                    const SizedBox(height: 12),
                    _CheckCard(
                      icon: Icons.account_tree_outlined,
                      title: 'Целостность данных',
                      passed: _report!.integrity.clean,
                      subtitle:
                          '${_report!.integrity.projectCount} проектов · '
                          '${_report!.integrity.noteCount} заметок · '
                          '${_report!.integrity.taskCount} задач · '
                          '${_report!.integrity.errorCount} ошибок · '
                          '${_report!.integrity.warningCount} предупреждений',
                      child: _report!.integrity.issues.isEmpty
                          ? const Text(
                              'Повреждённых идентификаторов и обязательных '
                              'связей не найдено.',
                            )
                          : Column(
                              children: [
                                for (final issue
                                    in _report!.integrity.issues.take(12))
                                  _IntegrityIssueTile(issue: issue),
                              ],
                            ),
                    ),
                    const SizedBox(height: 10),
                    _CheckCard(
                      icon: Icons.import_export_rounded,
                      title: 'Обратимый импорт и экспорт',
                      passed: _report!.backupRoundTrip.valid,
                      subtitle:
                          'JSON v${_report!.backupRoundTrip.formatVersion} · '
                          '${_report!.backupRoundTrip.noteCount} заметок',
                      child: Text(_report!.backupRoundTrip.message),
                    ),
                    const SizedBox(height: 10),
                    _CheckCard(
                      icon: Icons.folder_copy_outlined,
                      title: 'Стабильный Markdown Vault',
                      passed: !_report!.vaultStatus.readOnly,
                      subtitle: vaultReadinessSummary(_report!.vaultStatus),
                      child: Text(
                        _report!.vaultStatus.rootPath.isEmpty
                            ? 'Выбор Vault необязателен: основная база остаётся '
                                'локальной. После выбора Chronicle сохраняет '
                                'открытый Markdown и неизвестные поля frontmatter.'
                            : _report!.vaultStatus.rootPath,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _CheckCard(
                      icon: Icons.merge_type_rounded,
                      title: 'Конфликты и восстановление',
                      passed:
                          _report!.vaultStatus.pendingChangeCount == 0 &&
                          _report!.pendingConflictCount == 0 &&
                          _report!.automaticBackupCount > 0,
                      subtitle: _report!.pendingConflictCount > 0
                          ? 'Конфликтов ожидают решения: '
                              '${_report!.pendingConflictCount}.'
                          : _report!.vaultStatus.pendingChangeCount > 0
                          ? 'Изменений Vault ожидают просмотра: '
                              '${_report!.vaultStatus.pendingChangeCount}.'
                          : 'Непросмотренных изменений и конфликтов Vault нет.',
                      child: Text(
                        'Проверенных автоматических копий: '
                        '${_report!.automaticBackupCount}. '
                        'Перед опасным применением Vault и восстановлением '
                        'Chronicle создаёт аварийную копию.',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _CheckCard(
                      icon: Icons.undo_rounded,
                      title: 'Отмена основных операций',
                      passed: true,
                      subtitle:
                          'В текущем undo-журнале: ${_report!.undoDepth}.',
                      child: const Text(
                        'Ctrl+Z / Cmd+Z вне текстового редактора отменяет '
                        'удаление заметки или задачи, удаление источника и '
                        'архивирование проекта. Редактор сохраняет собственную '
                        'историю текста и версии заметки.',
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Card(
                      child: ExpansionTile(
                        leading: Icon(Icons.health_and_safety_outlined),
                        title: Text('Как восстановиться после ошибки'),
                        childrenPadding: EdgeInsets.fromLTRB(
                          18,
                          0,
                          18,
                          18,
                        ),
                        children: [
                          _RecoveryStep(
                            number: 1,
                            text:
                                'Не удаляй текущую папку Vault и не запускай '
                                'повторную синхронизацию.',
                          ),
                          _RecoveryStep(
                            number: 2,
                            text:
                                'Открой «Устройства и синхронизация» и проверь '
                                'диагностический журнал и каталог копий.',
                          ),
                          _RecoveryStep(
                            number: 3,
                            text:
                                'Выбери последнюю копию с подтверждёнными '
                                'контрольными суммами и просмотри её состав.',
                          ),
                          _RecoveryStep(
                            number: 4,
                            text:
                                'Восстановление сначала создаст аварийный '
                                'снимок, а при ошибке автоматически откатится.',
                          ),
                        ],
                      ),
                    ),
                    if (_busy) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(color: colors.primary),
                    ],
                  ],
                ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _busy ? null : _run,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Проверить снова'),
        ),
        FilledButton.tonalIcon(
          onPressed: _backupBusy || _busy ? null : _createBackup,
          icon: _backupBusy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.backup_outlined),
          label: const Text('Создать копию'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}

class _OverviewBanner extends StatelessWidget {
  const _OverviewBanner({required this.report});

  final ReleaseReadinessReport report;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ready = report.ready;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ready ? colors.primaryContainer : colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ready ? Icons.verified_rounded : Icons.warning_amber_rounded,
            color: ready ? colors.onPrimaryContainer : colors.onTertiaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ready
                      ? 'Основные гарантии 1.0 выполняются'
                      : 'Некоторые гарантии требуют внимания',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  ready
                      ? 'Проверены связи данных, обратимость резервной копии, '
                          'совместимость Vault и отсутствие открытых конфликтов.'
                      : 'Chronicle ничего не исправляет автоматически: открой '
                          'карточки ниже и реши, какие действия безопасны.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckCard extends StatelessWidget {
  const _CheckCard({
    required this.icon,
    required this.title,
    required this.passed,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final bool passed;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: colors.primary),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  passed
                      ? Icons.check_circle_rounded
                      : Icons.error_outline_rounded,
                  color: passed ? colors.primary : colors.error,
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _IntegrityIssueTile extends StatelessWidget {
  const _IntegrityIssueTile({required this.issue});

  final IntegrityIssue issue;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isError = issue.severity == IntegritySeverity.error;
    final isInfo = issue.severity == IntegritySeverity.info;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : isInfo
                ? Icons.info_outline_rounded
                : Icons.warning_amber_rounded,
            size: 18,
            color: isError
                ? colors.error
                : isInfo
                ? colors.primary
                : colors.tertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${issue.title}. ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: issue.details),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecoveryStep extends StatelessWidget {
  const _RecoveryStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 12, child: Text('$number')),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 42,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          const Text('Проверка готовности не завершена.'),
          const SizedBox(height: 6),
          Text('$error', textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}
