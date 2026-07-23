import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'note_editor_profile.dart';

class NoteEditorPreferencesStore {
  static const String preferencesKey = 'chronicle_note_editor_profiles_v1';

  Future<NoteEditorPreferences> load() async {
    final preferences = await SharedPreferences.getInstance();
    return decode(preferences.getString(preferencesKey));
  }

  Future<void> save(NoteEditorPreferences value) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(preferencesKey, encode(value));
    if (!saved) {
      throw StateError('Не удалось сохранить профили редактора.');
    }
  }

  static String encode(NoteEditorPreferences value) {
    return jsonEncode(value.toJson());
  }

  static NoteEditorPreferences decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return NoteEditorPreferences.defaults();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return NoteEditorPreferences.defaults();
      return NoteEditorPreferences.fromJson(<String, Object?>{
        for (final entry in decoded.entries)
          entry.key.toString(): entry.value,
      });
    } on Object {
      return NoteEditorPreferences.defaults();
    }
  }
}
