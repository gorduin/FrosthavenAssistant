import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../Model/character_class.dart';
import '../Model/monster.dart';
import '../Model/room.dart';
import '../Resource/commands/add_character_command.dart';
import '../Resource/commands/add_monster_command.dart';
import '../Resource/commands/add_standee_command.dart';
import '../Resource/commands/amd_add_minus_one_command.dart';
import '../Resource/commands/amd_remove_minus_1_command.dart';
import '../Resource/commands/change_stat_commands/change_bless_command.dart';
import '../Resource/commands/change_stat_commands/change_curse_command.dart';
import '../Resource/commands/remove_character_command.dart';
import '../Resource/commands/remove_monster_command.dart';
import '../Resource/commands/set_auto_level_adjust_command.dart';
import '../Resource/commands/set_campaign_command.dart';
import '../Resource/commands/set_character_level_command.dart';
import '../Resource/commands/set_difficulty_command.dart';
import '../Resource/commands/set_level_command.dart';
import '../Resource/commands/set_scenario_command.dart';
import '../Resource/commands/set_solo_command.dart';
import '../Resource/enums.dart';
import '../Resource/game_data.dart';
import '../Resource/game_methods.dart';
import '../Resource/settings.dart';
import '../Resource/state/game_state.dart';
import '../services/service_locator.dart';
import 'tv_menu.dart';
import 'tv_model.dart';
import 'tv_strings.dart';

// ======================================================================
// Scenario, level, difficulty
// ======================================================================

double? _scenarioNr(String scenario) {
  if (scenario.length < 2) return null;
  String nr = scenario.substring(1).split(' ').first;
  if (nr.endsWith('A')) nr = '${nr.substring(0, nr.length - 1)}.1';
  if (nr.endsWith('B')) nr = '${nr.substring(0, nr.length - 1)}.2';
  return double.tryParse(nr);
}

/// Scenario list of a campaign, ordered like the original menu.
List<String> scenariosOf(GameState gs, String campaign) {
  final gd = getIt<GameData>();
  final settings = getIt<Settings>();
  final list = gd.modelData.value[campaign]?.scenarios.keys.toList() ?? [];
  if (campaign == 'Solo' || campaign == 'Trail of Ashes') {
    if (!gs.unlockedClasses.contains('Bladeswarm')) {
      list.removeWhere((s) => s.contains('Bladeswarm'));
    }
    if (!gs.unlockedClasses.contains('Vanquisher')) {
      list.removeWhere((s) => s.contains('Vanquisher'));
    }
  }
  if (campaign == 'Solo' && !settings.showCustomContent.value) {
    list.removeWhere((scenario) {
      final first = scenario.split(':').first;
      final space = first.indexOf(' ');
      if (space < 0) return false;
      final characterName = first.substring(space + 1).split('/').first;
      return gd.modelData.value.values.any((c) =>
          GameMethods.isCustomCampaign(c.edition) &&
          c.characters.any((ch) => ch.name == characterName));
    });
  }
  list.sort((a, b) {
    final an = _scenarioNr(a);
    final bn = _scenarioNr(b);
    if (an != null && bn != null) return an.compareTo(bn);
    return a.compareTo(b);
  });
  if (list.remove('#Random Dungeon')) list.insert(0, '#Random Dungeon');
  if (campaign != 'Solo') list.insert(0, 'custom');
  return list;
}

List<String> _campaignsWithScenarios() {
  final gd = getIt<GameData>();
  final custom = getIt<Settings>().showCustomContent.value;
  return gd.editions
      .where((e) =>
          (gd.modelData.value[e]?.scenarios.isNotEmpty ?? false) &&
          (custom || !GameMethods.isCustomCampaign(e)))
      .toList();
}

(String, String) _scenarioTitle(String s) {
  if (s == 'custom') return (tr('customScenario'), tr('customScenarioSub'));
  if (s.startsWith('#')) {
    final space = s.indexOf(' ');
    if (space > 0) return (s.substring(0, space), s.substring(space + 1));
    return (s.substring(1), '');
  }
  return (s, '');
}

