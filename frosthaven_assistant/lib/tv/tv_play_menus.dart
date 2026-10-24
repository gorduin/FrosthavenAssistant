import 'package:flutter/material.dart';

import '../Layout/loot_card_widget.dart';
import '../Model/summon_model.dart';
import '../Resource/commands/add_standee_command.dart';
import '../Resource/commands/draw_loot_card_command.dart';
import '../Resource/commands/set_figure_note_command.dart';
import '../Resource/commands/set_loot_owner_command.dart';
import '../Resource/commands/set_scenario_command.dart';
import '../Resource/enums.dart';
import '../Resource/game_data.dart';
import '../Resource/game_methods.dart';
import '../Resource/settings.dart';
import '../Resource/stat_calculator.dart';
import '../Resource/state/game_state.dart';
import '../services/network/network.dart';
import '../services/service_locator.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'phone_server.dart';
import 'tv_campaign.dart';
import 'tv_campaign_menus.dart';
import 'tv_menu.dart';
import 'tv_backup.dart';
import 'tv_prefs.dart';
import 'tv_model.dart';
import 'tv_strings.dart';
import 'tv_theme.dart';

// ======================================================================
// Loot
// ======================================================================

bool hasLootDeck(GameState gs) =>
    !getIt<Settings>().hideLootDeck.value &&
    (gs.lootDeck.drawPileIsNotEmpty || gs.lootDeck.discardPileIsNotEmpty);

List<Character> _players() => GameMethods.getCurrentCharacters()
    .where((c) => !GameMethods.isObjectiveOrEscort(c.characterClass))
    .toList();

/// The loot deck's "treasure" card is the Random Item card (#1417).
bool _isRandomItem(LootCard c) => c.gfx == 'treasure';

/// Draws a loot card; the Random Item card is marked in the active campaign
/// for this scenario (a replay gives no new item, so that is announced).
void _drawLoot(BuildContext context, GameState gs) {
  gs.action(DrawLootCardCommand(gameState: gs));
  final deck = gs.lootDeck;
  if (!deck.discardPileIsNotEmpty || !_isRandomItem(deck.discardPileTop)) return;
  final c = TvCampaigns.active;
  if (c == null) return;
  final scenario = gs.scenario.value;
  if (c.randomItems.contains(scenario)) {
    TvToast.show(context, tr('randomItemAgain'), seconds: 6);
  } else {
    TvCampaigns.setRandomItem(c, scenario, true);
    TvToast.show(context, '${tr('randomItemMarked')}: $scenario', seconds: 5);
  }
}

Future<void> showLootMenu(BuildContext context, GameState gs) {
  const cardScale = 2.6;
  List<TvMenuRow> rows() {
    final deck = gs.lootDeck;
    final top = deck.discardPileIsNotEmpty ? deck.discardPileTop : null;
    final players = _players();
    final out = <TvMenuRow>[
      TvWidgetRow(() => Row(children: [
            SizedBox(
              width: 39 * cardScale,
              height: 58.67 * cardScale,
              child: top == null
                  ? Container(
                      decoration: BoxDecoration(
                        color: TvColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TvColors.line),
                      ),
                      alignment: Alignment.center,
                      child: Text(tr('noModCards'),
                          textAlign: TextAlign.center,
                          style: TvText.body(16, color: TvColors.dim)),
                    )
                  : LootCardFront(card: top, scale: cardScale),
            ),
            const SizedBox(width: 26),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(trCardsLeft(deck.drawPileSize), style: TvText.body(28)),
                const SizedBox(height: 10),
                for (final p in players)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${p.characterState.display.value}: '
                      '${trLootCards(deck.discardPileContents.where((c) => c.owner == p.characterClass.id).length)}',
                      style: TvText.body(20, color: TvColors.muted),
                    ),
                  ),
              ]),
            ),
          ])),
      TvButtonsRow([
        TvMenuButton(
          text: tr('drawLoot'),
          primary: true,
          onPressed: deck.drawPileIsEmpty
              ? null
              : () => _drawLoot(context, gs),
        ),
        TvMenuButton(
          text: tr('addTreasure'),
          onPressed: () async {
            if (context.mounted) await showTreasureMenu(context, gs);
          },
        ),
      ]),
    ];
    final camp = TvCampaigns.active;
    if (camp != null &&
        camp.randomItems.contains(gs.scenario.value) &&
        deck.drawPileContents.any(_isRandomItem)) {
      out.add(TvTextRow(tr('randomItemWarn')));
    }
    if (top != null && players.isNotEmpty) {
      out.add(TvButtonsRow([
        for (final p in players)
          TvMenuButton(
            text: p.characterState.display.value,
            icon: classIconPath(p),
            iconTint: classTint(p),
            active: top.owner == p.characterClass.id,
            onPressed: () =>
                gs.action(SetLootOwnerCommand(p.characterClass.id, top)),
          ),
      ], label: tr('lootOwner')));
    }
    out.add(TvButtonsRow([
      TvMenuButton(text: tr('close'), closes: true, onPressed: () {}),
    ]));
    return out;
  }

  return showTvMenu<void>(
    context,
    title: tr('loot'),
    subtitle: tr('lootSub'),
    rows: rows,
    rebuildOn: gs.commandIndex,
    width: 1100,
    start: (1, 0),
  );
}

