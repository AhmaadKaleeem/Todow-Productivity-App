import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:todow/domain/models/focus_activity_template.dart';

class FocusActivityStore {
  static const _storageKey = 'focus_activity_settings_v1';

  Future<FocusActivitySettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_storageKey);
    if (value == null) return const FocusActivitySettings();
    try {
      return FocusActivitySettings.fromJson(
        Map<String, Object?>.from(jsonDecode(value) as Map),
      );
    } on FormatException {
      return const FocusActivitySettings();
    } on TypeError {
      return const FocusActivitySettings();
    }
  }

  Future<void> save(FocusActivitySettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, jsonEncode(settings.toJson()));
  }
}