Future<void> showScenarioMenu(BuildContext context, GameState gs) {
  (int, int)? scenarioStart;
  List<TvMenuRow> rows() {
    final out = <TvMenuRow>[];
    out.add(TvButtonsRow([
      for (int l = 0; l <= 7; l++)
        TvMenuButton(
          text: '$l',
          active: gs.level.value == l,
          onPressed: () => gs.action(SetLevelCommand(l, null)),
        ),
    ], label: tr('scenarioLevel')));
    out.add(TvButtonsRow([
      for (int d = -1; d <= 3; d++)
        TvMenuButton(
          text: d > 0 ? '+$d' : '$d',
          active: gs.difficulty.value == d,
          onPressed: () => gs.action(SetDifficultyCommand(d, gameState: gs)),
        ),
    ], label: tr('difficulty')));
    out.add(TvButtonsRow([
      TvMenuButton(
        text: tr('solo'),
        active: gs.solo.value,
        onPressed: () => gs.action(SetSoloCommand(!gs.solo.value)),
      ),
      TvMenuButton(
        text: tr('autoLevel'),
        active: gs.autoScenarioLevel.value,
        onPressed: () => gs.action(SetAutoLevelAdjustCommand(
            !gs.autoScenarioLevel.value,
            gameState: gs)),
      ),
    ]));
    final campaign = gs.currentCampaign.value;
    out.addAll(tvGrid([
      for (final c in _campaignsWithScenarios())
        TvMenuButton(
          text: c,
          active: c == campaign,
          onPressed: c == campaign
              ? () {}
              : () => gs.action(SetCampaignCommand(c)),
        ),
    ], 4, label: tr('campaign')));
    final current = gs.scenario.value;
    final scenarios = scenariosOf(gs, campaign);
    final idx = scenarios.indexOf(current);
    scenarioStart = idx < 0
        ? (out.length, 0)
        : (out.length + idx ~/ 4, idx % 4);
    out.addAll(tvGrid([
      for (final s in scenarios)
        () {
          final t = _scenarioTitle(s);
          return TvMenuButton(
            text: t.$1,
            subtitle: t.$2,
            active: s == current,
            closes: true,
            onPressed: () =>
                gs.action(SetScenarioCommand(s, false, gameState: gs)),
          );
        }(),
    ], 4, label: tr('scenario'), style: TvRowStyle.tiles));
    return out;
  }

  rows();
  return showTvMenu<void>(
    context,
    title: tr('scenarioMenu'),
    subtitle: gs.scenario.value.isEmpty
        ? null
        : '${tr('currentScenario')}: ${gs.scenario.value}',
    rows: rows,
    rebuildOn: gs.commandIndex,
    // start on the first scenario: picking one is the usual reason to come here
    start: scenarioStart,
  );
}

// ======================================================================
// Auto / manual standees
// ======================================================================

/// Puts standees of [monster] on the table. With [normalQuota] /
/// [eliteQuota] (scenario start) the menu shows only the needed types and
/// closes once they are placed; without them it is a free picker.
Future<void> showStandeeMenu(BuildContext context, GameState gs, Monster monster,
    {int? normalQuota, int? eliteQuota}) {
  final isBoss = monster.type.levels.first.boss != null;
  final count = monster.type.count;
  final auto = normalQuota != null || eliteQuota != null;
  final startNormal = monster.monsterInstances
      .where((m) => m.type != MonsterType.elite)
      .length;
  final startElite =
      monster.monsterInstances.where((m) => m.type == MonsterType.elite).length;

  int addedOf(MonsterType type) {
    final now = monster.monsterInstances
        .where((m) => type == MonsterType.elite
            ? m.type == MonsterType.elite
            : m.type != MonsterType.elite)
        .length;
    return now - (type == MonsterType.elite ? startElite : startNormal);
  }

  bool allOut() => monster.monsterInstances.length >= count;

  int leftOf(MonsterType type) {
    final quota = type == MonsterType.elite ? eliteQuota : normalQuota;
    if (quota == null) return 0;
    return (quota - addedOf(type)).clamp(0, 99);
  }

  TvMenuRow numbers(MonsterType type, String label) {
    final used = monster.monsterInstances.map((m) => m.standeeNr).toSet();
    final full = auto && leftOf(type) == 0;
    return TvButtonsRow([
      for (int n = 1; n <= count; n++)
        TvMenuButton(
          text: '$n',
          active: monster.monsterInstances
              .any((m) => m.standeeNr == n && m.type == type),
          onPressed: used.contains(n) || full
              ? null
              : () => gs.action(AddStandeeCommand(
                  n, null, monster.id, type, false,
                  gameState: gs)),
        ),
    ], label: label);
  }

  List<TvMenuRow> rows() {
    final out = <TvMenuRow>[];
    if (isBoss) {
      out.add(numbers(MonsterType.boss, tr('boss')));
    } else if (auto) {
      if ((eliteQuota ?? 0) > 0) {
        out.add(numbers(MonsterType.elite,
            '${tr('elite')} · ${trLeft(leftOf(MonsterType.elite))}'));
      }
      if ((normalQuota ?? 0) > 0) {
        out.add(numbers(MonsterType.normal,
            '${tr('normal')} · ${trLeft(leftOf(MonsterType.normal))}'));
      }
    } else {
      out.add(numbers(MonsterType.normal, tr('normal')));
      out.add(numbers(MonsterType.elite, tr('elite')));
    }
    out.add(TvButtonsRow([
      TvMenuButton(
          text: auto ? tr('skip') : tr('done'),
          primary: !auto,
          closes: true,
          onPressed: () {}),
    ]));
    return out;
  }

  String? subtitle;
  if (auto) {
    final parts = <String>[
      if ((normalQuota ?? 0) > 0) '${normalQuota!} ${tr('normal').toLowerCase()}',
      if ((eliteQuota ?? 0) > 0) '${eliteQuota!} ${tr('elite').toLowerCase()}',
    ];
    subtitle = '${tr('placeStandees')}: ${parts.join(', ')}';
  } else {
    subtitle = tr('pickStandees');
  }

  return showTvMenu<void>(
    context,
    title: monster.type.display,
    subtitle: subtitle,
    image: monsterImagePath(monster),
    rows: rows,
    rebuildOn: gs.commandIndex,
    width: 1100,
    closeWhen: () {
      if (allOut()) return true;
      if (!auto || isBoss) return isBoss && auto && addedOf(MonsterType.boss) > 0;
      return leftOf(MonsterType.normal) == 0 && leftOf(MonsterType.elite) == 0;
    },
  );
}

