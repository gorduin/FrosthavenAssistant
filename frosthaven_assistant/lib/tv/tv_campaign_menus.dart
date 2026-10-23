import 'package:flutter/material.dart';

import '../Resource/commands/add_character_command.dart';
import '../Resource/commands/change_name_command.dart';
import '../Resource/commands/set_campaign_command.dart';
import '../Resource/commands/set_character_level_command.dart';
import '../Resource/game_data.dart';
import '../Resource/game_methods.dart';
import '../Resource/settings.dart';
import '../Resource/state/game_state.dart';
import '../services/service_locator.dart';
import 'tv_backup.dart';
import 'tv_campaign.dart';
import 'tv_menu.dart';
import 'tv_model.dart';
import 'tv_setup_menus.dart';
import 'tv_strings.dart';
import 'tv_theme.dart';

const Color kUnlockedColor = TvColors.elite;
const Color kCompletedColor = TvColors.earth;

/// Tile marking of a scenario in a campaign: (accent, subtitle prefix).
(Color?, String) progressLook(ScenarioProgress p) {
  switch (p) {
    case ScenarioProgress.unlocked:
      return (kUnlockedColor, '${tr('unlocked')} · ');
    case ScenarioProgress.completed:
      return (kCompletedColor, '${tr('completed')} · ');
    case ScenarioProgress.none:
      return (null, '');
  }
}

/// The active campaign, if it belongs to the edition currently played.
TvCampaign? campaignFor(GameState gs) {
  final c = TvCampaigns.active;
  if (c == null || c.edition != gs.currentCampaign.value) return null;
  return c;
}

/// Scenarios a campaign can track (no custom / random dungeon).
List<String> trackableScenarios(GameState gs, String edition) =>
    scenariosOf(gs, edition)
        .where((s) => s != 'custom' && s != '#Random Dungeon')
        .toList();

void _activate(GameState gs, TvCampaign? c) {
  TvCampaigns.activate(c);
  if (c != null && gs.currentCampaign.value != c.edition) {
    gs.action(SetCampaignCommand(c.edition));
  }
}

List<String> _editions() {
  final gd = getIt<GameData>();
  final custom = getIt<Settings>().showCustomContent.value;
  return gd.editions
      .where((e) =>
          e != 'Solo' &&
          (gd.modelData.value[e]?.scenarios.isNotEmpty ?? false) &&
          (custom || !GameMethods.isCustomCampaign(e)))
      .toList();
}

Future<void> _newCampaign(BuildContext context, GameState gs) async {
  final typed = await showTvTextInput(
    context,
    title: tr('newCampaign'),
    subtitle: tr('campaignNameQ'),
  );
  if (typed == null || !context.mounted) return;
  final name = typed.isEmpty
      ? '${tr('campaign')} ${TvCampaigns.all.length + 1}'
      : typed;
  String? edition;
  final editions = _editions();
  final current = gs.currentCampaign.value;
  await showTvMenu<void>(
    context,
    title: name,
    subtitle: tr('chooseEdition'),
    rows: () => tvGrid([
      for (final e in editions)
        TvMenuButton(
          text: e,
          active: e == current,
          closes: true,
          onPressed: () => edition = e,
        ),
    ], 4, label: tr('edition')),
    start: (() {
      final i = editions.indexOf(current);
      return i < 0 ? (0, 0) : (i ~/ 4, i % 4);
    })(),
  );
  final ed = edition;
  if (ed == null) return;
  final c = TvCampaigns.create(name, ed);
  _activate(gs, c);
}

