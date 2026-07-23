import 'dart:convert';

import '../models/app_models.dart';
import '../vault/vault_models.dart';
import '../vault/vault_service.dart';

// Keep this in one place so diagnostics, release metadata and the UI cannot
// silently drift apart.
const String chronicleStableVersion = '1.0.1+101';

enum IntegritySeverity { info, warning, error }

class IntegrityIssue {
  const IntegrityIssue({
    required this.code,
    required this.title,
    required this.details,
    required this.severity,
    this.entityIds = const <String>[],
  });

  final String code;
  final String title;
  final String details;
  final IntegritySeverity severity;
  final List<String> entityIds;
}

class DataIntegrityReport {
  const DataIntegrityReport({
    required this.checkedAt,
    required this.issues,
    required this.projectCount,
    required this.taskCount,
    required this.noteCount,
    required this.linkCount,
    required this.versionCount,
    required this.entryCount,
    required this.citationCount,
  });

  final DateTime checkedAt;
  final List<IntegrityIssue> issues;
  final int projectCount;
  final int taskCount;
  final int noteCount;
  final int linkCount;
  final int versionCount;
  final int entryCount;
  final int citationCount;

  int get errorCount => issues
      .where((issue) => issue.severity == IntegritySeverity.error)
      .length;
  int get warningCount => issues
      .where((issue) => issue.severity == IntegritySeverity.warning)
      .length;
  bool get healthy => errorCount == 0;
  bool get clean => errorCount == 0 && warningCount == 0;
}

class BackupRoundTripReport {
  const BackupRoundTripReport({
    required this.valid,
    required this.message,
    required this.formatVersion,
    required this.projectCount,
    required this.taskCount,
    required this.noteCount,
    required this.entryCount,
  });

  final bool valid;
  final String message;
  final int formatVersion;
  final int projectCount;
  final int taskCount;
  final int noteCount;
  final int entryCount;
}

class ReleaseReadinessReport {
  const ReleaseReadinessReport({
    required this.checkedAt,
    required this.integrity,
    required this.backupRoundTrip,
    required this.vaultStatus,
    required this.undoDepth,
    required this.automaticBackupCount,
    required this.pendingConflictCount,
  });

  final DateTime checkedAt;
  final DataIntegrityReport integrity;
  final BackupRoundTripReport backupRoundTrip;
  final VaultStatus vaultStatus;
  final int undoDepth;
  final int automaticBackupCount;
  final int pendingConflictCount;

  bool get ready =>
      integrity.clean &&
      backupRoundTrip.valid &&
      !vaultStatus.readOnly &&
      vaultStatus.pendingChangeCount == 0 &&
      pendingConflictCount == 0 &&
      automaticBackupCount > 0;
}

class ChronicleIntegrityAuditor {
  const ChronicleIntegrityAuditor._();

