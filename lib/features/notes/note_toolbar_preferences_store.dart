import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'note_toolbar_profile.dart';

class NoteToolbarPreferencesStore {
  static const String preferencesKey = 'chronicle_note_toolbar_profiles_v1';

  Future<NoteToolbarPreferences> load() async {
    final preferences = await SharedPreferences.getInstance();
    return decode(preferences.getString(preferencesKey));
  }

  Future<void> save(NoteToolbarPreferences value) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(preferencesKey, encode(value));
    if (!saved) {
      throw StateError('Не удалось сохранить панели быстрых действий.');
    }
  }

  static String encode(NoteToolbarPreferences value) {
    return jsonEncode(value.toJson());
  }

  static NoteToolbarPreferences decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return NoteToolbarPreferences.defaults();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return NoteToolbarPreferences.defaults();
      return NoteToolbarPreferences.fromJson(<String, Object?>{
        for (final entry in decoded.entries)
          entry.key.toString(): entry.value,
      });
    } on Object {
      return NoteToolbarPreferences.defaults();
    }
  }
}
