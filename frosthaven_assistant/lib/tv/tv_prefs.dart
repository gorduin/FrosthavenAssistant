import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TV UI preferences (stored on the device, separate from the game settings).
class TvPrefs {
  static const _hideKey = 'tv_hide_empty_monsters';

  /// Show only the monsters that have standees on the table, so the list
  /// does not reveal which monsters come in later rooms.
  static final hideEmptyMonsters = ValueNotifier<bool>(true);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      hideEmptyMonsters.value = prefs.getBool(_hideKey) ?? true;
    } catch (_) {}
  }

  static Future<void> setHideEmptyMonsters(bool v) async {
    hideEmptyMonsters.value = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hideKey, v);
    } catch (_) {}
  }
}
