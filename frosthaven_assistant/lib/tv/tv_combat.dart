import 'package:flutter/material.dart';

import '../Layout/ModifierCardWidget/modifier_card_front.dart';
import '../Layout/MonsterAbilityCardWidget/monster_ability_card_front.dart';
import '../Resource/app_constants.dart';
import '../Resource/commands/change_stat_commands/change_health_command.dart';
import '../Resource/commands/change_stat_commands/change_xp_command.dart';
import '../Resource/commands/draw_modifier_card_command.dart';
import '../Resource/commands/turn_done_command.dart';
import '../Resource/enums.dart';
import '../Resource/game_actions.dart';
import '../Resource/game_methods.dart';
import '../Resource/state/game_state.dart';
import 'tv_figure_menu.dart';
import 'tv_menu.dart';
import 'tv_model.dart';
import 'tv_strings.dart';
import 'tv_theme.dart';
import 'tv_widgets.dart';

/// Guided combat: one big window that walks through the round in
/// initiative order. Characters: who comes, health, conditions and their
/// start-of-turn reminders. Monsters: the ability card, the standees in the
/// order they act, and the monster modifier deck. OK goes to the next one;
/// after the last one the round can be closed. Back leaves to the list.
Future<void> showCombatGuide(BuildContext context, GameState gs) {
  final roundAtOpen = gs.round.value;
  return showTvMenu<void>(
    context,
    title: tr('combat'),
    width: 1640,
    rebuildOn: Listenable.merge([gs.commandIndex, gs.updateList, gs.roundState]),
    // the round was closed from here: back to the list for the initiatives
    closeWhen: () =>
        gs.roundState.value == RoundState.chooseInitiative ||
        gs.round.value != roundAtOpen,
    rows: () {
      final cur = currentTurnItem(gs);
      if (gs.roundState.value != RoundState.playTurns) {
        return [
          TvTextRow(tr('combatNotStarted')),
          TvButtonsRow([
            TvMenuButton(text: tr('close'), primary: true, closes: true, onPressed: () {}),
          ]),
        ];
      }
      if (cur == null) return _roundEnd(gs);
      if (cur is Monster) return _monsterTurn(gs, cur);
      return _characterTurn(context, gs, cur);
    },
  );
}

String _nameOf(ListItemData item) {
  if (item is Character) return item.characterState.display.value;
  if (item is Monster) return item.type.display;
  return item.id;
}

/// The next figure after the current one that still has to act.
ListItemData? _nextAfter(GameState gs, ListItemData cur) {
  final list = gs.currentList;
  final i = list.indexOf(cur);
  for (int j = i + 1; j < list.length; j++) {
    final e = list[j];
    if (e.turnState.value == TurnsState.done) continue;
    if (e is Character && e.characterState.health.value > 0) return e;
    if (e is Monster && (e.monsterInstances.isNotEmpty || e.isActive)) return e;
  }
  return null;
}

TvButtonsRow _navButtons(GameState gs, ListItemData cur, {List<TvMenuButton> extra = const []}) {
  final next = _nextAfter(gs, cur);
  return TvButtonsRow([
    TvMenuButton(
      text: next == null
          ? tr('combatDoneLast')
          : '${tr('combatDone')} · ${tr('next')}: ${_nameOf(next)}',
      primary: true,
      onPressed: () => gs.action(TurnDoneCommand(cur.id, gameState: gs)),
    ),
    ...extra,
    TvMenuButton(text: tr('backToList'), closes: true, onPressed: () {}),
  ]);
}

Widget _initBadge(int? init) => Container(
      width: 120,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: TvColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TvColors.line),
      ),
      child: Column(children: [
        Text(init == null ? '–' : '$init',
            style: TvText.title(56).copyWith(height: 1.3)),
        Text(tr('init').toUpperCase(), style: TvText.label(14)),
      ]),
    );

// ----------------------------------------------------------------- character

