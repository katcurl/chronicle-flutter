import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_store.dart';
import 'pairing_host_screen.dart';
import 'pairing_scan_screen.dart';
import '../sync/sync_models.dart';
import '../vault/vault_models.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  bool refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  Future<void> _refresh() async {
    if (refreshing) {
      return;
    }
    setState(() => refreshing = true);
    try {
      await widget.store.refreshSyncFoundation();
      await widget.store.refreshVaultStatus();
    } finally {
      if (mounted) {
        setState(() => refreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity = widget.store.deviceIdentity;
    final preferences = widget.store.syncPreferences;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Устройства и синхронизация'),
        actions: [
          IconButton(
            tooltip: 'Обновить сведения',
            onPressed: refreshing ? null : _refresh,
            icon:
                refreshing
                    ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          _SectionHeader(
            title: 'Это устройство',
            subtitle: 'Постоянный идентификатор создаётся один раз.',
          ),
          const SizedBox(height: 10),
          _DeviceIdentityCard(
            identity: identity,
            onRename: identity == null ? null : () => _rename(identity),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(
            title: 'Автоматическая синхронизация',
            subtitle: 'Только между доверенными устройствами в локальной сети.',
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Автосинхронизация'),
                  subtitle: const Text(
                    'Синхронизировать изменения, когда связанное устройство '
                    'обнаружено в той же сети.',
                  ),
                  value: preferences.autoSyncEnabled,
                  onChanged: (value) {
                    widget.store.updateSyncPreferences(
                      preferences.copyWith(autoSyncEnabled: value),
                    );
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Обнаружение в локальной сети'),
                  subtitle: const Text(
                    'Искать Chronicle Desktop или Android через Wi‑Fi/LAN.',
                  ),
                  value: preferences.discoverOnLocalNetwork,
                  onChanged: (value) {
                    widget.store.updateSyncPreferences(
                      preferences.copyWith(discoverOnLocalNetwork: value),
                    );
                  },
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.lock_outline_rounded),
                  title: Text('Только доверенные устройства'),
                  subtitle: Text(
                    'Одна сеть не считается авторизацией. Подключение будет '
                    'разрешено только после QR-сопряжения.',
                  ),
                  trailing: Icon(Icons.verified_user_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Связанные устройства',
            subtitle:
                widget.store.trustedDevices.isEmpty
                    ? 'Пока ни одно устройство не сопряжено.'
                    : 'Устройства, которым разрешён обмен данными.',
          ),
          const SizedBox(height: 10),
          if (widget.store.trustedDevices.isEmpty)
            _EmptyDevicesCard(onPair: _openPairing)
          else
            ...widget.store.trustedDevices.map(
              (device) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TrustedDeviceCard(
                  device: device,
                  onRevoke: () => _confirmRevoke(device),
                ),
              ),
            ),
          if (widget.store.trustedDevices.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: _openPairing,
                icon: const Icon(Icons.add_link_rounded),
                label: const Text('Подключить устройство'),
              ),
            ),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Журнал изменений',
            subtitle:
                '${widget.store.journalEntryCount} локальных событий. '
                'Именно этот журнал позже будет передаваться между устройствами.',
          ),
          const SizedBox(height: 10),
          _JournalCard(changes: widget.store.recentChanges),
          const SizedBox(height: 24),
          const _SectionHeader(
            title: 'Markdown Vault',
            subtitle:
                'Двусторонние Markdown-файлы и локальные вложения без облака.',
          ),
          const SizedBox(height: 10),
          _VaultCard(
            status: widget.store.vaultStatus,
            busy: widget.store.vaultBusy,
            onWrite: _writeVault,
            onScan: _scanVault,
            onChooseFolder: _chooseVaultFolder,
          ),
          const SizedBox(height: 24),
          const _SectionHeader(
            title: 'Резервная копия',
            subtitle: 'Один переносимый файл с проверкой контрольных сумм.',
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  enabled: !widget.store.vaultBusy,
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Экспортировать Chronicle'),
                  subtitle: const Text(
                    'Создать файл .chronicle с проектами, задачами, '
                    'заметками, временем и Markdown Vault.',
                  ),
                  onTap: widget.store.vaultBusy ? null : _exportBackup,
                ),
                const Divider(height: 1),
                ListTile(
                  enabled: !widget.store.vaultBusy,
                  leading: const Icon(Icons.settings_backup_restore_rounded),
                  title: const Text('Восстановить из файла'),
                  subtitle: const Text(
                    'Перед заменой данных Chronicle создаст аварийную копию.',
                  ),
                  onTap: widget.store.vaultBusy ? null : _restoreBackup,
                ),
                const Divider(height: 1),
                ListTile(
                  enabled: !widget.store.vaultBusy,
                  leading: const Icon(Icons.copy_all_outlined),
                  title: const Text('Скопировать JSON-копию'),
                  subtitle: const Text('Запасной совместимый экспорт в буфер.'),
                  onTap: widget.store.vaultBusy ? null : _copyBackup,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _FoundationNotice(),
        ],
      ),
    );
  }

  Future<void> _rename(DeviceIdentity identity) async {
    final controller = TextEditingController(text: identity.displayName);
    final result = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Название устройства'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 48,
              decoration: const InputDecoration(
                labelText: 'Как показывать устройство',
              ),
              onSubmitted: (value) => Navigator.pop(dialogContext, value),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, controller.text),
                child: const Text('Сохранить'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (result == null || !mounted) {
      return;
    }
    await widget.store.renameLocalDevice(result);
  }

  Future<void> _openPairing() async {
    if (kIsWeb) {
      await showDialog<void>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Нужна нативная версия Chronicle'),
              content: const Text(
                'Локальное QR-сопряжение работает в Android и desktop-сборках. '
                'Браузерная версия не может открыть локальный sync-сервис.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Понятно'),
                ),
              ],
            ),
      );
      return;
    }

    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    if (!isAndroid) {
      await _openPairingHost();
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.qr_code_scanner_rounded),
                    title: const Text('Сканировать QR-код'),
                    subtitle: const Text(
                      'Подключить телефон к Chronicle на компьютере.',
                    ),
                    onTap: () => Navigator.pop(sheetContext, 'scan'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.qr_code_2_rounded),
                    title: const Text('Показать QR-код'),
                    subtitle: const Text(
                      'Разрешить другому устройству отсканировать этот телефон.',
                    ),
                    onTap: () => Navigator.pop(sheetContext, 'host'),
                  ),
                ],
              ),
            ),
          ),
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == 'scan') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => PairingScanScreen(store: widget.store),
        ),
      );
    } else {
      await _openPairingHost();
    }
    await widget.store.refreshSyncFoundation();
  }

  Future<void> _openPairingHost() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => PairingHostScreen(store: widget.store)),
    );
    await widget.store.refreshSyncFoundation();
  }

  Future<void> _confirmRevoke(TrustedDevice device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Отозвать доверие?'),
            content: Text(
              '${device.displayName} больше не сможет синхронизироваться с этим '
              'Chronicle. Для повторного подключения потребуется новое сопряжение.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Отозвать'),
              ),
            ],
          ),
    );
    if (confirmed != true) {
      return;
    }
    await widget.store.revokeTrustedDevice(device.deviceId);
  }

  Future<void> _writeVault() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.store.writeVaultMirror();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Markdown Vault обновлён')),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось обновить Vault: $error')),
      );
    }
  }

  Future<void> _chooseVaultFolder() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final changed = await widget.store.chooseVaultFolder();
      if (!mounted || !changed) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Новая папка Vault выбрана')),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось выбрать папку: $error')),
      );
    }
  }

  Future<void> _scanVault() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final scan = await widget.store.scanVaultChanges();
      if (!mounted) {
        return;
      }
      if (!scan.hasChanges) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Внешних изменений не найдено')),
        );
        return;
      }
      final resolution = await _showVaultChanges(scan);
      if (resolution == null || !mounted) {
        return;
      }
      final result = await widget.store.applyVaultChanges(
        scan,
        conflictResolution: resolution,
      );
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Vault применён: ${result.createdCount} новых, '
            '${result.updatedCount} обновлено, '
            '${result.duplicatedCount} сохранено отдельно.',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось проверить Vault: $error')),
      );
    }
  }

  Future<VaultConflictResolution?> _showVaultChanges(VaultScanResult scan) {
    final safe = scan.safeChanges;
    final conflicts = scan.conflicts;
    return showDialog<VaultConflictResolution>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            icon: Icon(
              conflicts.isEmpty
                  ? Icons.sync_alt_rounded
                  : Icons.merge_type_rounded,
              size: 42,
            ),
            title: Text(
              conflicts.isEmpty
                  ? 'Импортировать изменения Vault?'
                  : 'Обнаружены конфликты Vault',
            ),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Безопасные изменения: ${safe.length}'),
                    Text('Конфликты: ${conflicts.length}'),
                    Text('Отсутствующие файлы: ${scan.missingFiles.length}'),
                    const SizedBox(height: 14),
                    for (final change in scan.changes.take(10))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          change.isConflict
                              ? Icons.warning_amber_rounded
                              : change.isNew
                              ? Icons.note_add_outlined
                              : Icons.edit_note_rounded,
                        ),
                        title: Text(change.proposedNote.title),
                        subtitle: Text(change.relativePath),
                      ),
                    if (scan.changes.length > 10)
                      Text('И ещё ${scan.changes.length - 10} изменений…'),
                    if (scan.missingFiles.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Удалённые с диска управляемые файлы будут восстановлены. '
                        'Заметки из базы не удаляются автоматически.',
                      ),
                    ],
                    if (conflicts.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Выбранное решение будет применено ко всем конфликтам. '
                        'Перед импортом Chronicle сохранит внутреннюю версию каждой '
                        'заметки в истории.',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Отмена'),
              ),
              if (conflicts.isNotEmpty)
                TextButton(
                  onPressed:
                      () => Navigator.pop(
                        dialogContext,
                        VaultConflictResolution.keepChronicle,
                      ),
                  child: const Text('Оставить Chronicle'),
                ),
              if (conflicts.isNotEmpty)
                OutlinedButton(
                  onPressed:
                      () => Navigator.pop(
                        dialogContext,
                        VaultConflictResolution.keepBoth,
                      ),
                  child: const Text('Сохранить обе'),
                ),
              FilledButton(
                onPressed:
                    () => Navigator.pop(
                      dialogContext,
                      VaultConflictResolution.importFile,
                    ),
                child: Text(
                  conflicts.isEmpty ? 'Импортировать' : 'Взять версию файла',
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _exportBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await widget.store.exportBackupFile();
      if (!mounted || result == null) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Копия сохранена: ${result.fileName}')),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось создать копию: $error')),
      );
    }
  }

  Future<void> _restoreBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final payload = await widget.store.pickBackupFile();
      if (!mounted || payload == null) {
        return;
      }
      final confirmed = await _confirmRestore(payload);
      if (confirmed != true || !mounted) {
        return;
      }
      await widget.store.restoreBackupFile(payload);
      if (!mounted) {
        return;
      }
      final emergencyPath = widget.store.lastEmergencyBackupPath;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            emergencyPath == null
                ? 'Данные восстановлены'
                : 'Данные восстановлены. Страховочная копия создана.',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось восстановить: $error')),
      );
    }
  }

  Future<bool?> _confirmRestore(BackupImportPayload payload) {
    final preview = payload.preview;
    return showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            icon: const Icon(Icons.restore_page_rounded, size: 42),
            title: const Text('Восстановить резервную копию?'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(payload.sourceName),
                  const SizedBox(height: 12),
                  Text('Проекты: ${preview.projectCount}'),
                  Text('Задачи: ${preview.taskCount}'),
                  Text('Заметки: ${preview.noteCount}'),
                  Text('Записи времени: ${preview.entryCount}'),
                  Text('Вложения: ${preview.attachmentCount}'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded, size: 19),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          preview.checksumsVerified
                              ? 'Контрольные суммы проверены.'
                              : 'Контрольные суммы не подтверждены.',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Текущие рабочие данные будут заменены. Перед этим Chronicle '
                    'автоматически сохранит страховочную копию в папке Vault.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Восстановить'),
              ),
            ],
          ),
    );
  }

  Future<void> _copyBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    final backup = await widget.store.exportBackupJson();
    await Clipboard.setData(ClipboardData(text: backup));
    if (!mounted) {
      return;
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('JSON-копия скопирована')),
    );
  }
}