/// The scenario start dialog sequence (one menu per monster type).
Future<void> runAutoAddStandees(
    BuildContext context, GameState gs, List<RoomMonsterData> data) async {
  final chars = GameMethods.getCurrentCharacterAmount().clamp(2, 4) - 2;
  for (final d in data) {
    final monster = gs.currentList
        .firstWhereOrNull((e) => e is Monster && e.id == d.name) as Monster?;
    if (monster == null) continue;
    int elite = d.elite.length > chars ? d.elite[chars] : 0;
    int normal = d.normal.length > chars ? d.normal[chars] : 0;
    final left = monster.type.count - monster.monsterInstances.length;
    if (left <= 0 || elite + normal == 0) continue;
    if (left < elite) {
      elite = left;
      normal = 0;
    } else if (left < elite + normal) {
      normal = left - elite;
    }
    if (!context.mounted) return;
    await showStandeeMenu(context, gs, monster,
        normalQuota: normal, eliteQuota: elite);
  }
}

// ======================================================================
// Characters
// ======================================================================

List<CharacterClass> _allClasses() {
  final gd = getIt<GameData>();
  final custom = getIt<Settings>().showCustomContent.value;
  final out = <CharacterClass>[];
  for (final c in gd.modelData.value.values) {
    out.addAll(c.characters);
  }
  out.removeWhere((c) =>
      (c.name == 'Bladeswarm' && c.edition == 'Gloomhaven') ||
      c.name == 'Vanquisher' ||
      (!custom && GameMethods.isCustomCampaign(c.edition)));
  return out;
}

String _editionLabel(String e) => e == 'na' ? tr('escortObjective') : e;

