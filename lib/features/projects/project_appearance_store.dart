import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../appearance/app_appearance.dart';
import 'project_appearance.dart';

class ProjectIconSelection {
  const ProjectIconSelection({
    required this.bytes,
    required this.extension,
    required this.originalName,
  });

  static const int maxBytes = 10 * 1024 * 1024;

  final Uint8List bytes;
  final String extension;
  final String originalName;

  factory ProjectIconSelection.validate({
    required Uint8List bytes,
    required String originalName,
  }) {
    if (bytes.isEmpty) {
      throw const FormatException('Выбранный файл пуст.');
    }
    if (bytes.length > maxBytes) {
      throw const FormatException(
        'Иконка проекта должна быть не больше 10 МБ.',
      );
    }
    final extension = _detectImageExtension(bytes);
    if (extension == null) {
      throw const FormatException('Поддерживаются PNG, JPEG, WebP и GIF.');
    }
    return ProjectIconSelection(
      bytes: bytes,
      extension: extension,
      originalName: originalName,
    );
  }
}

class ProjectBackgroundSelection {
  const ProjectBackgroundSelection({
    required this.bytes,
    required this.extension,
    required this.originalName,
  });

  static const int maxBytes = 30 * 1024 * 1024;

  final Uint8List bytes;
  final String extension;
  final String originalName;

  factory ProjectBackgroundSelection.validate({
    required Uint8List bytes,
    required String originalName,
  }) {
    if (bytes.isEmpty) {
      throw const FormatException('Выбранный файл пуст.');
    }
    if (bytes.length > maxBytes) {
      throw const FormatException('Фон проекта должен быть не больше 30 МБ.');
    }
    final extension = _detectImageExtension(bytes);
    if (extension == null) {
      throw const FormatException('Поддерживаются PNG, JPEG, WebP и GIF.');
    }
    return ProjectBackgroundSelection(
      bytes: bytes,
      extension: extension,
      originalName: originalName,
    );
  }
}

Future<ProjectIconSelection?> pickProjectIcon() async {
  final result = await FilePicker.pickFiles(
    dialogTitle: 'Выбрать иконку проекта',
    type: FileType.custom,
    allowedExtensions: const <String>['png', 'jpg', 'jpeg', 'webp', 'gif'],
    lockParentWindow: true,
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.single;
  if (file.size > ProjectIconSelection.maxBytes) {
    throw const FormatException('Иконка проекта должна быть не больше 10 МБ.');
  }
  final bytes = await file.readAsBytes();
  return ProjectIconSelection.validate(bytes: bytes, originalName: file.name);
}

Future<ProjectBackgroundSelection?> pickProjectBackground() async {
  final result = await FilePicker.pickFiles(
    dialogTitle: 'Выбрать фон проекта',
    type: FileType.custom,
    allowedExtensions: const <String>['png', 'jpg', 'jpeg', 'webp', 'gif'],
    lockParentWindow: true,
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.single;
  if (file.size > ProjectBackgroundSelection.maxBytes) {
    throw const FormatException('Фон проекта должен быть не больше 30 МБ.');
  }
  final bytes = await file.readAsBytes();
  return ProjectBackgroundSelection.validate(
    bytes: bytes,
    originalName: file.name,
  );
}

class ProjectAppearanceStore {
  static const String preferencesKey = 'chronicle_project_appearance_v1';
  static const String iconDirectoryName = 'project_icons';
  static const String backgroundDirectoryName = 'project_backgrounds';

  Future<Map<String, ProjectAppearancePreferences>> load() async {
    final preferences = await SharedPreferences.getInstance();
    return decode(preferences.getString(preferencesKey));
  }

  Future<void> save(Map<String, ProjectAppearancePreferences> values) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(preferencesKey, encode(values));
    if (!saved) {
      throw StateError('Не удалось сохранить оформление проектов.');
    }
  }

  Future<Directory> iconDirectory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(path.join(support.path, iconDirectoryName));
    await directory.create(recursive: true);
    return directory;
  }

  Future<Directory> backgroundDirectory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      path.join(support.path, backgroundDirectoryName),
    );
    await directory.create(recursive: true);
    return directory;
  }

  static String encode(Map<String, ProjectAppearancePreferences> values) {
    return jsonEncode(<String, Object?>{
      for (final entry in values.entries) entry.key: entry.value.toJson(),
    });
  }

  static Map<String, ProjectAppearancePreferences> decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, ProjectAppearancePreferences>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, ProjectAppearancePreferences>{};
      }
      final result = <String, ProjectAppearancePreferences>{};
      for (final entry in decoded.entries) {
        final rawValue = entry.value;
        if (rawValue is! Map) continue;
        result[entry.key.toString()] = ProjectAppearancePreferences.fromJson(
          <String, Object?>{
            for (final item in rawValue.entries)
              item.key.toString(): item.value,
          },
        );
      }
      return result;
    } on Object {
      return <String, ProjectAppearancePreferences>{};
    }
  }
}

