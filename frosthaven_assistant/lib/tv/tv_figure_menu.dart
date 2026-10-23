import 'package:flutter/material.dart';

import '../Resource/commands/add_condition_command.dart';
import '../Resource/commands/change_stat_commands/change_health_command.dart';
import '../Resource/commands/change_stat_commands/change_xp_command.dart';
import '../Resource/commands/remove_condition_command.dart';
import '../Resource/commands/set_init_command.dart';
import '../Resource/commands/set_level_command.dart';
import '../Resource/commands/turn_done_command.dart';
import '../Resource/enums.dart';
import '../Resource/game_methods.dart';
import '../Resource/state/game_state.dart';
import 'tv_menu.dart';
import 'tv_model.dart';
import 'tv_setup_menus.dart';
import 'tv_strings.dart';

/// OK on a figure: initiative, health, XP, conditions and turn actions.
Future<void> showFigureMenu(BuildContext context, GameState gs, TvTarget t) {
  final item = t.item;
  final fig = t.figure;

  String title;
  String? subtitle;
  String? image;
  Color? tint;
  if (item is Character && t.isCharacter) {
    title = item.characterState.display.value;
    subtitle = characterSubline(item);
    image = classIconPath(item);
    tint = classTint(item);
  } else if (t.isSummon) {
    final s = t.instance!;
    title = '${s.name} · ${trStandeeNr(s.standeeNr)}';
    subtitle = tr('summon');
    image = summonImagePath(s);
  } else if (item is Monster) {
    final s = t.instance;
    title = s == null
        ? item.type.display
        : '${item.type.display} · ${trStandeeNr(s.standeeNr)}';
    subtitle = s == null
        ? tr('noStandees')
        : (s.type == MonsterType.elite
            ? tr('elite')
            : s.type == MonsterType.boss
                ? tr('boss')
                : tr('normal'));
    image = monsterImagePath(item);
  } else {
    title = item.id;
  }

  // initiative is committed once when the menu closes (one undo step)
  final Character? ch = (item is Character && t.isCharacter) ? item : null;
  final bool isPlayer =
      ch != null && !GameMethods.isObjectiveOrEscort(ch.characterClass);
  final canSetInit =
      isPlayer && gs.roundState.value == RoundState.chooseInitiative;
  final startInit = ch?.characterState.initiative.value ?? 0;
  int pendingInit = startInit;

  final immunities = immunitiesFor(t);
  final conditions = fig == null ? <Condition>[] : conditionsFor(t);

  List<TvMenuRow> rows() {
    final out = <TvMenuRow>[];
    if (canSetInit) {
      out.add(TvStepperRow(
        label: tr('initiative'),
        min: 0,
        max: 99,
        value: () => pendingInit,
        format: (v) => v <= 0 ? '–' : v.toString().padLeft(2, '0'),
        onChange: (v) => pendingInit = v,
      ));
    }
    if (fig != null) {
      out.add(TvStepperRow(
        label: tr('health'),
        min: 0,
        max: fig.maxHealth.value,
        value: () => fig.health.value,
        format: (v) => '$v / ${fig.maxHealth.value}',
        onChange: (v) {
          final d = v - fig.health.value;
          if (d != 0) {
            gs.action(ChangeHealthCommand(d, t.figureId, t.ownerId, gameState: gs));
          }
        },
      ));
    }
    if (ch != null && isPlayer) {
      final st = ch.characterState;
      out.add(TvStepperRow(
        label: tr('experience'),
        min: 0,
        max: 999,
        value: () => st.xp.value,
        onChange: (v) {
          final d = v - st.xp.value;
          if (d != 0) {
            gs.action(ChangeXPCommand(d, t.figureId, t.ownerId, gameState: gs));
          }
        },
      ));
    }
    final Monster? monster = item is Monster ? item : null;
    if (monster != null) {
      out.add(TvStepperRow(
        label: tr('monsterLevel'),
        min: 0,
        max: 7,
        value: () => monster.level.value,
        onChange: (v) => gs.action(SetLevelCommand(v, monster.id)),
      ));
    }
    if (fig != null && conditions.isNotEmpty) {
      const perRow = 6;
      for (int i = 0; i < conditions.length; i += perRow) {
        final chunk = conditions.sublist(
            i, (i + perRow) > conditions.length ? conditions.length : i + perRow);
        out.add(TvButtonsRow(
          [
            for (final c in chunk)
              _conditionButton(gs, t, fig, c, immunities),
          ],
          label: i == 0 ? tr('conditions') : null,
          iconGrid: true,
        ));
      }
    }
    final owner = item;
    final canEndTurn = gs.roundState.value == RoundState.playTurns &&
        owner.turnState.value != TurnsState.done &&
        (owner is Character || owner is Monster);
    out.add(TvButtonsRow([
      if (canEndTurn)
        TvMenuButton(
          text: tr('turnDone'),
          icon: null,
          closes: true,
          onPressed: () => gs.action(TurnDoneCommand(owner.id, gameState: gs)),
        ),
      TvMenuButton(text: tr('close'), primary: true, closes: true, onPressed: () {}),
    ], label: tr('actions')));
    // setup actions open their own menu once this one has closed
    void later(void Function() f) =>
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) f();
        });
    if (ch != null && isPlayer) {
      out.add(TvButtonsRow([
        TvMenuButton(
            text: tr('characterLevel'),
            closes: true,
            onPressed: () => later(() => showCharacterLevelMenu(context, gs, ch))),
        TvMenuButton(
            text: tr('removeCharacter'),
            closes: true,
            onPressed: () => later(() => confirmRemoveCharacter(context, gs, ch))),
      ]));
    } else if (ch != null) {
      out.add(TvButtonsRow([
        TvMenuButton(
            text: tr('removeCharacter'),
            closes: true,
            onPressed: () => later(() => confirmRemoveCharacter(context, gs, ch))),
      ]));
    } else if (monster != null) {
      out.add(TvButtonsRow([
        TvMenuButton(
            text: tr('addStandees'),
            closes: true,
            onPressed: () => later(() => showStandeeMenu(context, gs, monster))),
        TvMenuButton(
            text: tr('removeMonster'),
            closes: true,
            onPressed: () => later(() => confirmRemoveMonster(context, gs, monster))),
      ]));
    }
    return out;
  }

  return showTvMenu<void>(
    context,
    title: title,
    subtitle: subtitle,
    image: image,
    imageTint: tint,
    rows: rows,
    rebuildOn: gs.commandIndex,
    onClose: () {
      if (ch != null && canSetInit && pendingInit != startInit && pendingInit > 0) {
        gs.action(SetInitCommand(ch.id, pendingInit, gameState: gs));
      }
    },
  );
}

TvMenuButton _conditionButton(GameState gs, TvTarget t, FigureState fig,
    Condition c, List<String> immunities) {
  final allowed = conditionAllowed(c, immunities);
  final active = fig.conditions.value.contains(c);
  return TvMenuButton(
    text: trCondition(c),
    icon: conditionIconPath(c),
    iconTint: conditionTint(c),
    active: active,
    disabledNote: allowed ? null : tr('immune'),
    onPressed: !allowed
        ? null
        : () {
            if (fig.conditions.value.contains(c)) {
              gs.action(RemoveConditionCommand(c, t.figureId, t.ownerId, gameState: gs));
            } else {
              gs.action(AddConditionCommand(c, t.figureId, t.ownerId, gameState: gs));
            }
          },
  );
}