Future<void> showAddCharacterMenu(BuildContext context, GameState gs) {
  final all = _allClasses();
  final gd = getIt<GameData>();
  final editions = <String>[
    for (final e in gd.editions)
      if (all.any((c) => c.edition == e)) e,
  ];
  final campaign = gs.currentCampaign.value;
  if (editions.remove(campaign)) editions.insert(0, campaign);
  if (editions.remove('na')) editions.add('na');
  String edition = editions.isNotEmpty ? editions.first : 'na';
  bool showHidden = false;

  bool added(CharacterClass c) =>
      !GameMethods.isObjectiveOrEscort(c) &&
      GameMethods.getCurrentCharacters().any((e) => e.characterClass.id == c.id);

  void add(CharacterClass c) {
    String display = c.name;
    if (GameMethods.isObjectiveOrEscort(c)) {
      final n = gs.currentList
              .where((e) => e is Character && e.characterClass.name == c.name)
              .length +
          1;
      if (n > 1) display += ' $n';
    }
    final cmd = AddCharacterCommand(c.id, c.edition, display, 1);
    gs.action(cmd);
    final ch = cmd.character;
    if (ch != null && !GameMethods.isObjectiveOrEscort(c) && context.mounted) {
      showCharacterLevelMenu(context, gs, ch);
    }
  }

  int firstTileRow = 0;
  List<TvMenuRow> rows() {
    final unlocked = gs.unlockedClasses;
    final list = all.where((c) => c.edition == edition).toList()
      ..sort((a, b) {
        if (a.hidden != b.hidden) return a.hidden ? 1 : -1;
        return a.name.compareTo(b.name);
      });
    final out = <TvMenuRow>[];
    out.addAll(tvGrid([
      for (final e in editions)
        TvMenuButton(
          text: _editionLabel(e),
          active: e == edition,
          onPressed: () => edition = e,
        ),
    ], 4, label: tr('edition')));
    out.add(TvButtonsRow([
      TvMenuButton(
          text: tr('showHiddenClasses'),
          active: showHidden,
          onPressed: () => showHidden = !showHidden),
    ]));
    firstTileRow = out.length;
    out.addAll(tvGrid([
      for (final c in list)
        () {
          final locked = c.hidden && !unlocked.contains(c.id) && !showHidden;
          final isAdded = added(c);
          return TvMenuButton(
            text: locked ? '???' : c.name,
            icon: 'assets/images/class-icons/${c.name}.png',
            iconTint: locked || GameMethods.isObjectiveOrEscort(c) ? null : c.color,
            disabledNote: isAdded ? tr('alreadyAdded') : null,
            onPressed: locked || isAdded ? null : () => add(c),
          );
        }(),
    ], 6, label: tr('classes'), style: TvRowStyle.pictures));
    out.add(TvButtonsRow([
      TvMenuButton(text: tr('done'), primary: true, closes: true, onPressed: () {}),
    ]));
    return out;
  }

  return showTvMenu<void>(
    context,
    title: tr('addCharacter'),
    subtitle: tr('addCharacterSub'),
    rows: rows,
    rebuildOn: gs.commandIndex,
    start: (() {
      rows();
      return (firstTileRow, -1);
    })(),
  );
}

Future<void> showCharacterLevelMenu(
    BuildContext context, GameState gs, Character ch) {
  final current = ch.characterState.level.value;
  return showTvMenu<void>(
    context,
    title: ch.characterState.display.value,
    subtitle: tr('chooseLevel'),
    image: classIconPath(ch),
    imageTint: classTint(ch),
    width: 980,
    rows: () => [
      TvButtonsRow([
        for (int l = 1; l <= 9; l++)
          TvMenuButton(
            text: '$l',
            active: ch.characterState.level.value == l,
            closes: true,
            onPressed: () => gs.action(SetCharacterLevelCommand(l, ch.id)),
          ),
      ], label: tr('level')),
    ],
    rebuildOn: gs.commandIndex,
    start: (0, (current - 1).clamp(0, 8)),
  );
}

Future<void> confirmRemoveCharacter(
    BuildContext context, GameState gs, Character ch) {
  return showTvMenu<void>(
    context,
    title: tr('removeCharacterQ'),
    subtitle: ch.characterState.display.value,
    image: classIconPath(ch),
    imageTint: classTint(ch),
    width: 900,
    rows: () => [
      TvButtonsRow([
        TvMenuButton(text: tr('cancel'), closes: true, onPressed: () {}),
        TvMenuButton(
            text: tr('remove'),
            primary: true,
            closes: true,
            onPressed: () =>
                gs.action(RemoveCharacterCommand([ch], gameState: gs))),
      ]),
    ],
  );
}

// ======================================================================
// Monsters
// ======================================================================

