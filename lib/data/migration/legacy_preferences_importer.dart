import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_models.dart';

class LegacyPreferencesImporter {
  static const _legacyKeys = <String>[
    'chronicle_data_v5',
    'chronicle_data_v4',
  ];

  Future<AppData?> read() async {
    final preferences = await SharedPreferences.getInstance();
    for (final key in _legacyKeys) {
      final raw = preferences.getString(key);
      if (raw == null || raw.trim().isEmpty) continue;
      try {
        return AppData.decode(raw);
      } on Object {
        continue;
      }
    }
    return null;
  }
}