  static DataIntegrityReport audit(AppData data) {
    final issues = <IntegrityIssue>[];
    final projectIds = data.projects.map((item) => item.id).toSet();
    final taskIds = data.tasks.map((item) => item.id).toSet();
    final noteIds = data.notes.map((item) => item.id).toSet();

    _checkDuplicateIds(
      issues,
      code: 'duplicate-project-id',
      label: 'проектов',
      ids: data.projects.map((item) => item.id),
    );
    _checkDuplicateIds(
      issues,
      code: 'duplicate-task-id',
      label: 'задач',
      ids: data.tasks.map((item) => item.id),
    );
    _checkDuplicateIds(
      issues,
      code: 'duplicate-note-id',
      label: 'заметок',
      ids: data.notes.map((item) => item.id),
    );
    _checkDuplicateIds(
      issues,
      code: 'duplicate-time-entry-id',
      label: 'записей времени',
      ids: data.entries.map((item) => item.id),
    );
    _checkDuplicateIds(
      issues,
      code: 'duplicate-note-link-id',
      label: 'связей заметок',
      ids: data.noteLinks.map((item) => item.id),
    );
    _checkDuplicateIds(
      issues,
      code: 'duplicate-note-version-id',
      label: 'версий заметок',
      ids: data.noteVersions.map((item) => item.id),
    );
    _checkDuplicateIds(
      issues,
      code: 'duplicate-citation-source-id',
      label: 'источников',
      ids: data.citationSources.map((item) => item.id),
    );

    final orphanNotes = data.notes
        .where((note) => !projectIds.contains(note.projectId))
        .map((note) => note.id)
        .toList(growable: false);
    _addOrphanIssue(
      issues,
      code: 'orphan-notes',
      title: 'Заметки без существующего проекта',
      details: 'Такие заметки нельзя надёжно показать в проектной структуре.',
      ids: orphanNotes,
    );

    final orphanTasks = data.tasks
        .where((task) => !projectIds.contains(task.projectId))
        .map((task) => task.id)
        .toList(growable: false);
    _addOrphanIssue(
      issues,
      code: 'orphan-tasks',
      title: 'Задачи без существующего проекта',
      details: 'Связь задачи с проектом повреждена.',
      ids: orphanTasks,
    );

    final sourceIds = data.citationSources.map((item) => item.id).toSet();
    final brokenPinnedNotes = <String>[];
    final brokenLinkedSources = <String>[];
    for (final project in data.projects) {
      for (final noteId in project.pinnedNoteIds) {
        if (!noteIds.contains(noteId)) {
          brokenPinnedNotes.add('${project.id}:$noteId');
        }
      }
      for (final sourceId in project.linkedSourceIds) {
        if (!sourceIds.contains(sourceId)) {
          brokenLinkedSources.add('${project.id}:$sourceId');
        }
      }
    }
    _addOrphanIssue(
      issues,
      code: 'project-missing-pinned-note',
      title: 'Проекты с отсутствующими закреплёнными заметками',
      details: 'Закреплённый результат больше не существует.',
      ids: brokenPinnedNotes,
      severity: IntegritySeverity.warning,
    );
    _addOrphanIssue(
      issues,
      code: 'project-missing-linked-source',
      title: 'Проекты с отсутствующими источниками',
      details: 'Связанный библиографический источник больше не существует.',
      ids: brokenLinkedSources,
      severity: IntegritySeverity.warning,
    );

    final brokenTaskNotes = data.tasks
        .where(
          (task) =>
              task.noteId != null && !noteIds.contains(task.noteId),
        )
        .map((task) => task.id)
        .toList(growable: false);
    _addOrphanIssue(
      issues,
      code: 'task-missing-note',
      title: 'Задачи с отсутствующей заметкой',
      details: 'Задача хранит ссылку на заметку, которой больше нет.',
      ids: brokenTaskNotes,
      severity: IntegritySeverity.warning,
    );

    final brokenParents = data.tasks
        .where(
          (task) =>
              task.parentTaskId != null &&
              (!taskIds.contains(task.parentTaskId) ||
                  task.parentTaskId == task.id),
        )
        .map((task) => task.id)
        .toList(growable: false);
    _addOrphanIssue(
      issues,
      code: 'task-missing-parent',
      title: 'Задачи с повреждённой иерархией',
      details: 'Родительская задача отсутствует или задача ссылается на себя.',
      ids: brokenParents,
      severity: IntegritySeverity.warning,
    );

    final brokenEntries = data.entries
        .where((entry) => !projectIds.contains(entry.projectId))
        .map((entry) => entry.id)
        .toList(growable: false);
    _addOrphanIssue(
      issues,
      code: 'time-entry-missing-project',
      title: 'Записи времени без существующего проекта',
      details: 'История времени потеряла обязательную связь с проектом.',
      ids: brokenEntries,
      severity: IntegritySeverity.warning,
    );

    final brokenLinks = data.noteLinks
        .where(
          (link) =>
              !noteIds.contains(link.sourceNoteId) ||
              (link.targetNoteId != null &&
                  !noteIds.contains(link.targetNoteId)),
        )
        .map((link) => link.id)
        .toList(growable: false);
    _addOrphanIssue(
      issues,
      code: 'note-link-broken-reference',
      title: 'Индекс связей содержит отсутствующие заметки',
      details: 'Индекс можно безопасно перестроить из Markdown.',
      ids: brokenLinks,
      severity: IntegritySeverity.warning,
    );

    final orphanVersions = data.noteVersions
        .where((version) => !noteIds.contains(version.noteId))
        .map((version) => version.id)
        .toList(growable: false);
    _addOrphanIssue(
      issues,
      code: 'orphan-note-versions',
      title: 'Версии без исходной заметки',
      details: 'История сохранена, но исходная заметка отсутствует.',
      ids: orphanVersions,
      severity: IntegritySeverity.info,
    );

    final duplicateCitationKeys = _duplicates(
      data.citationSources
          .map((source) => source.normalizedCitationKey)
          .where((key) => key.isNotEmpty),
    );
    if (duplicateCitationKeys.isNotEmpty) {
      issues.add(
        IntegrityIssue(
          code: 'duplicate-citation-key',
          title: 'Повторяющиеся ключи цитирования',
          details:
              'Ключи должны быть уникальны: ${duplicateCitationKeys.join(', ')}.',
          severity: IntegritySeverity.warning,
          entityIds: duplicateCitationKeys,
        ),
      );
    }

    return DataIntegrityReport(
      checkedAt: DateTime.now(),
      issues: List<IntegrityIssue>.unmodifiable(issues),
      projectCount: data.projects.length,
      taskCount: data.tasks.length,
      noteCount: data.notes.length,
      linkCount: data.noteLinks.length,
      versionCount: data.noteVersions.length,
      entryCount: data.entries.length,
      citationCount: data.citationSources.length,
    );
  }

