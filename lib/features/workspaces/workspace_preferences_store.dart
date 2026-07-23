import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'workspace_profile.dart';

class WorkspacePreferencesStore {
  static const String preferencesKey = 'chronicle_workspaces_v1';

  Future<WorkspacePreferences> load() async {
    final preferences = await SharedPreferences.getInstance();
    return decode(preferences.getString(preferencesKey));
  }

  Future<void> save(WorkspacePreferences value) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(preferencesKey, encode(value));
    if (!saved) {
      throw StateError('Не удалось сохранить рабочие пространства.');
    }
  }

  static String encode(WorkspacePreferences value) {
    return jsonEncode(value.toJson());
  }

  static WorkspacePreferences decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return WorkspacePreferences.defaults();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return WorkspacePreferences.defaults();
      return WorkspacePreferences.fromJson(<String, Object?>{
        for (final entry in decoded.entries) entry.key.toString(): entry.value,
      });
    } on Object {
      return WorkspacePreferences.defaults();
    }
  }
}
