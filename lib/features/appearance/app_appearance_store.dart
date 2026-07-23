import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_appearance.dart';

class AppBackgroundSelection {
  const AppBackgroundSelection({
    required this.bytes,
    required this.extension,
    required this.originalName,
  });

  static const int maxBytes = 30 * 1024 * 1024;

  final Uint8List bytes;
  final String extension;
  final String originalName;

  factory AppBackgroundSelection.validate({
    required Uint8List bytes,
    required String originalName,
  }) {
    if (bytes.isEmpty) {
      throw const FormatException('Выбранный файл пуст.');
    }
    if (bytes.length > maxBytes) {
      throw const FormatException('Фон должен быть не больше 30 МБ.');
    }
    final extension = _detectImageExtension(bytes);
    if (extension == null) {
      throw const FormatException('Поддерживаются PNG, JPEG, WebP и GIF.');
    }
    return AppBackgroundSelection(
      bytes: bytes,
      extension: extension,
      originalName: originalName,
    );
  }
}

class AppAppearanceChange {
  const AppAppearanceChange({
    required this.preferences,
    this.background,
    this.removeBackground = false,
  });

  final AppAppearancePreferences preferences;
  final AppBackgroundSelection? background;
  final bool removeBackground;
}

Future<AppBackgroundSelection?> pickAppBackground() async {
  final result = await FilePicker.pickFiles(
    dialogTitle: 'Выбрать фон Chronicle',
    type: FileType.custom,
    allowedExtensions: const <String>['png', 'jpg', 'jpeg', 'webp', 'gif'],
    lockParentWindow: true,
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.single;
  if (file.size > AppBackgroundSelection.maxBytes) {
    throw const FormatException('Фон должен быть не больше 30 МБ.');
  }
  final bytes = await file.readAsBytes();
  return AppBackgroundSelection.validate(bytes: bytes, originalName: file.name);
}

class AppAppearanceStore {
  static const String preferencesKey = 'chronicle_appearance_v1';
  static const String backgroundDirectoryName = 'appearance_backgrounds';

  Future<AppAppearancePreferences> load() async {
    final preferences = await SharedPreferences.getInstance();
    return decode(preferences.getString(preferencesKey));
  }

  Future<void> save(AppAppearancePreferences value) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(preferencesKey, encode(value));
    if (!saved) {
      throw StateError('Не удалось сохранить оформление Chronicle.');
    }
  }

  Future<Directory> backgroundDirectory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      path.join(support.path, backgroundDirectoryName),
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<File?> backgroundFileFor(AppAppearancePreferences value) async {
    final fileName = value.backgroundFileName;
    if (fileName == null || path.basename(fileName) != fileName) return null;
    final directory = await backgroundDirectory();
    final file = File(path.join(directory.path, fileName));
    return await file.exists() ? file : null;
  }

  Future<AppAppearancePreferences> saveChange(
    AppAppearanceChange change,
  ) async {
    final old = await load();
    var next = change.preferences;
    final directory = await backgroundDirectory();
    File? newlyWrittenFile;
    String? oldBackgroundToDelete;

    if (change.removeBackground) {
      oldBackgroundToDelete = old.backgroundFileName;
      next = next.copyWith(
        clearBackgroundFileName: true,
        backgroundRevision: old.backgroundRevision + 1,
      );
    } else if (change.background != null) {
      final selected = change.background!;
      final fileName =
          'background_${DateTime.now().microsecondsSinceEpoch}'
          '.${selected.extension}';
      newlyWrittenFile = File(path.join(directory.path, fileName));
      await newlyWrittenFile.writeAsBytes(selected.bytes, flush: true);
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

    try {
      await save(next);
    } on Object {
      if (newlyWrittenFile != null) {
        try {
          if (await newlyWrittenFile.exists()) {
            await newlyWrittenFile.delete();
          }
        } on FileSystemException {
          // Best-effort cleanup must not mask the preference write error.
        }
      }
      rethrow;
    }

    if (oldBackgroundToDelete != null &&
        oldBackgroundToDelete != next.backgroundFileName) {
      await _deleteManagedBackground(oldBackgroundToDelete, directory);
    }
    return next;
  }

  static String encode(AppAppearancePreferences value) {
    return jsonEncode(value.toJson());
  }

  static AppAppearancePreferences decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return AppAppearancePreferences.defaults();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return AppAppearancePreferences.defaults();
      return AppAppearancePreferences.fromJson(<String, Object?>{
        for (final entry in decoded.entries) entry.key.toString(): entry.value,
      });
    } on Object {
      return AppAppearancePreferences.defaults();
    }
  }

  Future<void> _deleteManagedBackground(
    String fileName,
    Directory directory,
  ) async {
    if (path.basename(fileName) != fileName) return;
    final file = File(path.join(directory.path, fileName));
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // A stale managed background is harmless.
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
