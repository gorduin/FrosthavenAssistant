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
String trLootCards(int n) => _hu ? '$n lap' : '$n card${n == 1 ? '' : 's'}';
String trServerOn(String ip, String port) => _hu
    ? 'A szerver fut. A telefonos X-haven Assistantben csatlakozz ide: $ip, port $port'
    : 'Server running. In the X-haven Assistant phone app connect to $ip, port $port';
String trSummonColor(String c) {
  const hu = {'blue': 'Kék', 'green': 'Zöld', 'yellow': 'Sárga', 'orange': 'Narancs'};
  const en = {'blue': 'Blue', 'green': 'Green', 'yellow': 'Yellow', 'orange': 'Orange'};
  return (_hu ? hu[c] : en[c]) ?? c;
}
String trCompletedCount(int n) => _hu ? '$n teljesítve' : '$n completed';
String trUnlockedCount(int n) => _hu ? '$n feloldva' : '$n unlocked';
String trAddedToGame(int n) =>
    _hu ? '$n karakter került a játékba' : '$n character(s) added to the game';
String trSavedToParty(int n) => _hu
    ? 'Csapat mentve ($n új tag)'
    : 'Party saved ($n new member${n == 1 ? '' : 's'})';
String trPhones(int n) => _hu ? '$n telefon csatlakozva' : '$n phone${n == 1 ? '' : 's'} connected';
String trLoadedParty(int added, int updated) => _hu
    ? '$added új karakter, $updated frissítve (szint, név)'
    : '$added added, $updated updated (level, name)';
String trLeft(int n) => _hu ? 'még $n' : '$n left';
String trInDeck(int left) => _hu ? '$left lap a pakliban' : '$left in deck';