class _VaultCard extends StatelessWidget {
  const _VaultCard({
    required this.status,
    required this.busy,
    required this.onWrite,
    required this.onScan,
    required this.onChooseFolder,
  });

  final VaultStatus status;
  final bool busy;
  final VoidCallback onWrite;
  final VoidCallback onScan;
  final VoidCallback onChooseFolder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastWritten = status.lastWrittenAt?.toLocal();
    final lastWrittenText =
        lastWritten == null
            ? 'Ещё не создавался'
            : '${lastWritten.day.toString().padLeft(2, '0')}.'
                '${lastWritten.month.toString().padLeft(2, '0')}.'
                '${lastWritten.year} '
                '${lastWritten.hour.toString().padLeft(2, '0')}:'
                '${lastWritten.minute.toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.folder_copy_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.supported
                            ? 'Chronicle Vault'
                            : 'Vault недоступен',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        status.rootPath.isEmpty
                            ? status.message ?? 'Путь пока не определён.'
                            : status.rootPath,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                Text('Заметок: ${status.noteCount}'),
                Text('Файлов: ${status.fileCount}'),
                Text('Вложений: ${status.attachmentCount}'),
                Text('Изменений: ${status.pendingChangeCount}'),
                Text('Конфликтов: ${status.conflictCount}'),
                if (status.missingFileCount > 0)
                  Text('Отсутствует: ${status.missingFileCount}'),
                Text('Обновлён: $lastWrittenText'),
              ],
            ),
            if (status.message != null && status.rootPath.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                status.message!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: busy || !status.supported ? null : onScan,
                  icon: const Icon(Icons.manage_search_rounded),
                  label: Text(
                    status.pendingChangeCount > 0
                        ? 'Просмотреть изменения'
                        : 'Проверить изменения',
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: busy || !status.supported ? null : onWrite,
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Записать из Chronicle'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onChooseFolder,
                  icon: const Icon(Icons.drive_file_move_outline),
                  label: const Text('Выбрать папку'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DeviceIdentityCard extends StatelessWidget {
  const _DeviceIdentityCard({required this.identity, required this.onRename});

  final DeviceIdentity? identity;
  final VoidCallback? onRename;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (identity == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                _platformIcon(identity!.platform),
                color: colors.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    identity!.displayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${platformDisplayName(identity!.platform)} · '
                    'ID ${identity!.shortId}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Переименовать',
              onPressed: onRename,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDevicesCard extends StatelessWidget {
  const _EmptyDevicesCard({required this.onPair});

  final VoidCallback onPair;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(
              Icons.devices_other_rounded,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Телефон и компьютер будут находить друг друга автоматически',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Сначала потребуется один раз подтвердить пару через QR-код. '
              'Аккаунт и почта не нужны.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onPair,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Подключить устройство'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustedDeviceCard extends StatelessWidget {
  const _TrustedDeviceCard({required this.device, required this.onRevoke});

  final TrustedDevice device;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(_platformIcon(device.platform)),
        title: Text(device.displayName),
        subtitle: Text(
          device.lastSyncAt == null
              ? '${platformDisplayName(device.platform)} · ещё не синхронизировалось'
              : '${platformDisplayName(device.platform)} · '
                  'синхронизация ${_relativeTime(device.lastSyncAt!)}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'revoke') {
              onRevoke();
            }
          },
          itemBuilder:
              (_) => const [
                PopupMenuItem(value: 'revoke', child: Text('Отозвать доверие')),
              ],
        ),
      ),
    );
  }
}

class _JournalCard extends StatelessWidget {
  const _JournalCard({required this.changes});

  final List<ChangeRecord> changes;

  @override
  Widget build(BuildContext context) {
    if (changes.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.history_toggle_off_rounded),
          title: Text('Журнал пока пуст'),
          subtitle: Text('Измени проект, задачу или заметку.'),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < changes.length && index < 8; index++) ...[
            _ChangeTile(change: changes[index]),
            if (index < changes.length - 1 && index < 7)
              const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _ChangeTile extends StatelessWidget {
  const _ChangeTile({required this.change});

  final ChangeRecord change;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(_entityIcon(change.entityType)),
      title: Text(
        '${_operationLabel(change.operation)} · '
        '${_entityLabel(change.entityType)}',
      ),
      subtitle: Text(
        'rev ${change.revision} · ${_relativeTime(change.changedAt)}',
      ),
      trailing: Text(
        '#${change.localSequence}',
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class _FoundationNotice extends StatelessWidget {
  const _FoundationNotice();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.construction_rounded, color: colors.onTertiaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'v0.15 добавляет настоящее QR-сопряжение, одноразовый токен и '
              'проверку ключей устройств. Передача проектов и заметок начнётся '
              'в следующей версии после проверки доверенного соединения.',
              style: TextStyle(color: colors.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _platformIcon(String platform) {
  return switch (platform.toLowerCase()) {
    'android' || 'ios' => Icons.smartphone_rounded,
    'windows' || 'linux' || 'macos' => Icons.computer_rounded,
    'web' => Icons.language_rounded,
    _ => Icons.devices_rounded,
  };
}

IconData _entityIcon(String entityType) {
  return switch (entityType) {
    'project' => Icons.folder_outlined,
    'task' => Icons.check_circle_outline_rounded,
    'note' || 'note_version' => Icons.note_outlined,
    'time_entry' => Icons.timer_outlined,
    _ => Icons.sync_alt_rounded,
  };
}

String _entityLabel(String entityType) {
  return switch (entityType) {
    'project' => 'проект',
    'task' => 'задача',
    'note' => 'заметка',
    'note_version' => 'версия заметки',
    'time_entry' => 'сессия времени',
    _ => entityType,
  };
}

String _operationLabel(String operation) {
  return switch (operation) {
    'upsert' => 'Изменено',
    'append' => 'Добавлено',
    'delete' => 'Удалено',
    'restore' => 'Восстановлено',
    'snapshot' => 'Снимок',
    _ => operation,
  };
}

String _relativeTime(DateTime dateTime) {
  final difference = DateTime.now().difference(dateTime);
  if (difference.inSeconds < 30) {
    return 'только что';
  }
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes} мин назад';
  }
  if (difference.inHours < 24) {
    return '${difference.inHours} ч назад';
  }
  return '${difference.inDays} дн назад';
}
