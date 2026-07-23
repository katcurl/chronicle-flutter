import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'note_home_preferences.dart';

class NoteHomePreferencesStore {
  static const String preferencesKey = 'chronicle_note_home_preferences_v1';

  Future<NoteHomePreferences> load() async {
    final preferences = await SharedPreferences.getInstance();
    return decode(preferences.getString(preferencesKey));
  }

  Future<void> save(NoteHomePreferences value) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(preferencesKey, encode(value));
    if (!saved) {
      throw StateError('Не удалось сохранить стартовую страницу заметок.');
    }
  }

  static String encode(NoteHomePreferences value) {
    return jsonEncode(value.toJson());
  }

  static NoteHomePreferences decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return NoteHomePreferences.defaults();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return NoteHomePreferences.defaults();
      return NoteHomePreferences.fromJson(<String, Object?>{
        for (final entry in decoded.entries) entry.key.toString(): entry.value,
      });
    } on Object {
      return NoteHomePreferences.defaults();
    }
  }
}