const Map<String, (String, String)> _strings = {
  'customScenario': ('Egyéni', 'Custom'),
  'customScenarioSub': ('üres küldetés', 'empty scenario'),
  'scenarioLevel': ('Küldetésszint', 'Scenario level'),
  'difficulty': ('Nehézség', 'Difficulty'),
  'solo': ('Egyjátékos', 'Solo'),
  'autoLevel': ('Automatikus szint', 'Automatic level'),
  'campaign': ('Kampány', 'Campaign'),
  'scenario': ('Küldetés', 'Scenario'),
  'scenarioMenu': ('Küldetés és szint', 'Scenario and level'),
  'currentScenario': ('Jelenleg', 'Current'),
  'skip': ('Kihagyás', 'Skip'),
  'done': ('Kész', 'Done'),
  'placeStandees': ('Tedd fel a táblára', 'Place on the board'),
  'pickStandees': ('Válaszd ki, melyik számú standee kerül fel', 'Pick the standee numbers to place'),
  'escortObjective': ('Kísérő és cél', 'Escort and objective'),
  'edition': ('Kiadás', 'Edition'),
  'showHiddenClasses': ('Zárt kasztok is', 'Show locked classes'),
  'alreadyAdded': ('már játékban', 'already in game'),
  'classes': ('Kasztok', 'Classes'),
  'addCharacter': ('Karakter hozzáadása', 'Add character'),
  'addCharacterSub': ('OK a kasztra, utána a szint', 'OK on a class, then pick the level'),
  'chooseLevel': ('Válassz szintet', 'Choose level'),
  'removeCharacterQ': ('Eltávolítod a karaktert?', 'Remove the character?'),
  'remove': ('Eltávolítás', 'Remove'),
  'showBosses': ('Főellenségek', 'Bosses'),
  'showSpecial': ('Különleges szörnyek', 'Special monsters'),
  'asAlly': ('Szövetségesként', 'As ally'),
  'monsters': ('Szörnyek', 'Monsters'),
  'addMonster': ('Szörny hozzáadása', 'Add monster'),
  'addMonsterSub': ('OK a szörnyre, utána a standee-k', 'OK on a monster, then its standees'),
  'removeMonsterQ': ('Eltávolítod a szörnyet?', 'Remove the monster?'),
  'deckMenuSub': ('Áldás, átok és −1 lapok a szörnyek paklijában', 'Bless, curse and −1 cards in the monster deck'),
  'bless': ('Áldás', 'Bless'),
  'curse': ('Átok', 'Curse'),
  'minusOnes': ('−1 lapok', '−1 cards'),
  'btnScenario': ('Küldetés', 'Scenario'),
  'btnAddChar': ('Karakter', 'Character'),
  'btnAddMonster': ('Szörny', 'Monster'),
  'btnDeck': ('Pakli', 'Deck'),
  'addStandees': ('Standee-k', 'Standees'),
  'monsterLevel': ('Szörny szintje', 'Monster level'),
  'removeCharacter': ('Karakter eltávolítása', 'Remove character'),
  'removeMonster': ('Szörny eltávolítása', 'Remove monster'),
  'characterLevel': ('Karakter szintje', 'Character level'),
  'loot': ('Zsákmány', 'Loot'),
  'lootSub': ('Húzáskor a soron lévő karakteré lesz a lap', 'A drawn card goes to the character whose turn it is'),
  'drawLoot': ('Zsákmánylap húzása', 'Draw loot card'),
  'lootOwner': ('Kié a legutóbbi lap?', 'Who gets the last card?'),
  'btnLoot': ('Zsákmány', 'Loot'),
  'btnSection': ('Szakasz', 'Section'),
  'sections': ('Szakaszok', 'Sections'),
  'sectionMenu': ('Szakasz hozzáadása', 'Add section'),
  'summonColor': ('Szín', 'Colour'),
  'summonNumber': ('Szám', 'Number'),
  'summons': ('Idézések', 'Summons'),
  'summonMenu': ('Idézés', 'Summon'),
  'addSummon': ('Idézés', 'Summon'),
  'note': ('Jegyzet', 'Note'),
  'editNote': ('Jegyzet', 'Note'),
  'textInputHint': (
    'Írj a billentyűzettel · Kész / Enter: mentés · üresen mentve törli · Vissza: mégse',
    'Type with the keyboard · Done / Enter: save · save empty to clear · Back: cancel'
  ),
  'rules': ('Játékszabályok', 'Rules'),
  'setInitRequired': ('Kezdeményezés kötelező', 'Initiative required'),
  'setExpireConditions': ('Állapotok lejárnak', 'Conditions expire'),
  'setAutoAddStandees': ('Standee-felrakás indításkor', 'Place standees at start'),
  'setAutoAddSpawns': ('Időzített érkezők', 'Timed spawns'),
  'setRandomStandees': ('Véletlen standee-számok', 'Random standee numbers'),
  'setNoCalculation': ('Nincs számolás a kártyán', 'No card calculations'),
  'setBattleGoals': ('Harci cél emlékeztető', 'Battle goal reminder'),
  'setReminders': ('Körszabály emlékeztetők', 'Round rule reminders'),
  'setHideLoot': ('Zsákmánypakli elrejtése', 'Hide loot deck'),
  'setCustomContent': ('Egyéni tartalom', 'Custom content'),
  'network': ('Hálózat', 'Network'),
  'startServer': ('Szerver indítása', 'Start server'),
  'stopServer': ('Szerver fut · leállítás', 'Server running · stop'),
  'serverOffHint': (
    'Szerverként a telefonok is követhetik és vezérelhetik a játékot.',
    'As a server, phones can follow and control the game too.'
  ),
  'unlocked': ('feloldva', 'unlocked'),
  'completed': ('teljesítve', 'completed'),
  'newCampaign': ('Új kampány', 'New campaign'),
  'campaignNameQ': ('Mi legyen a kampány (csapat) neve?', 'Name of the campaign (party)?'),
  'chooseEdition': ('Melyik játékkal játszotok?', 'Which game are you playing?'),
  'campaigns': ('Kampányok', 'Campaigns'),
  'noCampaigns': ('Még nincs kampány. Hozz létre egyet!', 'No campaigns yet. Create one!'),
  'noCampaign': ('Kampány nélkül', 'No campaign'),
  'markScenarios': ('Küldetések jelölése', 'Mark scenarios'),
  'rename': ('Átnevezés', 'Rename'),
  'delete': ('Törlés', 'Delete'),
  'activeCampaign': ('Aktív kampány', 'Active campaign'),
  'campaignMenu': ('Kampány', 'Campaign'),
  'campaignMenuSub': (
    'A teljesített és feloldott küldetések és a csapat kampányonként mentődnek',
    'Completed and unlocked scenarios and the party are saved per campaign'
  ),
  'deleteCampaignQ': ('Törlöd a kampányt?', 'Delete the campaign?'),
  'progressHint': (
    'OK: jelöletlen → feloldva → teljesítve',
    'OK: none → unlocked → completed'
  ),
  'startCampaign': ('Kampány indítása', 'Start a campaign'),
  'markCompleted': ('Küldetés teljesítve', 'Scenario completed'),
  'markedCompleted': ('Teljesítve', 'Completed'),
  'party': ('Csapat', 'Party'),
  'partySub': (
    'A kampány karakterei: név, szint és összesített tapasztalat',
    'The campaign characters: name, level and total experience'
  ),
  'partyEmpty': (
    'Még üres. Add hozzá a most játszó karaktereket: Mentés a játékból.',
    'Empty. Add the characters playing now: Save from game.'
  ),
  'partyMembers': ('Tagok', 'Members'),
  'loadParty': ('Betöltés a játékba', 'Load into game'),
  'saveParty': ('Mentés a játékból', 'Save from game'),
  'creditXp': ('Küldetés TP jóváírása', 'Credit scenario XP'),
  'xpCredited': ('TP jóváírva', 'XP credited'),
  'noPlayers': ('Nincs játszó karakter', 'No characters playing'),
  'partyHint': (
    'A „Küldetés teljesítve” gomb a TP-t is jóváírja. Bukott küldetésnél a „Küldetés TP jóváírása” gombbal teheted meg.',
    '“Scenario completed” also credits XP. After a lost scenario use “Credit scenario XP”.'
  ),
  'removeFromParty': ('Eltávolítás a csapatból', 'Remove from party'),
  'phones': ('Telefonok', 'Phones'),
  'phonesOn': ('Telefonos kapcsolat be', 'Phone access on'),
  'phonesOff': ('Telefonos kapcsolat ki', 'Phone access off'),
  'showQr': ('QR-kód megjelenítése', 'Show QR code'),
  'qrSub': (
    'Mindenki a saját karakterét kezelheti a telefonján, telepítés nélkül',
    'Everyone can manage their own character on their phone, no install'
  ),
  'qrStep1': ('1. Csatlakozz ugyanarra a wifire.', '1. Join the same Wi-Fi.'),
  'qrStep2': ('2. Nyisd meg a Kamerát, és irányítsd a kódra.', '2. Open the Camera and point it at the code.'),
  'qrStep3': ('3. Koppints a linkre, és válaszd ki a karaktered.', '3. Tap the link and pick your character.'),
  'newMember': ('Új tag', 'New member'),
  'partyUpToDate': ('A csapat már megegyezik a játékkal', 'The party already matches the game'),
  'saveChangesQ': ('Ezek változnak a csapatban:', 'These will change in the party:'),
  'save': ('Mentés', 'Save'),
  'xpTotal': ('össz.', 'total'),
  'digitStepperHint': ('◀ ▶ ±1 · OK: számjegyenként', '◀ ▶ ±1 · OK: digit by digit'),
  'digitEditHint': (
    '◀ ▶ helyiérték · ▲ ▼ számjegy · OK kész',
    '◀ ▶ place · ▲ ▼ digit · OK done'
  ),
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
    'Még nincs karakter és szörny. Lent: Küldetés, + Karakter, + Szörny.',
    'No characters or monsters yet. Below: Scenario, + Character, + Monster.'
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
    'Előbb adj hozzá karaktert (lent: + Karakter).',
    'Add characters first (below: + Character).'
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