Future<void> showAddMonsterMenu(BuildContext context, GameState gs) {
  final gd = getIt<GameData>();
  final custom = getIt<Settings>().showCustomContent.value;
  final all = <MonsterModel>[
    for (final c in gd.modelData.value.values) ...c.monsters.values,
  ];
  final editions = <String>[
    for (final e in gd.editions)
      if (e != 'na' &&
          (custom || !GameMethods.isCustomCampaign(e)) &&
          all.any((m) => m.edition == e))
        e,
  ];
  final campaign = gs.currentCampaign.value;
  if (editions.remove(campaign)) editions.insert(0, campaign);
  String edition = editions.isNotEmpty ? editions.first : '';
  bool showBoss = true;
  bool showSpecial = false;
  bool asAlly = false;

  bool isAdded(MonsterModel m) =>
      GameMethods.getCurrentMonsters().any((e) => e.id == m.name);

  void add(MonsterModel m) {
    gs.action(AddMonsterCommand(m.name, null, asAlly, gameState: gs));
    final monster = gs.currentList
        .firstWhereOrNull((e) => e is Monster && e.id == m.name) as Monster?;
    if (monster != null && context.mounted) {
      showStandeeMenu(context, gs, monster);
    }
  }

  int firstTileRow = 0;
  List<TvMenuRow> rows() {
    final list = all
        .where((m) =>
            m.edition == edition &&
            (showSpecial || !m.hidden) &&
            (showBoss || m.levels.first.boss == null))
        .toList()
      ..sort((a, b) {
        final ab = a.levels.first.boss != null;
        final bb = b.levels.first.boss != null;
        if (a.hidden != b.hidden) return a.hidden ? 1 : -1;
        if (ab != bb) return ab ? 1 : -1;
        return a.display.compareTo(b.display);
      });
    final out = <TvMenuRow>[];
    out.addAll(tvGrid([
      for (final e in editions)
        TvMenuButton(
          text: e,
          active: e == edition,
          onPressed: () => edition = e,
        ),
    ], 4, label: tr('edition')));
    out.add(TvButtonsRow([
      TvMenuButton(
          text: tr('showBosses'),
          active: showBoss,
          onPressed: () => showBoss = !showBoss),
      TvMenuButton(
          text: tr('showSpecial'),
          active: showSpecial,
          onPressed: () => showSpecial = !showSpecial),
      TvMenuButton(
          text: tr('asAlly'),
          active: asAlly,
          onPressed: () => asAlly = !asAlly),
    ]));
    firstTileRow = out.length;
    out.addAll(tvGrid([
      for (final m in list)
        TvMenuButton(
          text: m.display,
          subtitle: m.levels.first.boss != null ? tr('boss') : null,
          icon: 'assets/images/monsters/${m.gfx}.png',
          coverImage: true,
          disabledNote: isAdded(m) ? tr('alreadyAdded') : null,
          onPressed: isAdded(m) ? null : () => add(m),
        ),
    ], 6, label: tr('monsters'), style: TvRowStyle.pictures));
    out.add(TvButtonsRow([
      TvMenuButton(text: tr('done'), primary: true, closes: true, onPressed: () {}),
    ]));
    return out;
  }

  return showTvMenu<void>(
    context,
    title: tr('addMonster'),
    subtitle: tr('addMonsterSub'),
    rows: rows,
    rebuildOn: gs.commandIndex,
    start: (() {
      rows();
      return (firstTileRow, -1);
    })(),
  );
}

Future<void> confirmRemoveMonster(
    BuildContext context, GameState gs, Monster m) {
  return showTvMenu<void>(
    context,
    title: tr('removeMonsterQ'),
    subtitle: m.type.display,
    image: monsterImagePath(m),
    width: 900,
    rows: () => [
      TvButtonsRow([
        TvMenuButton(text: tr('cancel'), closes: true, onPressed: () {}),
        TvMenuButton(
            text: tr('remove'),
            primary: true,
            closes: true,
            onPressed: () =>
                gs.action(RemoveMonsterCommand([m], gameState: gs))),
      ]),
    ],
  );
}

// ======================================================================
// Monster modifier deck
// ======================================================================

Future<void> showDeckMenu(BuildContext context, GameState gs) {
  final deck = gs.modifierDeck;
  return showTvMenu<void>(
    context,
    title: tr('monsterModDeck'),
    subtitle: tr('deckMenuSub'),
    width: 1000,
    rebuildOn: gs.commandIndex,
    rows: () => [
      TvStepperRow(
        label: tr('bless'),
        min: 0,
        max: 10,
        value: () => deck.getRemovable('bless').value,
        onChange: (v) {
          final d = v - deck.getRemovable('bless').value;
          if (d == 0) return;
          gs.action(ChangeBlessCommand.deck(deck, gameState: gs)..setChange(d));
        },
      ),
      TvStepperRow(
        label: tr('curse'),
        min: 0,
        max: 10,
        value: () => deck.getRemovable('curse').value,
        onChange: (v) {
          final d = v - deck.getRemovable('curse').value;
          if (d == 0) return;
          gs.action(ChangeCurseCommand.deck(deck, gameState: gs)..setChange(d));
        },
      ),
      TvStepperRow(
        label: tr('minusOnes'),
        min: -6,
        max: 10,
        value: () => deck.addedMinusOnes.value,
        format: (v) => v > 0 ? '+$v' : '$v',
        onChange: (v) {
          final cur = deck.addedMinusOnes.value;
          if (v > cur) {
            gs.action(AmdAddMinusOneCommand('', gameState: gs));
          } else if (v < cur && deck.hasMinus1()) {
            gs.action(AMDRemoveMinus1Command('', gameState: gs));
          }
        },
      ),
      TvButtonsRow([
        TvMenuButton(text: tr('close'), primary: true, closes: true, onPressed: () {}),
      ]),
    ],
  );
}