// ======================================================================
// Scenario sections (doors opening etc.)
// ======================================================================

List<String> sectionsOf(GameState gs) {
  final gd = getIt<GameData>();
  final list = gd.modelData.value[gs.currentCampaign.value]
          ?.scenarios[gs.scenario.value]
          ?.sections
          .map((e) => e.name)
          .where((n) => !n.contains('spawn'))
          .toList() ??
      [];
  list.sort((a, b) {
    final an = GameMethods.findNrFromScenarioName(a);
    final bn = GameMethods.findNrFromScenarioName(b);
    if (an != null && bn != null) return an.compareTo(bn);
    return a.compareTo(b);
  });
  return list;
}

Future<void> showSectionMenu(BuildContext context, GameState gs) {
  final sections = sectionsOf(gs);
  List<TvMenuRow> rows() {
    final added = gs.scenarioSectionsAdded;
    return [
      ...tvGrid([
        for (final s in sections)
          () {
            final space = s.indexOf(' ');
            final title = space > 0 ? s.substring(0, space) : s;
            final sub = space > 0 ? s.substring(space + 1) : '';
            final isAdded = added.contains(s);
            return TvMenuButton(
              text: title,
              subtitle: sub,
              active: isAdded,
              closes: true,
              onPressed: isAdded
                  ? null
                  : () => gs.action(SetScenarioCommand(s, true, gameState: gs)),
            );
          }(),
      ], 4, label: tr('sections'), style: TvRowStyle.tiles),
      TvButtonsRow([
        TvMenuButton(text: tr('close'), closes: true, onPressed: () {}),
      ]),
    ];
  }

  return showTvMenu<void>(
    context,
    title: tr('sectionMenu'),
    subtitle: gs.scenario.value,
    rows: rows,
    rebuildOn: gs.commandIndex,
    start: (0, -1),
  );
}

// ======================================================================
// Character summons
// ======================================================================