Future<void> showCampaignMenu(BuildContext context, GameState gs) {
  Future<void> later(Future<void> Function() f) async {
    if (context.mounted) await f();
  }

  List<TvMenuRow> rows() {
    final active = TvCampaigns.active;
    final out = <TvMenuRow>[];
    if (TvCampaigns.all.isNotEmpty) {
      out.addAll(tvGrid([
        for (final c in TvCampaigns.all)
          TvMenuButton(
            text: c.name,
            subtitle: '${c.edition} · ${trCompletedCount(c.completedCount)}',
            active: c.id == active?.id,
            onPressed: () => _activate(gs, c),
          ),
      ], 4, label: tr('campaigns'), style: TvRowStyle.tiles));
    } else {
      out.add(TvTextRow(tr('noCampaigns')));
    }
    out.add(TvButtonsRow([
      TvMenuButton(
          text: tr('newCampaign'),
          primary: TvCampaigns.all.isEmpty,
          onPressed: () => later(() => _newCampaign(context, gs))),
      if (active != null)
        TvMenuButton(
            text: tr('noCampaign'), onPressed: () => _activate(gs, null)),
    ]));
    if (active != null) {
      out.add(TvButtonsRow([
        TvMenuButton(
            text: tr('markScenarios'),
            primary: true,
            onPressed: () => later(() => showProgressMenu(context, gs, active))),
        TvMenuButton(
            text: tr('party'),
            onPressed: () => later(() => showPartyMenu(context, gs, active))),
        TvMenuButton(
            text: tr('rename'),
            onPressed: () => later(() async {
                  final n = await showTvTextInput(context,
                      title: tr('rename'), initial: active.name);
                  if (n != null && n.isNotEmpty) TvCampaigns.rename(active, n);
                })),
        TvMenuButton(
            text: tr('delete'),
            onPressed: () => later(() => _confirmDelete(context, active))),
      ], label: '${tr('activeCampaign')}: ${active.name}'));
    }
    out.add(TvButtonsRow([
      TvMenuButton(text: tr('close'), closes: true, onPressed: () {}),
    ]));
    return out;
  }

  return showTvMenu<void>(
    context,
    title: tr('campaignMenu'),
    subtitle: tr('campaignMenuSub'),
    rows: rows,
    rebuildOn: Listenable.merge([TvCampaigns.version, gs.commandIndex]),
  );
}

Future<void> _confirmDelete(BuildContext context, TvCampaign c) {
  return showTvMenu<void>(
    context,
    title: tr('deleteCampaignQ'),
    subtitle: c.name,
    width: 900,
    rows: () => [
      TvButtonsRow([
        TvMenuButton(text: tr('cancel'), closes: true, onPressed: () {}),
        TvMenuButton(
            text: tr('delete'),
            primary: true,
            closes: true,
            onPressed: () => TvCampaigns.delete(c)),
      ]),
    ],
  );
}

/// One grid with every scenario of the campaign's edition; OK cycles
/// none → unlocked → completed. Made for catching up on an ongoing campaign.
Future<void> showProgressMenu(
    BuildContext context, GameState gs, TvCampaign c) {
  final scenarios = trackableScenarios(gs, c.edition);
  List<TvMenuRow> rows() => [
        TvTextRow('${trCompletedCount(c.completedCount)} · '
            '${trUnlockedCount(c.unlockedCount)} — ${tr('progressHint')}'),
        ...tvGrid([
          for (final s in scenarios)
            () {
              final look = progressLook(c.of(s));
              final space = s.indexOf(' ');
              final title = space > 0 ? s.substring(0, space) : s;
              final name = space > 0 ? s.substring(space + 1) : '';
              return TvMenuButton(
                text: title,
                subtitle: '${look.$2}$name',
                accent: look.$1,
                active: c.of(s) == ScenarioProgress.completed,
                onPressed: () => TvCampaigns.cycleProgress(c, s),
              );
            }(),
        ], 4, label: c.edition, style: TvRowStyle.tiles),
        TvButtonsRow([
          TvMenuButton(text: tr('done'), primary: true, closes: true, onPressed: () {}),
        ]),
      ];

  return showTvMenu<void>(
    context,
    title: c.name,
    subtitle: c.edition,
    rows: rows,
    rebuildOn: TvCampaigns.version,
    start: (1, 0),
  );
}


// ======================================================================
// Party
// ======================================================================

List<Character> _gamePlayers() => GameMethods.getCurrentCharacters()
    .where((c) => !GameMethods.isObjectiveOrEscort(c.characterClass))
    .toList();

