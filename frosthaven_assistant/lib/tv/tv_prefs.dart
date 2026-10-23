import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TV UI preferences (stored on the device, separate from the game settings).
class TvPrefs {
  static const _hideKey = 'tv_hide_empty_monsters';
  static const _cardsKey = 'tv_hide_monster_cards';

  /// House rule: a monster's ability card stays hidden until its turn.
  static final hideMonsterCards = ValueNotifier<bool>(true);

  /// Show only the monsters that have standees on the table, so the list
  /// does not reveal which monsters come in later rooms.
  static final hideEmptyMonsters = ValueNotifier<bool>(true);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      hideEmptyMonsters.value = prefs.getBool(_hideKey) ?? true;
      hideMonsterCards.value = prefs.getBool(_cardsKey) ?? true;
    } catch (_) {}
  }

  static Future<void> setHideMonsterCards(bool v) async {
    hideMonsterCards.value = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_cardsKey, v);
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
