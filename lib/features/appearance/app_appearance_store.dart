import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_appearance.dart';

class AppAppearanceStore {
  static const String preferencesKey = 'chronicle_appearance_v1';

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
        for (final entry in decoded.entries)
          entry.key.toString(): entry.value,
      });
    } on Object {
      return AppAppearancePreferences.defaults();
    }
  }
}