/// What "save from game" would change: new members and level / name
/// changes of existing ones (the campaign XP total is never touched).
List<String> partySaveChanges(TvCampaign c) {
  final out = <String>[];
  for (final ch in _gamePlayers()) {
    final m = c.party.where((p) => p.classId == ch.characterClass.id).firstOrNull;
    final name = ch.characterState.display.value;
    final level = ch.characterState.level.value;
    if (m == null) {
      out.add('${tr('newMember')}: $name (${trLevel(level)})');
      continue;
    }
    if (m.level != level) out.add('${m.name}: ${trLevel(m.level)} → ${trLevel(level)}');
    if (m.name != name) out.add('${m.name} → $name');
  }
  return out;
}

/// Adds the characters playing now to the party, or updates their name and
/// level (the campaign XP total is kept).
int savePartyFromGame(TvCampaign c) {
  int added = 0;
  for (final ch in _gamePlayers()) {
    final m = c.party.where((p) => p.classId == ch.characterClass.id).firstOrNull;
    if (m == null) {
      c.party.add(PartyMember(
        classId: ch.characterClass.id,
        edition: ch.characterClass.edition,
        name: ch.characterState.display.value,
        level: ch.characterState.level.value,
        xp: 0,
      ));
      added++;
    } else {
      m.name = ch.characterState.display.value;
      m.level = ch.characterState.level.value;
    }
  }
  TvCampaigns.changed();
  return added;
}

/// Puts the party into the game: adds the members who are missing and gives
/// the ones already playing the party's level and name. XP stays as it is:
/// the game counts the XP of the current scenario.
(int, int) loadPartyIntoGame(GameState gs, TvCampaign c) {
  int added = 0;
  int updated = 0;
  final playing = _gamePlayers();
  for (final m in c.party) {
    final ch = playing.where((e) => e.characterClass.id == m.classId).firstOrNull;
    if (ch == null) {
      final cmd = AddCharacterCommand(m.classId, m.edition, m.name, m.level);
      gs.action(cmd);
      if (cmd.character != null) added++;
      continue;
    }
    bool changed = false;
    if (ch.characterState.level.value != m.level) {
      gs.action(SetCharacterLevelCommand(m.level, ch.id));
      changed = true;
    }
    if (m.name.isNotEmpty && ch.characterState.display.value != m.name) {
      gs.action(ChangeNameCommand(m.name, ch.id, gameState: gs));
      changed = true;
    }
    if (changed) updated++;
  }
  return (added, updated);
}

/// Adds the XP gained in this scenario to the campaign totals.
/// Returns "name +n" parts for a confirmation message.
List<String> creditScenarioXp(TvCampaign c) {
  final out = <String>[];
  for (final ch in _gamePlayers()) {
    final xp = ch.characterState.xp.value;
    var m = c.party.where((p) => p.classId == ch.characterClass.id).firstOrNull;
    if (m == null) {
      m = PartyMember(
        classId: ch.characterClass.id,
        edition: ch.characterClass.edition,
        name: ch.characterState.display.value,
        level: ch.characterState.level.value,
        xp: 0,
      );
      c.party.add(m);
    }
    m.xp += xp;
    out.add('${m.name} +$xp');
  }
  TvCampaigns.changed();
  return out;
}

/// End of scenario: mark it completed and credit the XP.
void completeScenario(BuildContext context, GameState gs, TvCampaign c) {
  final scenario = gs.scenario.value;
  TvCampaigns.setProgress(c, scenario, ScenarioProgress.completed);
  final xp = creditScenarioXp(c);
  TvBackup.backupNow('scenario');
  TvToast.show(
      context,
      '${tr('markedCompleted')}: $scenario'
      '${xp.isEmpty ? '' : '\n${tr('xpCredited')}: ${xp.join(', ')}'}',
      seconds: 6);
}