class ProjectAppearanceController extends ChangeNotifier {
  ProjectAppearanceController({ProjectAppearanceStore? store})
    : _store = store ?? ProjectAppearanceStore();

  final ProjectAppearanceStore _store;
  Map<String, ProjectAppearancePreferences> _values =
      <String, ProjectAppearancePreferences>{};
  Directory? _iconDirectory;
  Directory? _backgroundDirectory;
  bool _ready = false;
  bool _disposed = false;

  bool get ready => _ready;

  Future<void> load() async {
    try {
      _values = await _store.load();
    } on Object {
      _values = <String, ProjectAppearancePreferences>{};
    }
    try {
      _iconDirectory = await _store.iconDirectory();
    } on Object {
      _iconDirectory = null;
    }
    try {
      _backgroundDirectory = await _store.backgroundDirectory();
    } on Object {
      _backgroundDirectory = null;
    }
    _ready = true;
    _notify();
  }

  ProjectAppearancePreferences preferencesFor(String projectId) {
    return _values[projectId] ?? ProjectAppearancePreferences.defaults();
  }

  AppAppearancePreferences effectiveAppearance(
    String projectId,
    AppAppearancePreferences globalAppearance,
  ) {
    return preferencesFor(projectId).effectiveAppearance(globalAppearance);
  }

  File? iconFileFor(String projectId) {
    return _managedFile(_iconDirectory, preferencesFor(projectId).iconFileName);
  }

  File? backgroundFileFor(String projectId) {
    return _managedFile(
      _backgroundDirectory,
      preferencesFor(projectId).backgroundFileName,
    );
  }

