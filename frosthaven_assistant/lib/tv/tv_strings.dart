import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Resource/enums.dart';

/// Hungarian / English strings of the TV UI. Game content (monster, class and
/// card names) stays as in the game data; only the app chrome is translated.
class TvLang {
  static const _prefKey = 'tv_lang';
  static final current = ValueNotifier<String>('hu');

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_prefKey);
      if (v == 'hu' || v == 'en') current.value = v!;
    } catch (_) {
      // first run / storage unavailable: keep the default
    }
  }

  static Future<void> set(String lang) async {
    current.value = lang;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, lang);
    } catch (_) {}
  }
}

bool get _hu => TvLang.current.value == 'hu';

String tr(String key) {
  final entry = _strings[key];
  if (entry == null) return key;
  return _hu ? entry.$1 : entry.$2;
}

/// "3. szint" / "Level 3"
String trLevel(int n) => _hu ? '$n. szint' : 'Level $n';
String trStandees(int n) => _hu ? '$n standee' : '$n standee${n == 1 ? '' : 's'}';
String trPlayers(int n) => _hu ? '$n játékos' : '$n player${n == 1 ? '' : 's'}';
String trCardsLeft(int n) => _hu ? '$n lap van hátra' : '$n cards left';
String trStandeeNr(int n) => _hu ? '$n-es standee' : 'standee $n';
String trInDeck(int left) => _hu ? '$left lap a pakliban' : '$left in deck';

const Map<String, (String, String)> _strings = {
  'round': ('kör', 'round'),
  'init': ('kezd.', 'init.'),
  'level': ('Szint', 'Level'),
  'selected': ('Kijelölve', 'Selected'),
  'abilityCard': ('képességkártya', 'ability card'),
  'monsterModDeck': ('Szörny módosító pakli', 'Monster modifier deck'),
  'discarded': ('eldobott', 'discarded'),
  'draw': ('Húzás', 'Draw'),
  'nextRound': ('Kör vége', 'Next round'),
  'drawModifier': ('Módosító húzása', 'Draw modifier'),
  'phaseInit': ('Kezdeményezés választása', 'Choose initiative'),
  'phasePlay': ('Körök folynak', 'Playing turns'),
  'normal': ('Normál', 'Normal'),
  'elite': ('Elit', 'Elite'),
  'boss': ('Főellenség', 'Boss'),
  'summon': ('Idézett', 'Summon'),
  'hp': ('ÉP', 'HP'),
  'xp': ('TP', 'XP'),
  'noCard': ('Húzás után látszik', 'Shown after drawing'),
  'notOnBoard': ('Ebben a körben nem aktív', 'Not active this round'),
  'noMonsters': ('Nincs szörny a küldetésben', 'No monsters in the scenario'),
  'emptyList': (
    'Még nincs karakter és szörny. A ⚙ menüben a klasszikus nézetben adhatod hozzá őket.',
    'No characters or monsters yet. Add them in the classic view from the ⚙ menu.'
  ),
  'noStandees': ('nincs standee az asztalon', 'no standees on the table'),
  'keyHp': ('életerő −1 / +1', 'health −1 / +1'),
  'keyOk': ('állapotok és műveletek', 'conditions and actions'),
  'keyLongOk': ('hosszan: átrendezés', 'hold: reorder'),
  'keyUpDown': ('következő figura', 'next figure'),
  'hint': (
    '◀ ▶ életerő · OK menü · OK hosszan átrendez · Vissza: kilépés',
    '◀ ▶ health · OK menu · hold OK reorder · Back: exit'
  ),
  'hintHeader': (
    '◀ ▶ lépés · OK: elem be/ki · OK hosszan: félig erős',
    '◀ ▶ move · OK: element on/off · hold OK: waning'
  ),
  'hintFooter': ('◀ ▶ lépés · OK: végrehajtás', '◀ ▶ move · OK: run'),
  'reorderHint': (
    'Átrendezés: ▲ ▼ mozgat · OK vagy Vissza: kész',
    'Reorder: ▲ ▼ move · OK or Back: done'
  ),
  'reordering': ('átrendezés', 'reordering'),
  'undo': ('Visszavonás', 'Undo'),
  'redo': ('Újra', 'Redo'),
  'settings': ('Beállítások', 'Settings'),
  'language': ('Nyelv', 'Language'),
  'classicView': ('Klasszikus nézet', 'Classic view'),
  'classicHint': (
    'A klasszikus nézetből a Vissza gombbal jössz vissza.',
    'Press Back to return from the classic view.'
  ),
  'close': ('Bezárás', 'Close'),
  'exitTitle': ('Kilépsz az alkalmazásból?', 'Exit the app?'),
  'exitYes': ('Kilépés', 'Exit'),
  'cancel': ('Mégse', 'Cancel'),
  'initiative': ('Kezdeményezés', 'Initiative'),
  'health': ('Életerő', 'Health'),
  'maxHealth': ('Max. életerő', 'Max health'),
  'experience': ('Tapasztalat', 'Experience'),
  'conditions': ('Állapotok', 'Conditions'),
  'actions': ('Műveletek', 'Actions'),
  'turnDone': ('Köre kész', 'Turn done'),
  'stepperHint': ('◀ ▶ érték · tartva gyorsul', '◀ ▶ value · hold to speed up'),
  'immune': ('immunis', 'immune'),
  'blockedNoChars': (
    'Előbb adj hozzá karaktert (klasszikus nézet, ⚙ menü).',
    'Add characters first (classic view, ⚙ menu).'
  ),
  'blockedInit': (
    'Előbb add meg minden karakter kezdeményezését (OK a karakteren).',
    'Set every character\'s initiative first (OK on the character).'
  ),
  'nothingToUndo': ('Nincs mit visszavonni', 'Nothing to undo'),
  'undone': ('Visszavonva', 'Undone'),
  'shuffle': ('keverés', 'shuffle'),
  'noModCards': ('Még nem húztál', 'Nothing drawn yet'),
};