const Map<Condition, (String, String)> _reminders = {
  Condition.stun: ('Kábítás: ebben a körben nem cselekedhet', 'Stun: cannot act this turn'),
  Condition.immobilize: ('Mozgásképtelen: nem mozoghat', 'Immobilize: cannot move'),
  Condition.disarm: ('Lefegyverzés: nem támadhat', 'Disarm: cannot attack'),
  Condition.muddle: ('Zavarodottság: hátrányos támadások', 'Muddle: attacks with disadvantage'),
  Condition.wound: ('Sebesülés: −1 ÉP a kör elején', 'Wound: suffer 1 damage at the start of the turn'),
  Condition.wound2: ('Sebesülés 2: −2 ÉP a kör elején', 'Wound 2: suffer 2 damage at the start of the turn'),
  Condition.regenerate: ('Regenerálódás: +1 ÉP a kör elején', 'Regenerate: heal 1 at the start of the turn'),
  Condition.bane: ('Végzet: 10 sebzés a kör végén', 'Bane: suffer 10 damage at the end of the turn'),
  Condition.impair: ('Hátráltatás: nem használhat tárgyat', 'Impair: cannot use items'),
  Condition.strengthen: ('Erősítés: előnyös támadások', 'Strengthen: attacks with advantage'),
  Condition.invisible: ('Láthatatlanság: nem célozható', 'Invisible: cannot be targeted'),
};

String _reminderOf(Condition c) {
  final r = _reminders[c];
  if (r == null) return trCondition(c);
  return TvLang.current.value == 'hu' ? r.$1 : r.$2;
}

List<TvMenuRow> _characterTurn(
    BuildContext context, GameState gs, ListItemData cur) {
  final ch = cur as Character;
  final st = ch.characterState;
  final conds = st.conditions.value;
  return [
    TvWidgetRow(() => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _initBadge(st.initiative.value > 0 ? st.initiative.value : null),
          const SizedBox(width: 28),
          Container(
            width: 150,
            height: 150,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: TvColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: ch.characterClass.color, width: 3),
            ),
            child: Image.asset(classIconPath(ch), color: classTint(ch)),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(trTurnOf(st.display.value), style: TvText.title(60).copyWith(height: 1.25)),
              const SizedBox(height: 6),
              Text(characterSubline(ch), style: TvText.body(22, color: TvColors.muted)),
              if (ch.note.value.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: tvText('✎ ${ch.note.value}', TvText.body(22, color: TvColors.elite)),
                ),
              const SizedBox(height: 18),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic, children: [
                Text('${st.health.value}', style: TvText.body(54, weight: FontWeight.w800)),
                Text(' / ${st.maxHealth.value} ${tr('hp')}',
                    style: TvText.body(24, color: TvColors.muted)),
              ]),
              const SizedBox(height: 8),
              SizedBox(width: 520, child: TvHpBar(hp: st.health.value, max: st.maxHealth.value, height: 12)),
              if (conds.isNotEmpty) ...[
                const SizedBox(height: 20),
                for (final c in conds)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Image.asset(conditionIconPath(c), width: 36, height: 36,
                          color: conditionTint(c)),
                      const SizedBox(width: 12),
                      Text(_reminderOf(c), style: TvText.body(24)),
                    ]),
                  ),
              ],
              if (st.summonList.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(tr('summons').toUpperCase(), style: TvText.label(15)),
                const SizedBox(height: 8),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final s in st.summonList)
                    TvStandeeChip(instance: s, ownerId: ch.id, selected: false, summon: true),
                ]),
              ],
            ]),
          ),
        ])),
    _navButtons(gs, cur),
    ..._characterEdits(context, gs, ch),
  ];
}

/// Health / XP of the character (and its summons) and quick access to the
/// monsters on the table, so the round can be played without leaving here.
List<TvMenuRow> _characterEdits(BuildContext context, GameState gs, Character ch) {
  final st = ch.characterState;
  final out = <TvMenuRow>[
    TvStepperRow(
      label: tr('health'),
      min: 0,
      max: st.maxHealth.value,
      value: () => st.health.value,
      format: (v) => '$v / ${st.maxHealth.value}',
      onChange: (v) {
        final d = v - st.health.value;
        if (d != 0) gs.action(ChangeHealthCommand(d, ch.id, ch.id, gameState: gs));
      },
    ),
    if (!GameMethods.isObjectiveOrEscort(ch.characterClass))
      TvStepperRow(
        label: tr('experience'),
        min: 0,
        max: 99,
        digits: 2,
        value: () => st.xp.value,
        onChange: (v) {
          final d = v - st.xp.value;
          if (d != 0) gs.action(ChangeXPCommand(d, ch.id, ch.id, gameState: gs));
        },
      ),
    for (final s in st.summonList)
      TvStepperRow(
        label: '${s.name}${s.standeeNr > 0 ? ' ${s.standeeNr}' : ''}',
        min: 0,
        max: s.maxHealth.value,
        value: () => s.health.value,
        format: (v) => '$v / ${s.maxHealth.value}',
        onChange: (v) {
          final d = v - s.health.value;
          if (d != 0) {
            gs.action(ChangeHealthCommand(d, s.getId(), ch.id, gameState: gs));
          }
        },
      ),
  ];
  // monsters on the table: OK opens the standee's menu (health, conditions)
  final standees = buildTargets(gs).where((t) => t.isStandee && !t.isSummon).toList();
  if (standees.isNotEmpty) {
    out.addAll(tvGrid([
      for (final t in standees)
        TvMenuButton(
          text: '${(t.item as Monster).type.display} ${t.instance!.standeeNr}'
              '${t.instance!.type == MonsterType.elite ? ' ${tr('elite').toLowerCase()}' : ''} · '
              '${t.instance!.health.value}/${t.instance!.maxHealth.value}',
          onPressed: () => showFigureMenu(context, gs, t),
        ),
    ], 3, label: tr('combatMonsters')));
  }
  return out;
}