Future<void> showSummonMenu(BuildContext context, GameState gs, Character ch) {
  final gd = getIt<GameData>();
  final custom = getIt<Settings>().showCustomContent.value;
  String color = 'blue';
  int nr = 1;
  const colors = ['blue', 'green', 'yellow', 'orange'];

  List<SummonModel> available() {
    final st = ch.characterState;
    final out = <SummonModel>[];
    for (final s in ch.characterClass.summons) {
      if (s.level > st.level.value) continue;
      final out_ = st.summonList.where((e) => e.name == s.name).length;
      if (out_ < s.standees) out.add(s);
    }
    final items = gd.itemSummonData.toList();
    if (!custom && items.length >= 4) items.removeRange(items.length - 4, items.length);
    out.addAll(items);
    return out;
  }

  void add(SummonModel m) {
    String gfx = color;
    int standeeNr = nr;
    if (m.gfx.isNotEmpty) {
      gfx = m.gfx;
      // single, pictured summons are not numbered
      if (m.standees < 2) standeeNr = 0;
    }
    final data = SummonData(
      standeeNr,
      m.name,
      StatCalculator.calculateFormula(m.health) ?? 2,
      m.move,
      m.attack,
      m.range,
      gfx,
    );
    gs.action(AddStandeeCommand(
        standeeNr, data, ch.id, MonsterType.summon, true,
        gameState: gs));
  }

  List<TvMenuRow> rows() {
    final list = available();
    return [
      TvButtonsRow([
        for (final c in colors)
          TvMenuButton(
            text: trSummonColor(c),
            icon: 'assets/images/summon/$c.png',
            active: color == c,
            onPressed: () => color = c,
          ),
      ], label: tr('summonColor')),
      TvButtonsRow([
        for (int n = 1; n <= 8; n++)
          TvMenuButton(text: '$n', active: nr == n, onPressed: () => nr = n),
      ], label: tr('summonNumber')),
      ...tvGrid([
        for (final m in list)
          TvMenuButton(
            text: m.name,
            subtitle: m.gfx.isEmpty ? '$color · $nr' : null,
            icon: 'assets/images/summon/${m.gfx.isEmpty ? color : m.gfx}.png',
            coverImage: true,
            closes: true,
            onPressed: () => add(m),
          ),
      ], 6, label: tr('summons'), style: TvRowStyle.pictures),
      TvButtonsRow([
        TvMenuButton(text: tr('close'), closes: true, onPressed: () {}),
      ]),
    ];
  }

  return showTvMenu<void>(
    context,
    title: tr('summonMenu'),
    subtitle: ch.characterState.display.value,
    image: classIconPath(ch),
    imageTint: classTint(ch),
    rows: rows,
    rebuildOn: gs.commandIndex,
    start: (2, -1),
  );
}

// ======================================================================
// Notes
// ======================================================================

Future<void> editNote(BuildContext context, GameState gs, ListItemData item,
    String name) async {
  final text = await showTvTextInput(
    context,
    title: tr('note'),
    subtitle: name,
    initial: item.note.value,
  );
  if (text == null) return;
  if (text == item.note.value) return;
  gs.action(SetFigureNoteCommand(text, item.id, gameState: gs));
}

// ======================================================================
// Settings and network
// ======================================================================

class _Toggle {
  const _Toggle(this.key, this.notifier, {this.invert = false});
  final String key;
  final ValueNotifier<bool> notifier;
  final bool invert;
}