Future<void> showPartyMenu(BuildContext context, GameState gs, TvCampaign c) {
  List<TvMenuRow> rows() => [
        if (c.party.isEmpty) TvTextRow(tr('partyEmpty')),
        ...tvGrid([
          for (final m in c.party)
            TvMenuButton(
              text: m.name,
              subtitle: '${trLevel(m.level)} · ${m.xp} ${tr('xp')}',
              icon: classIconPathById(m.classId),
              iconTint: classColorById(m.classId),
              onPressed: () => showMemberMenu(context, c, m),
            ),
        ], 6, label: tr('partyMembers'), style: TvRowStyle.pictures),
        TvButtonsRow([
          TvMenuButton(
            text: tr('loadParty'),
            primary: c.party.isNotEmpty,
            onPressed: c.party.isEmpty
                ? null
                : () {
                    final (added, updated) = loadPartyIntoGame(gs, c);
                    TvToast.show(context, trLoadedParty(added, updated));
                  },
          ),
          TvMenuButton(
            text: tr('saveParty'),
            onPressed: () => confirmSaveParty(context, c),
          ),
          TvMenuButton(
            text: tr('creditXp'),
            onPressed: () {
              final xp = creditScenarioXp(c);
              TvToast.show(context,
                  xp.isEmpty ? tr('noPlayers') : '${tr('xpCredited')}: ${xp.join(', ')}');
            },
          ),
        ]),
        TvTextRow(tr('partyHint')),
        TvButtonsRow([
          TvMenuButton(text: tr('close'), closes: true, onPressed: () {}),
        ]),
      ];

  return showTvMenu<void>(
    context,
    title: '${tr('party')} · ${c.name}',
    subtitle: tr('partySub'),
    rows: rows,
    rebuildOn: Listenable.merge([TvCampaigns.version, gs.commandIndex]),
  );
}

Future<void> showMemberMenu(BuildContext context, TvCampaign c, PartyMember m) {
  return showTvMenu<void>(
    context,
    title: m.name,
    subtitle: c.name,
    image: classIconPathById(m.classId),
    imageTint: classColorById(m.classId),
    width: 1000,
    rebuildOn: TvCampaigns.version,
    rows: () => [
      TvStepperRow(
        label: tr('level'),
        min: 1,
        max: 9,
        value: () => m.level,
        onChange: (v) {
          m.level = v;
          TvCampaigns.changed();
        },
      ),
      TvStepperRow(
        label: tr('experience'),
        min: 0,
        max: 999,
        digits: 3,
        value: () => m.xp,
        onChange: (v) {
          m.xp = v;
          TvCampaigns.changed();
        },
      ),
      TvButtonsRow([
        TvMenuButton(
            text: tr('removeFromParty'),
            closes: true,
            onPressed: () {
              c.party.remove(m);
              TvCampaigns.changed();
            }),
        TvMenuButton(text: tr('done'), primary: true, closes: true, onPressed: () {}),
      ]),
    ],
  );
}


/// "Save from game": lists what would change and asks before overwriting.
Future<void> confirmSaveParty(BuildContext context, TvCampaign c) async {
  final changes = partySaveChanges(c);
  if (changes.isEmpty) {
    TvToast.show(context, tr('partyUpToDate'));
    return;
  }
  return showTvMenu<void>(
    context,
    title: tr('saveParty'),
    subtitle: tr('saveChangesQ'),
    width: 1000,
    rows: () => [
      for (final ch in changes) TvTextRow(ch),
      TvButtonsRow([
        TvMenuButton(text: tr('cancel'), closes: true, onPressed: () {}),
        TvMenuButton(
          text: tr('save'),
          primary: true,
          closes: true,
          onPressed: () {
            final n = savePartyFromGame(c);
            TvToast.show(context, trSavedToParty(n));
          },
        ),
      ]),
    ],
  );
}

/// Campaign XP total of a character, when an active campaign tracks it.
int? campaignXpOf(GameState gs, Character ch) {
  final c = campaignFor(gs);
  if (c == null) return null;
  return c.party.where((p) => p.classId == ch.characterClass.id).firstOrNull?.xp;
}