  Future<void> saveProjectAppearance(
    String projectId,
    ProjectAppearancePreferences value, {
    ProjectIconSelection? icon,
    bool removeIcon = false,
    ProjectBackgroundSelection? background,
    bool removeBackground = false,
  }) async {
    var next = value;
    final old = preferencesFor(projectId);
    final iconDirectory = _iconDirectory ?? await _store.iconDirectory();
    final backgroundDirectory =
        _backgroundDirectory ?? await _store.backgroundDirectory();
    _iconDirectory = iconDirectory;
    _backgroundDirectory = backgroundDirectory;
    final newlyWrittenFiles = <File>[];
    String? oldIconToDelete;
    String? oldBackgroundToDelete;

    if (removeIcon) {
      oldIconToDelete = old.iconFileName;
      next = next.copyWith(
        clearIconFileName: true,
        iconRevision: old.iconRevision + 1,
      );
    } else if (icon != null) {
      final fileName = _managedFileName(
        prefix: 'project_icon',
        projectId: projectId,
        extension: icon.extension,
      );
      final file = File(path.join(iconDirectory.path, fileName));
      await file.writeAsBytes(icon.bytes, flush: true);
      newlyWrittenFiles.add(file);
      oldIconToDelete = old.iconFileName;
      next = next.copyWith(
        iconFileName: fileName,
        iconRevision: old.iconRevision + 1,
      );
    } else if (next.iconFileName == null && old.iconFileName != null) {
      next = next.copyWith(
        iconFileName: old.iconFileName,
        iconRevision: old.iconRevision,
      );
    }

    if (removeBackground) {
      oldBackgroundToDelete = old.backgroundFileName;
      next = next.copyWith(
        clearBackgroundFileName: true,
        backgroundRevision: old.backgroundRevision + 1,
      );
    } else if (background != null) {
      final fileName = _managedFileName(
        prefix: 'project_background',
        projectId: projectId,
        extension: background.extension,
      );
      final file = File(path.join(backgroundDirectory.path, fileName));
      await file.writeAsBytes(background.bytes, flush: true);
      newlyWrittenFiles.add(file);
      oldBackgroundToDelete = old.backgroundFileName;
      next = next.copyWith(
        backgroundFileName: fileName,
        backgroundRevision: old.backgroundRevision + 1,
      );
    } else if (next.backgroundFileName == null &&
        old.backgroundFileName != null) {
      next = next.copyWith(
        backgroundFileName: old.backgroundFileName,
        backgroundRevision: old.backgroundRevision,
      );
    }

    final updated = Map<String, ProjectAppearancePreferences>.from(_values);
    updated[projectId] = next;
    try {
      await _store.save(updated);
    } on Object {
      for (final file in newlyWrittenFiles) {
        try {
          if (await file.exists()) await file.delete();
        } on FileSystemException {
          // Best-effort cleanup must not mask the preference write error.
        }
      }
      rethrow;
    }
    _values = updated;
    _notify();
    if (oldIconToDelete != null && oldIconToDelete != next.iconFileName) {
      await _deleteManagedFile(oldIconToDelete, iconDirectory);
    }
    if (oldBackgroundToDelete != null &&
        oldBackgroundToDelete != next.backgroundFileName) {
      await _deleteManagedFile(oldBackgroundToDelete, backgroundDirectory);
    }
  }

  Future<void> removeProject(String projectId) async {
    final old = _values[projectId];
    final iconDirectory = _iconDirectory ?? await _store.iconDirectory();
    final backgroundDirectory =
        _backgroundDirectory ?? await _store.backgroundDirectory();
    _iconDirectory = iconDirectory;
    _backgroundDirectory = backgroundDirectory;
    final updated = Map<String, ProjectAppearancePreferences>.from(_values)
      ..remove(projectId);
    await _store.save(updated);
    _values = updated;
    _notify();
    await _deleteManagedFile(old?.iconFileName, iconDirectory);
    await _deleteManagedFile(old?.backgroundFileName, backgroundDirectory);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  File? _managedFile(Directory? directory, String? fileName) {
    if (directory == null || fileName == null) return null;
    if (path.basename(fileName) != fileName) return null;
    final file = File(path.join(directory.path, fileName));
    return file.existsSync() ? file : null;
  }

  String _managedFileName({
    required String prefix,
    required String projectId,
    required String extension,
  }) {
    final safeProjectId = projectId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return '${prefix}_${safeProjectId}_'
        '${DateTime.now().microsecondsSinceEpoch}.$extension';
  }

  Future<void> _deleteManagedFile(String? fileName, Directory directory) async {
    if (fileName == null || path.basename(fileName) != fileName) return;
    final file = File(path.join(directory.path, fileName));
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // A stale managed image is harmless.
    }
  }
}

String? _detectImageExtension(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return 'png';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'jpg';
  }
  if (bytes.length >= 6) {
    final signature = String.fromCharCodes(bytes.take(6));
    if (signature == 'GIF87a' || signature == 'GIF89a') return 'gif';
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return 'webp';
  }
  return null;
}