Future<void> showTvSettings(BuildContext context, GameState gs,
    {required VoidCallback onClassicView}) {
  final settings = getIt<Settings>();
  final network = getIt<Network>();
  network.networkInfo.initNetworkInfo();

  final toggles = <_Toggle>[
    _Toggle('setInitRequired', settings.noInit, invert: true),
    _Toggle('setExpireConditions', settings.expireConditions),
    _Toggle('setAutoAddStandees', settings.autoAddStandees),
    _Toggle('setAutoAddSpawns', settings.autoAddSpawns),
    _Toggle('setRandomStandees', settings.randomStandees),
    _Toggle('setNoCalculation', settings.noCalculation),
    _Toggle('setBattleGoals', settings.showBattleGoalReminder),
    _Toggle('setReminders', settings.showReminders),
    _Toggle('setHideLoot', settings.hideLootDeck),
    _Toggle('setCustomContent', settings.showCustomContent),
  ];

  final rebuild = Listenable.merge([
    TvLang.current,
    PhoneServer.running,
    PhoneServer.clients,
    TvPrefs.hideEmptyMonsters,
    TvPrefs.hideMonsterCards,
    TvBackup.lastOk,
    TvBackup.lastError,
    TvBackup.busy,
    settings.server,
    network.networkInfo.wifiIPv6,
    for (final t in toggles) t.notifier,
  ]);

  List<TvMenuRow> rows() {
    final serverOn = settings.server.value;
    final ip = network.networkInfo.wifiIPv6.value;
    final port = settings.lastKnownPort;
    return [
      TvButtonsRow([
        TvMenuButton(
            text: 'Magyar',
            active: TvLang.current.value == 'hu',
            onPressed: () => TvLang.set('hu')),
        TvMenuButton(
            text: 'English',
            active: TvLang.current.value == 'en',
            onPressed: () => TvLang.set('en')),
      ], label: tr('language')),
      TvButtonsRow([
        TvMenuButton(text: tr('undo'), onPressed: () => gs.undo()),
        TvMenuButton(text: tr('redo'), onPressed: () => gs.redo()),
      ], label: tr('actions')),
      ...tvGrid([
        TvMenuButton(
          text: tr('setHideMonsterCards'),
          active: TvPrefs.hideMonsterCards.value,
          onPressed: () =>
              TvPrefs.setHideMonsterCards(!TvPrefs.hideMonsterCards.value),
        ),
        TvMenuButton(
          text: tr('setHideEmptyMonsters'),
          active: TvPrefs.hideEmptyMonsters.value,
          onPressed: () =>
              TvPrefs.setHideEmptyMonsters(!TvPrefs.hideEmptyMonsters.value),
        ),
        for (final t in toggles)
          TvMenuButton(
            text: tr(t.key),
            active: t.invert ? !t.notifier.value : t.notifier.value,
            onPressed: () {
              t.notifier.value = !t.notifier.value;
              settings.saveToDisk();
            },
          ),
      ], 3, label: tr('rules')),
      TvButtonsRow([
        TvMenuButton(
          text: PhoneServer.running.value ? tr('phonesOn') : tr('phonesOff'),
          active: PhoneServer.running.value,
          onPressed: () => PhoneServer.setEnabled(!PhoneServer.running.value),
        ),
        if (PhoneServer.running.value)
          TvMenuButton(
            text: tr('showQr'),
            primary: true,
            onPressed: () => showPhoneQr(context),
          ),
      ], label: tr('phones')),
      if (PhoneServer.running.value)
        TvTextRow('${PhoneServer.url.value} · ${trPhones(PhoneServer.clients.value)}'),
      TvButtonsRow([
        TvMenuButton(
          text: TvBackup.busy.value ? tr('backupBusy') : tr('backupNow'),
          onPressed: !TvBackup.configured || TvBackup.busy.value
              ? null
              : () async {
                  final ok = await TvBackup.backupNow('manual', force: true);
                  if (context.mounted) {
                    TvToast.show(context, ok ? tr('backupDone') : '${tr('backupFailed')}: ${TvBackup.lastError.value}');
                  }
                },
        ),
        TvMenuButton(
          text: tr('restoreBackup'),
          onPressed: !TvBackup.configured ? null : () => showRestoreMenu(context, gs),
        ),
      ], label: tr('backup')),
      TvTextRow(_backupStatus()),
      TvButtonsRow([
        TvMenuButton(
          text: serverOn ? tr('stopServer') : tr('startServer'),
          active: serverOn,
          onPressed: () {
            if (!settings.server.value) {
              settings.lastKnownHostIP = '(${network.networkInfo.wifiIPv6.value})';
              settings.saveToDisk();
              network.server.startServer();
            } else {
              network.server.stopServer(null);
            }
          },
        ),
      ], label: tr('network')),
      TvTextRow(serverOn
          ? trServerOn(ip.isEmpty ? '?' : ip, port)
          : tr('serverOffHint')),
      TvButtonsRow([
        TvMenuButton(text: tr('classicView'), closes: true, onPressed: onClassicView),
        TvMenuButton(text: tr('close'), primary: true, closes: true, onPressed: () {}),
      ]),
    ];
  }

  return showTvMenu<void>(
    context,
    title: tr('settings'),
    rows: rows,
    rebuildOn: rebuild,
    width: 1180,
  );
}


// ======================================================================
// Backup to the own web space
// ======================================================================

String _two(int n) => n.toString().padLeft(2, '0');

String _when(DateTime t) =>
    '${t.year}.${_two(t.month)}.${_two(t.day)}. ${_two(t.hour)}:${_two(t.minute)}';

