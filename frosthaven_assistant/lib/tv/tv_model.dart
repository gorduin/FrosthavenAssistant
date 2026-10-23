import 'package:collection/collection.dart';
import 'package:flutter/painting.dart';

import '../Model/character_class.dart';
import '../Model/monster.dart';
import '../Resource/game_data.dart';
import '../Resource/enums.dart';
import '../Resource/game_methods.dart';
import '../Resource/settings.dart';
import '../Resource/state/game_state.dart';
import '../Resource/ui_utils.dart';
import '../services/service_locator.dart';
import 'tv_strings.dart';

/// One remote-selectable figure on the main screen: a character, one of its
/// summons, a monster standee, or a monster group that has no standees yet.
class TvTarget {
  TvTarget({
    required this.rowIndex,
    required this.item,
    required this.figureId,
    required this.ownerId,
    this.figure,
  });

  /// Index into GameState.currentList.
  final int rowIndex;
  final ListItemData item;

  /// Ids as the health / condition commands expect them.
  final String figureId;
  final String ownerId;

  /// null for a monster group without standees.
  final FigureState? figure;

  String get key => '$ownerId|$figureId';

  bool get isCharacter => item is Character && figure is CharacterState;
  bool get isStandee => figure is MonsterInstance;
  bool get isSummon => isStandee && item is Character;
  bool get isEmptyGroup => figure == null;

  MonsterInstance? get instance =>
      figure is MonsterInstance ? figure as MonsterInstance : null;
}

List<TvTarget> buildTargets(GameState gs) {
  final list = gs.currentList;
  final out = <TvTarget>[];
  for (int i = 0; i < list.length; i++) {
    final item = list[i];
    if (item is Character) {
      out.add(TvTarget(
          rowIndex: i,
          item: item,
          figureId: item.id,
          ownerId: item.id,
          figure: item.characterState));
      for (final s in item.characterState.summonList) {
        out.add(TvTarget(
            rowIndex: i,
            item: item,
            figureId: s.getId(),
            ownerId: item.id,
            figure: s));
      }
    } else if (item is Monster) {
      final instances = item.monsterInstances;
      if (instances.isEmpty) {
        out.add(TvTarget(
            rowIndex: i, item: item, figureId: item.id, ownerId: item.id));
      } else {
        for (final m in instances) {
          out.add(TvTarget(
              rowIndex: i,
              item: item,
              figureId: m.getId(),
              ownerId: item.id,
              figure: m));
        }
      }
    }
  }
  return out;
}

// ---------- images ----------

String classIconPath(Character c) =>
    'assets/images/class-icons/${c.characterClass.name}.png';

/// Class icons are single-colour silhouettes; the original UI tints them with
/// the class colour (objectives / escorts keep their own colours).
Color? classTint(Character c) =>
    GameMethods.isObjectiveOrEscort(c.characterClass) ? null : c.characterClass.color;

/// "Blinkblade · 3. szint", or just the level when the player kept the class name.
String characterSubline(Character c) {
  final cls = c.characterClass.name;
  if (GameMethods.isObjectiveOrEscort(c.characterClass)) return cls;
  final lvl = trLevel(c.characterState.level.value);
  return c.characterState.display.value == cls ? lvl : '$cls · $lvl';
}

CharacterClass? _classById(String id) {
  for (final c in getIt<GameData>().modelData.value.values) {
    for (final cls in c.characters) {
      if (cls.id == id) return cls;
    }
  }
  return null;
}

String classIconPathById(String id) =>
    'assets/images/class-icons/${_classById(id)?.name ?? id}.png';

Color? classColorById(String id) => _classById(id)?.color;

String monsterImagePath(Monster m) =>
    'assets/images/monsters/${m.type.gfx}.png';

String summonImagePath(MonsterInstance s) =>
    'assets/images/summon/${s.gfx}.png';

String elementIconPath(Elements e) => 'assets/images/psd/element-${e.name}.png';

String conditionIconPath(Condition condition) {
  final suffix = GameMethods.isFrosthavenStyle(null) ? '_fh' : '';
  if (condition.name.contains('character')) {
    return 'assets/images/class-icons/${condition.getName()}.png';
  }
  if (suffix.isNotEmpty && hasGHVersion(condition.name)) {
    return 'assets/images/abilities/${condition.getName()}$suffix.png';
  }
  return 'assets/images/abilities/${condition.name}.png';
}