// ----------------------------------------------------------------- monster

List<TvMenuRow> _monsterTurn(GameState gs, Monster m) {
  const cardScale = 3.9;
  final deck = GameMethods.getDeck(m.type.deck);
  final card = deck != null && deck.discardPileIsNotEmpty ? deck.discardPileTop : null;
  // FH: elites act first, then normals, each in standee number order
  final order = m.monsterInstances.toList()
    ..sort((a, b) {
      int rank(MonsterInstance i) => i.type == MonsterType.boss
          ? 0
          : i.type == MonsterType.elite
              ? 1
              : 2;
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : a.standeeNr.compareTo(b.standeeNr);
    });
  final mod = gs.modifierDeck;
  final lastMod = mod.discardPileIsNotEmpty ? mod.discardPileTop : null;
  return [
    TvWidgetRow(() => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _initBadge(card?.initiative),
          const SizedBox(width: 24),
          SizedBox(
            width: (kAbilityCardWidth + 2 * kMonsterCardMargin) * cardScale,
            height: (94.4 + 2 * kMonsterCardMargin) * cardScale,
            child: card == null
                ? const SizedBox()
                : MonsterAbilityCardFront(
                    card: card, data: m, scale: cardScale, calculateAll: false),
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(trTurnOf(m.type.display), style: TvText.title(52).copyWith(height: 1.25)),
              const SizedBox(height: 10),
              TvStatCard(monster: m, scale: 2.6),
              const SizedBox(height: 14),
              Text(tr('actOrder'), style: TvText.body(20, color: TvColors.muted)),
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (final s in order)
                  TvStandeeChip(
                      instance: s,
                      ownerId: m.id,
                      selected: false,
                      badges: defenseBadges(m, s.type)),
              ]),
              const SizedBox(height: 22),
              Row(children: [
                SizedBox(
                  width: kModifierCardBaseWidth * 2.4 + 8,
                  height: 39 * 2.4 + 8,
                  child: lastMod == null
                      ? Container(
                          decoration: BoxDecoration(
                            color: TvColors.card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: TvColors.line),
                          ),
                          alignment: Alignment.center,
                          child: Text(tr('noModCards'),
                              textAlign: TextAlign.center,
                              style: TvText.body(16, color: TvColors.dim)),
                        )
                      : ModifierCardFront(card: lastMod, name: '', scale: 2.4),
                ),
                const SizedBox(width: 18),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('monsterModDeck'), style: TvText.body(20, color: TvColors.muted)),
                  const SizedBox(height: 4),
                  Text(trCardsLeft(mod.drawPileSize), style: TvText.body(24)),
                ]),
              ]),
            ]),
          ),
        ])),
    _navButtons(gs, m, extra: [
      TvMenuButton(
        text: tr('drawModifier'),
        onPressed: () => gs.action(DrawModifierCardCommand('', gameState: gs)),
      ),
    ]),
  ];
}

// ----------------------------------------------------------------- round end

List<TvMenuRow> _roundEnd(GameState gs) => [
      TvWidgetRow(() => Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Row(children: [
              const Icon(Icons.flag_outlined, size: 64, color: TvColors.focus),
              const SizedBox(width: 24),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(trRoundOver(gs.round.value), style: TvText.title(56).copyWith(height: 1.25)),
                const SizedBox(height: 8),
                Text(tr('roundOverSub'), style: TvText.body(22, color: TvColors.muted)),
              ]),
            ]),
          )),
      TvButtonsRow([
        TvMenuButton(
          text: tr('nextRound'),
          primary: true,
          onPressed: () => runDrawOrNextRoundAction(gs),
        ),
        TvMenuButton(text: tr('backToList'), closes: true, onPressed: () {}),
      ]),
    ];