String _backupStatus() {
  if (!TvBackup.configured) return tr('backupNotConfigured');
  final last = TvBackup.lastOk.value;
  final err = TvBackup.lastError.value;
  final parts = <String>[
    last == null ? tr('backupNever') : '${tr('backupLast')}: ${_when(last)}',
    if (err.isNotEmpty) '${tr('backupFailed')}: $err',
    tr('backupAuto'),
  ];
  return parts.join(' · ');
}

Future<void> showRestoreMenu(BuildContext context, GameState gs) async {
  List<Map<String, dynamic>> backups;
  try {
    TvToast.show(context, tr('backupLoading'));
    backups = await TvBackup.list();
  } catch (e) {
    if (context.mounted) TvToast.show(context, '${tr('backupFailed')}: $e');
    return;
  }
  if (!context.mounted) return;
  if (backups.isEmpty) {
    TvToast.show(context, tr('backupNone'));
    return;
  }
  String label(Map<String, dynamic> b) {
    final created = DateTime.tryParse('${b['created']}');
    return created == null ? '${b['name']}' : _when(created);
  }

  await showTvMenu<void>(
    context,
    title: tr('restoreBackup'),
    subtitle: tr('restoreSub'),
    rows: () => [
      ...tvGrid([
        for (final b in backups)
          TvMenuButton(
            text: label(b),
            subtitle: [
              if (b['scenario'] != null && '${b['scenario']}'.isNotEmpty) '${b['scenario']}',
              if (b['round'] != null) '${b['round']}. ${tr('round')}',
            ].join(' · '),
            closes: true,
            onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) _confirmRestore(context, gs, b['name'] as String, label(b));
            }),
          ),
      ], 3, label: tr('backups'), style: TvRowStyle.tiles),
      TvButtonsRow([
        TvMenuButton(text: tr('close'), closes: true, onPressed: () {}),
      ]),
    ],
  );
}

Future<void> _confirmRestore(
    BuildContext context, GameState gs, String name, String label) {
  return showTvMenu<void>(
    context,
    title: tr('restoreQ'),
    subtitle: '$label — ${tr('restoreWarn')}',
    width: 1000,
    rows: () => [
      TvButtonsRow([
        TvMenuButton(text: tr('cancel'), closes: true, onPressed: () {}),
        TvMenuButton(
          text: tr('restore'),
          primary: true,
          closes: true,
          onPressed: () async {
            try {
              await TvBackup.restore(name);
              if (context.mounted) TvToast.show(context, tr('restored'));
            } catch (e) {
              if (context.mounted) TvToast.show(context, '${tr('backupFailed')}: $e');
            }
          },
        ),
      ]),
    ],
  );
}

// ======================================================================
// Phone companion QR code
// ======================================================================

Future<void> showPhoneQr(BuildContext context) async {
  if (!PhoneServer.running.value) await PhoneServer.setEnabled(true);
  if (!context.mounted) return;
  return showTvMenu<void>(
    context,
    title: tr('phones'),
    subtitle: tr('qrSub'),
    width: 1100,
    rebuildOn: Listenable.merge([PhoneServer.clients, PhoneServer.url]),
    rows: () => [
      TvWidgetRow(() => Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: QrImageView(
                data: PhoneServer.url.value,
                size: 380,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 36),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('qrStep1'), style: TvText.body(24)),
                const SizedBox(height: 14),
                Text(tr('qrStep2'), style: TvText.body(24)),
                const SizedBox(height: 14),
                Text(tr('qrStep3'), style: TvText.body(24)),
                const SizedBox(height: 26),
                Text(PhoneServer.url.value,
                    style: TvText.body(20, color: TvColors.focus)),
                const SizedBox(height: 10),
                Text(trPhones(PhoneServer.clients.value),
                    style: TvText.body(22, color: TvColors.muted)),
              ]),
            ),
          ])),
      TvButtonsRow([
        TvMenuButton(text: tr('close'), primary: true, closes: true, onPressed: () {}),
      ]),
    ],
  );
}
