import 'package:flutter/material.dart';

import '../Resource/commands/set_campaign_command.dart';
import '../Resource/game_data.dart';
import '../Resource/game_methods.dart';
import '../Resource/settings.dart';
import '../Resource/state/game_state.dart';
import '../services/service_locator.dart';
import 'tv_campaign.dart';
import 'tv_menu.dart';
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