  static BackupRoundTripReport verifyBackupRoundTrip(String raw) {
    try {
      final first = AppData.decode(raw);
      final encodedAgain = first.encode();
      final second = AppData.decode(encodedAgain);
      final firstCanonical = _canonicalSnapshot(first);
      final secondCanonical = _canonicalSnapshot(second);
      final valid = firstCanonical == secondCanonical;
      return BackupRoundTripReport(
        valid: valid,
        message: valid
            ? 'Экспорт и повторный импорт сохраняют все сущности без изменений.'
            : 'Повторный импорт изменил содержимое резервной копии.',
        formatVersion: AppData.formatVersionOf(raw),
        projectCount: first.projects.length,
        taskCount: first.tasks.length,
        noteCount: first.notes.length,
        entryCount: first.entries.length,
      );
    } on Object catch (error) {
      return BackupRoundTripReport(
        valid: false,
        message: 'Проверка round-trip не выполнена: $error',
        formatVersion: 0,
        projectCount: 0,
        taskCount: 0,
        noteCount: 0,
        entryCount: 0,
      );
    }
  }

  static String _canonicalSnapshot(AppData data) {
    List<Map<String, dynamic>> sorted<T>(
      Iterable<T> values,
      Map<String, dynamic> Function(T value) json,
    ) {
      final list = values.map(json).toList();
      list.sort((left, right) {
        final leftId = left['id']?.toString() ?? '';
        final rightId = right['id']?.toString() ?? '';
        return leftId.compareTo(rightId);
      });
      return list;
    }

    final snapshot = <String, Object?>{
      'projects': sorted(data.projects, (item) => item.toJson()),
      'tasks': sorted(data.tasks, (item) => item.toJson()),
      'notes': sorted(data.notes, (item) => item.toJson()),
      'entries': sorted(data.entries, (item) => item.toJson()),
      'noteLinks': sorted(
        data.noteLinks,
        (item) => item.toJson(),
      ),
      'noteVersions': sorted(
        data.noteVersions,
        (item) => item.toJson(),
      ),
      'citationSources': sorted(
        data.citationSources,
        (item) => item.toJson(),
      ),
    };
    return jsonEncode(snapshot);
  }

  static void _checkDuplicateIds(
    List<IntegrityIssue> issues, {
    required String code,
    required String label,
    required Iterable<String> ids,
  }) {
    final duplicateIds = _duplicates(ids.where((id) => id.trim().isNotEmpty));
    final emptyCount = ids.where((id) => id.trim().isEmpty).length;
    if (duplicateIds.isEmpty && emptyCount == 0) {
      return;
    }
    issues.add(
      IntegrityIssue(
        code: code,
        title: 'Неуникальные идентификаторы $label',
        details: emptyCount > 0
            ? 'Найдены пустые идентификаторы: $emptyCount.'
            : 'Повторяются: ${duplicateIds.join(', ')}.',
        severity: IntegritySeverity.error,
        entityIds: duplicateIds,
      ),
    );
  }

  static void _addOrphanIssue(
    List<IntegrityIssue> issues, {
    required String code,
    required String title,
    required String details,
    required List<String> ids,
    IntegritySeverity severity = IntegritySeverity.error,
  }) {
    if (ids.isEmpty) {
      return;
    }
    issues.add(
      IntegrityIssue(
        code: code,
        title: title,
        details: '$details Найдено: ${ids.length}.',
        severity: severity,
        entityIds: ids.take(12).toList(growable: false),
      ),
    );
  }

  static List<String> _duplicates(Iterable<String> values) {
    final seen = <String>{};
    final duplicates = <String>{};
    for (final value in values) {
      if (!seen.add(value)) {
        duplicates.add(value);
      }
    }
    final result = duplicates.toList()..sort();
    return result;
  }
}

String vaultReadinessSummary(VaultStatus status) {
  if (!status.supported) {
    return status.message ?? 'Vault недоступен на этой платформе.';
  }
  if (status.readOnly) {
    return status.message ?? 'Vault открыт только для чтения.';
  }
  final version =
      status.formatVersion ?? VaultService.currentVaultFormatVersion;
  if (status.rootPath.isEmpty) {
    return 'Формат Vault v$version стабилен; папка пока не выбрана.';
  }
  return 'Vault v$version доступен для чтения и записи.';
}