const Map<Condition, (String, String)> _conditionNames = {
  Condition.stun: ('Kábítás', 'Stun'),
  Condition.immobilize: ('Mozgásképtelen', 'Immobilize'),
  Condition.disarm: ('Lefegyverzés', 'Disarm'),
  Condition.wound: ('Sebesülés', 'Wound'),
  Condition.wound2: ('Sebesülés 2', 'Wound 2'),
  Condition.muddle: ('Zavarodottság', 'Muddle'),
  Condition.poison: ('Mérgezés', 'Poison'),
  Condition.poison2: ('Mérgezés 2', 'Poison 2'),
  Condition.poison3: ('Mérgezés 3', 'Poison 3'),
  Condition.poison4: ('Mérgezés 4', 'Poison 4'),
  Condition.bane: ('Végzet', 'Bane'),
  Condition.brittle: ('Törékenység', 'Brittle'),
  Condition.chill: ('Fagy', 'Chill'),
  Condition.infect: ('Fertőzés', 'Infect'),
  Condition.impair: ('Hátráltatás', 'Impair'),
  Condition.rupture: ('Felhasadás', 'Rupture'),
  Condition.plague: ('Pestis', 'Plague'),
  Condition.strengthen: ('Erősítés', 'Strengthen'),
  Condition.invisible: ('Láthatatlanság', 'Invisible'),
  Condition.regenerate: ('Regenerálódás', 'Regenerate'),
  Condition.ward: ('Oltalom', 'Ward'),
  Condition.dodge: ('Kitérés', 'Dodge'),
  Condition.safeguard: ('Védettség', 'Safeguard'),
  Condition.shield: ('Pajzs', 'Shield'),
  Condition.retaliate: ('Visszavágás', 'Retaliate'),
};

String trCondition(Condition c) {
  final e = _conditionNames[c];
  if (e == null) return c.getName();
  return _hu ? e.$1 : e.$2;
}

const Map<Elements, (String, String)> _elementNames = {
  Elements.fire: ('Tűz', 'Fire'),
  Elements.ice: ('Jég', 'Ice'),
  Elements.air: ('Levegő', 'Air'),
  Elements.earth: ('Föld', 'Earth'),
  Elements.light: ('Fény', 'Light'),
  Elements.dark: ('Sötétség', 'Dark'),
};

String trElement(Elements e) {
  final n = _elementNames[e];
  if (n == null) return e.name;
  return _hu ? n.$1 : n.$2;
}
