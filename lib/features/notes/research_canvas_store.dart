import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'research_canvas_models.dart';

class ResearchCanvasStore {
  const ResearchCanvasStore();

  static const String preferencesKey = 'chronicle_research_canvases_v1';

  Future<ResearchCanvasPreferences> load() async {
    final preferences = await SharedPreferences.getInstance();
    return decode(preferences.getString(preferencesKey));
  }

  Future<void> save(ResearchCanvasPreferences value) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(preferencesKey, encode(value));
    if (!saved) {
      throw StateError('Не удалось сохранить исследовательские карты.');
    }
  }

  static String encode(ResearchCanvasPreferences value) {
    return jsonEncode(value.toJson());
  }

  static ResearchCanvasPreferences decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return ResearchCanvasPreferences.defaults();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return ResearchCanvasPreferences.defaults();
      return ResearchCanvasPreferences.fromJson(<String, Object?>{
        for (final entry in decoded.entries) entry.key.toString(): entry.value,
      });
    } on Object {
      return ResearchCanvasPreferences.defaults();
    }
  }
}