/// Character-specific conditions use the class icon, tinted like the class.
Color? conditionTint(Condition condition) {
  if (!condition.name.contains('character')) return null;
  final name = condition.getName();
  final match = GameMethods.getCurrentCharacters()
      .firstWhereOrNull((c) => c.characterClass.name == name);
  return match?.characterClass.color;
}

// ---------- game helpers ----------

MonsterStatsModel? statsFor(Monster m, MonsterType type) {
  final lvl = m.type.levels
      .firstWhereOrNull((l) => l.level == m.level.value);
  if (lvl == null) return null;
  switch (type) {
    case MonsterType.elite:
      return lvl.elite;
    case MonsterType.boss:
      return lvl.boss;
    default:
      return lvl.normal;
  }
}

List<String> immunitiesFor(TvTarget t) {
  final inst = t.instance;
  final item = t.item;
  if (inst == null || item is! Monster) return const [];
  return statsFor(item, inst.type)?.immunities ?? const [];
}

bool conditionAllowed(Condition c, List<String> immunities) {
  for (final item in immunities) {
    if (item.length < 2) continue;
    final immunity = item.substring(1, item.length - 1);
    if (c.name.contains(immunity)) return false;
    if (immunity == 'poison' && c == Condition.infect) return false;
    if (immunity == 'wound' && c == Condition.rupture) return false;
  }
  return true;
}

/// Conditions offered in the figure menu, following the original status menu.
List<Condition> conditionsFor(TvTarget t) {
  final custom = getIt<Settings>().showCustomContent.value;
  final isChar = t.isCharacter;
  final isSummon = t.isSummon;
  final out = <Condition>[
    Condition.stun,
    Condition.immobilize,
    Condition.disarm,
    Condition.wound,
    Condition.muddle,
    Condition.poison,
    Condition.bane,
    Condition.brittle,
    Condition.safeguard,
  ];
  if (isChar || isSummon) {
    if (custom) out.add(Condition.infect);
    if (!isSummon) out.add(Condition.impair);
    if (custom) out.add(Condition.rupture);
  } else if (custom) {
    out.addAll([Condition.poison2, Condition.rupture]);
  }
  out.addAll([
    Condition.strengthen,
    Condition.invisible,
    Condition.regenerate,
    Condition.ward,
    if (custom) Condition.dodge,
  ]);
  if (t.isStandee && !isSummon) {
    final n = GameMethods.getCurrentCharacters().length;
    const chars = [
      Condition.character1,
      Condition.character2,
      Condition.character3,
      Condition.character4
    ];
    for (int i = 0; i < n && i < chars.length; i++) {
      out.add(chars[i]);
    }
  }
  return out;
}

bool isRowActive(ListItemData item) =>
    item.turnState.value == TurnsState.current;

bool isRowDone(GameState gs, ListItemData item) =>
    gs.roundState.value == RoundState.playTurns &&
    item.turnState.value == TurnsState.done;

/// The monster whose ability card the right panel shows for [t].
Monster? cardMonsterFor(GameState gs, TvTarget? t) {
  if (t != null && t.item is Monster) return t.item as Monster;
  final list = gs.currentList;
  final current = list.firstWhereOrNull(
      (e) => e is Monster && e.turnState.value == TurnsState.current);
  if (current is Monster) return current;
  // next monster in turn order that has not acted yet
  final next = list.firstWhereOrNull((e) =>
      e is Monster &&
      e.turnState.value == TurnsState.notDone &&
      (e.monsterInstances.isNotEmpty || e.isActive));
  if (next is Monster) return next;
  final any = list.firstWhereOrNull((e) => e is Monster);
  return any is Monster ? any : null;
}

/// Initiative shown in a row; null when unknown (shows "–").
int? rowInitiative(GameState gs, ListItemData item) {
  if (item is Character) {
    final v = item.characterState.initiative.value;
    return v > 0 ? v : null;
  }
  if (item is Monster) {
    if (gs.roundState.value != RoundState.playTurns) return null;
    if (!item.isActive && item.monsterInstances.isEmpty) return null;
    final deck = GameMethods.getDeck(item.type.deck);
    if (deck == null || deck.discardPileIsEmpty) return null;
    return deck.discardPileTop.initiative;
  }
  return null;
}
