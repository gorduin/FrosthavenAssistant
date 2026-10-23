import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../Resource/commands/change_stat_commands/change_health_command.dart';
import '../Resource/commands/draw_modifier_card_command.dart';
import '../Resource/commands/imbue_element_command.dart';
import '../Resource/commands/reorder_list_command.dart';
import '../Resource/commands/use_element_command.dart';
import '../Resource/enums.dart';
import '../Resource/game_actions.dart';
import '../Resource/game_methods.dart';
import '../Resource/state/game_state.dart';
import '../services/network/network.dart';
import '../services/service_locator.dart';
import 'tv_figure_menu.dart';
import 'tv_menu.dart';
import 'phone_server.dart';
import 'tv_campaign.dart';
import 'tv_combat.dart';
import 'tv_prefs.dart';
import 'tv_model.dart';
import 'tv_play_menus.dart';
import 'tv_setup_menus.dart';
import 'tv_strings.dart';
import 'tv_theme.dart';
import 'tv_widgets.dart';

/// Switches between the TV UI and the original (touch) UI.
final tvClassicView = ValueNotifier<bool>(false);

enum _Zone { header, list, footer }

/// The TV main game screen: initiative list on the left, details on the
/// right, driven entirely by the D-pad.
class TvHomeScreen extends StatefulWidget {
  const TvHomeScreen({super.key});

  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends State<TvHomeScreen> {
  static const _kLongPress = Duration(milliseconds: 600);
  static const _kHeaderCount = 8; // 6 elements, undo, settings

  final GameState _gs = getIt<GameState>();
  final _focus = FocusNode(debugLabel: 'tv-home');
  final _scroll = ScrollController();
  final Map<int, GlobalKey> _rowKeys = {};

  _Zone _zone = _Zone.list;
  int _headerIdx = 0;
  int _footerIdx = 0;
  String? _selectedKey;
  int _selectedIdx = 0;

  /// Row index being moved, or null.
  int? _reorderRow;

  Timer? _okTimer;
  bool _okLongFired = false;
  bool _okDown = false;
  DateTime _lastHpRepeat = DateTime.fromMillisecondsSinceEpoch(0);
  bool _menuOpen = false;

  late final Listenable _changes = Listenable.merge([
    _gs.commandIndex,
    _gs.updateList,
    _gs.currentListNotifier,
    _gs.roundState,
    _gs.round,
    _gs.level,
    _gs.scenario,
    for (final e in Elements.values) _gs.elementStateFor(e),
    TvLang.current,
    TvCampaigns.version,
    TvPrefs.hideEmptyMonsters,
    TvPrefs.hideMonsterCards,
    PhoneServer.running,
    PhoneServer.clients,
  ]);

  @override
  void initState() {
    super.initState();
    _changes.addListener(_onGameChanged);
    _gs.pendingAutoAddDialog.addListener(_checkPendingStandees);
    _gs.toastMessage.addListener(_onToastMessage);
    getIt<Network>().networkMessage.addListener(_onNetworkMessage);
    unawaited(TvLang.load());
    unawaited(TvCampaigns.load());
    unawaited(TvPrefs.load());
    unawaited(PhoneServer.restore());
    _refocusTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _keepFocus();
    });
  }

  Timer? _refocusTimer;

  /// Focus can get lost (the view or app loses focus and Flutter falls back to
  /// the root scope); while this screen is on top it takes the focus back.
  void _keepFocus() {
    if (!mounted || _focus.hasFocus) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    _focus.requestFocus();
  }

  /// Scenario start: the game asks for standees to be placed. Runs as soon as
  /// no other menu is open (the scenario menu closes right after setting it).
  void _checkPendingStandees() {
    final data = _gs.pendingAutoAddDialog.value;
    if (data == null || _menuOpen || !mounted) return;
    _gs.pendingAutoAddDialog.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openMenu(() => runAutoAddStandees(context, _gs, data));
    });
  }

  void _onNetworkMessage() {
    final msg = getIt<Network>().networkMessage.value;
    if (msg.isEmpty || !mounted) return;
    TvToast.show(context, msg, seconds: 5);
  }

  /// Game messages (e.g. "remember to choose your battle goals").
  void _onToastMessage() {
    final msg = _gs.toastMessage.value;
    if (msg.isEmpty || !mounted) return;
    TvToast.show(context, msg, seconds: 7);
  }

  @override
  void dispose() {
    _changes.removeListener(_onGameChanged);
    _gs.pendingAutoAddDialog.removeListener(_checkPendingStandees);
    _gs.toastMessage.removeListener(_onToastMessage);
    getIt<Network>().networkMessage.removeListener(_onNetworkMessage);
    _okTimer?.cancel();
    _refocusTimer?.cancel();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onGameChanged() {
    if (!mounted) return;
    setState(() {});
    _scheduleScroll();
  }

  // ---------------------------------------------------------------- selection

  List<TvTarget> get _targets => buildTargets(_gs);

  /// Resolves the current selection, keeping it on the same figure when the
  /// list changes (sorting, deaths) and falling back to the same position.
  TvTarget? _resolveSelection(List<TvTarget> targets) {
    if (targets.isEmpty) return null;
    if (_selectedKey != null) {
      final i = targets.indexWhere((t) => t.key == _selectedKey);
      if (i >= 0) {
        _selectedIdx = i;
        return targets[i];
      }
    }
    _selectedIdx = _selectedIdx.clamp(0, targets.length - 1);
    final t = targets[_selectedIdx];
    _selectedKey = t.key;
    return t;
  }

  void _select(List<TvTarget> targets, int idx) {
    if (targets.isEmpty) return;
    idx = idx.clamp(0, targets.length - 1);
    setState(() {
      _selectedIdx = idx;
      _selectedKey = targets[idx].key;
    });
    _scheduleScroll();
  }

  void _scheduleScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _zone != _Zone.list) return;
      final t = _resolveSelection(_targets);
      final row = _reorderRow ?? t?.rowIndex;
      if (row == null) return;
      final ctx = _rowKeys[row]?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(ctx,
          alignment: 0.5,
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit);
    });
  }

  // ---------------------------------------------------------------- actions

  void _changeHealth(TvTarget t, int delta) {
    final fig = t.figure;
    if (fig == null) return;
    final hp = fig.health.value;
    if (delta > 0 && hp >= fig.maxHealth.value) return;
    if (delta < 0 && hp <= 0) return;
    _gs.action(ChangeHealthCommand(delta, t.figureId, t.ownerId, gameState: _gs));
  }

  void _drawOrNextRound() {
    final isDraw = _gs.roundState.value == RoundState.chooseInitiative;
    if (isDraw && !GameMethods.canDraw()) {
      TvToast.show(context,
          _gs.currentList.isEmpty ? tr('blockedNoChars') : tr('blockedInit'));
      return;
    }
    runDrawOrNextRoundAction(_gs);
    // guided combat starts right after the draw
    if (isDraw && _gs.roundState.value == RoundState.playTurns) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_menuOpen) _openCombat();
      });
    }
  }

  String _turnName(ListItemData item) {
    if (item is Character) return item.characterState.display.value;
    if (item is Monster) return item.type.display;
    return item.id;
  }

  void _openCombat() => _openMenu(() => showCombatGuide(context, _gs));

  void _drawModifier() {
    _gs.action(DrawModifierCardCommand('', gameState: _gs));
  }

  void _undo() {
    if (_gs.commandIndex.value < 0) {
      TvToast.show(context, tr('nothingToUndo'));
      return;
    }
    final desc = _gs.commandDescriptions.isNotEmpty &&
            _gs.commandIndex.value < _gs.commandDescriptions.length
        ? _gs.commandDescriptions[_gs.commandIndex.value]
        : '';
    _gs.undo();
    TvToast.show(context, desc.isEmpty ? tr('undone') : '${tr('undone')}: $desc');
  }

  void _elementTap(Elements e, {bool half = false}) {
    if (half) {
      _gs.action(ImbueElementCommand(e, true, gameState: _gs));
      return;
    }
    final st = _gs.elementState[e];
    if (st == ElementState.full || st == ElementState.half) {
      _gs.action(UseElementCommand(e, gameState: _gs));
    } else {
      _gs.action(ImbueElementCommand(e, false, gameState: _gs));
    }
  }

  Future<void> _openMenu(Future<void> Function() open) async {
    _menuOpen = true;
    try {
      await open();
    } finally {
      _menuOpen = false;
      if (mounted) {
        _focus.requestFocus();
        setState(() {});
        _checkPendingStandees();
      }
    }
  }

  void _openSettings() {
    _openMenu(() => showTvSettings(context, _gs, onClassicView: () {
          tvClassicView.value = true;
          TvToast.show(context, tr('classicHint'));
        }));
  }


  void _confirmExit() {
    _openMenu(() => showTvMenu<void>(
          context,
          title: tr('exitTitle'),
          width: 760,
          rows: () => [
            TvButtonsRow([
              TvMenuButton(text: tr('cancel'), closes: true, onPressed: () {}),
              TvMenuButton(
                  text: tr('exitYes'),
                  primary: true,
                  closes: true,
                  onPressed: () => SystemNavigator.pop()),
            ]),
          ],
        ));
  }

  void _openFigureMenu(TvTarget t) {
    _openMenu(() => showFigureMenu(context, _gs, t));
  }

  // ---------------------------------------------------------------- keys

  bool _isOk(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.select ||
      k == LogicalKeyboardKey.enter ||
      k == LogicalKeyboardKey.numpadEnter ||
      k == LogicalKeyboardKey.gameButtonA;

  bool _isBack(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.escape ||
      k == LogicalKeyboardKey.goBack ||
      k == LogicalKeyboardKey.browserBack;

  /// Back acts on key *up*, and only for a press that started here: Android
  /// performs its own back navigation on an unhandled up event, so a dialog
  /// opened on key down would be popped again by the same press.
  bool _backDown = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    final k = e.logicalKey;
    if (_isBack(k)) {
      if (_menuOpen) return KeyEventResult.handled;
      if (e is KeyDownEvent) {
        _backDown = true;
      } else if (e is KeyUpEvent && _backDown) {
        _backDown = false;
        _onBack();
      }
      return KeyEventResult.handled;
    }
    if (_menuOpen) return KeyEventResult.ignored;

    if (_isOk(k)) {
      if (e is KeyDownEvent) {
        _okDown = true;
        _okLongFired = false;
        _okTimer?.cancel();
        _okTimer = Timer(_kLongPress, () {
          if (!_okDown) return;
          _okLongFired = true;
          _onOk(long: true);
        });
      } else if (e is KeyUpEvent) {
        final wasDown = _okDown;
        _okDown = false;
        _okTimer?.cancel();
        if (wasDown && !_okLongFired) _onOk(long: false);
      }
      return KeyEventResult.handled;
    }

    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final repeat = e is KeyRepeatEvent;

    final targets = _targets;
    _resolveSelection(targets);

    switch (_zone) {
      case _Zone.list:
        return _onListKey(k, repeat, targets);
      case _Zone.header:
        if (repeat) return KeyEventResult.handled;
        if (k == LogicalKeyboardKey.arrowLeft) {
          setState(() => _headerIdx = (_headerIdx - 1).clamp(0, _kHeaderCount - 1));
        } else if (k == LogicalKeyboardKey.arrowRight) {
          setState(() => _headerIdx = (_headerIdx + 1).clamp(0, _kHeaderCount - 1));
        } else if (k == LogicalKeyboardKey.arrowDown) {
          setState(() => _zone = _Zone.list);
          _scheduleScroll();
        } else if (k != LogicalKeyboardKey.arrowUp) {
          return KeyEventResult.ignored;
        }
        return KeyEventResult.handled;
      case _Zone.footer:
        if (repeat) return KeyEventResult.handled;
        final n = _footerButtons().length;
        if (k == LogicalKeyboardKey.arrowLeft) {
          setState(() => _footerIdx = (_footerIdx - 1).clamp(0, n - 1));
        } else if (k == LogicalKeyboardKey.arrowRight) {
          setState(() => _footerIdx = (_footerIdx + 1).clamp(0, n - 1));
        } else if (k == LogicalKeyboardKey.arrowUp) {
          setState(() => _zone = _Zone.list);
          _scheduleScroll();
        } else if (k != LogicalKeyboardKey.arrowDown) {
          return KeyEventResult.ignored;
        }
        return KeyEventResult.handled;
    }
  }

  KeyEventResult _onListKey(
      LogicalKeyboardKey k, bool repeat, List<TvTarget> targets) {
    // reorder mode: ▲▼ move the row
    final moving = _reorderRow;
    if (moving != null) {
      if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowDown) {
        final d = k == LogicalKeyboardKey.arrowUp ? -1 : 1;
        final len = _gs.currentList.length;
        final to = moving + d;
        if (to >= 0 && to < len) {
          // insert(newIndex, removeAt(oldIndex)): newIndex is the final position
          _gs.action(ReorderListCommand(to, moving, gameState: _gs));
          setState(() => _reorderRow = to);
          _scheduleScroll();
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowUp) {
      if (repeat) return KeyEventResult.handled;
      if (_selectedIdx <= 0 || targets.isEmpty) {
        setState(() => _zone = _Zone.header);
      } else {
        _select(targets, _selectedIdx - 1);
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown) {
      if (repeat) return KeyEventResult.handled;
      if (targets.isEmpty || _selectedIdx >= targets.length - 1) {
        setState(() {
          _zone = _Zone.footer;
          _footerIdx = _footerIdx.clamp(0, _footerButtons().length - 1);
        });
      } else {
        _select(targets, _selectedIdx + 1);
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowRight) {
      if (targets.isEmpty) return KeyEventResult.handled;
      if (repeat) {
        final now = DateTime.now();
        if (now.difference(_lastHpRepeat).inMilliseconds < 160) {
          return KeyEventResult.handled;
        }
        _lastHpRepeat = now;
      }
      final t = targets[_selectedIdx.clamp(0, targets.length - 1)];
      _changeHealth(t, k == LogicalKeyboardKey.arrowLeft ? -1 : 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onOk({required bool long}) {
    if (_menuOpen) return;
    switch (_zone) {
      case _Zone.list:
        if (_reorderRow != null) {
          setState(() => _reorderRow = null);
          return;
        }
        final targets = _targets;
        final t = _resolveSelection(targets);
        if (t == null) return;
        if (long) {
          setState(() => _reorderRow = t.rowIndex);
        } else {
          _openFigureMenu(t);
        }
        return;
      case _Zone.header:
        if (_headerIdx < Elements.values.length) {
          _elementTap(Elements.values[_headerIdx], half: long);
        } else if (_headerIdx == 6) {
          _undo();
        } else {
          _openSettings();
        }
        return;
      case _Zone.footer:
        final buttons = _footerActions();
        final i = _footerIdx.clamp(0, buttons.length - 1);
        buttons[i]();
        return;
    }
  }

  void _onBack() {
    if (_reorderRow != null) {
      setState(() => _reorderRow = null);
      return;
    }
    if (_zone != _Zone.list) {
      setState(() => _zone = _Zone.list);
      _scheduleScroll();
      return;
    }
    _confirmExit();
  }

  List<(TvFooterButton, VoidCallback)> _footer() {
    final isDraw = _gs.roundState.value == RoundState.chooseInitiative;
    return [
      if (!isDraw)
        (
          TvFooterButton(
              currentTurnItem(_gs) == null
                  ? tr('combatBtn')
                  : '${tr('combatBtn')} · ${trTurnOf(_turnName(currentTurnItem(_gs)!))}',
              primary: true,
              icon: Icons.sports_martial_arts),
          _openCombat
        ),
      (
        TvFooterButton(isDraw ? tr('draw') : tr('nextRound'),
            primary: isDraw,
            icon: isDraw ? Icons.style : Icons.skip_next),
        _drawOrNextRound
      ),
      (TvFooterButton(tr('drawModifier'), icon: Icons.layers), _drawModifier),
      if (hasLootDeck(_gs))
        (
          TvFooterButton(tr('btnLoot'), icon: Icons.diamond_outlined),
          () => _openMenu(() => showLootMenu(context, _gs))
        ),
      if (sectionsOf(_gs).isNotEmpty)
        (
          TvFooterButton(tr('btnSection'), icon: Icons.door_front_door_outlined),
          () => _openMenu(() => showSectionMenu(context, _gs))
        ),
      (
        TvFooterButton(tr('btnDeck'), icon: Icons.tune),
        () => _openMenu(() => showDeckMenu(context, _gs))
      ),
      (
        TvFooterButton(tr('btnScenario'), icon: Icons.map_outlined),
        () => _openMenu(() => showScenarioMenu(context, _gs))
      ),
      (
        TvFooterButton(tr('btnAddChar'), icon: Icons.person_add_alt_1),
        () => _openMenu(() => showAddCharacterMenu(context, _gs))
      ),
      (
        TvFooterButton(tr('btnAddMonster'), icon: Icons.add_circle_outline),
        () => _openMenu(() => showAddMonsterMenu(context, _gs))
      ),
    ];
  }

  List<TvFooterButton> _footerButtons() => [for (final f in _footer()) f.$1];
  List<VoidCallback> _footerActions() => [for (final f in _footer()) f.$2];

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final targets = _targets;
    final selected = _resolveSelection(targets);
    final list = _gs.currentList;
    final listFocused = _zone == _Zone.list;

    String hint;
    if (_reorderRow != null) {
      hint = tr('reorderHint');
    } else if (_zone == _Zone.header) {
      hint = tr('hintHeader');
    } else if (_zone == _Zone.footer) {
      hint = tr('hintFooter');
    } else {
      hint = tr('hint');
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_menuOpen) _onBack();
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: ColoredBox(
          color: TvColors.bg,
          child: TvStage(
            child: Stack(children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.18,
                  child: Image.asset('assets/images/bg/dark_bg.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox()),
                ),
              ),
              const Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0, -0.2),
                        radius: 1.0,
                        colors: [Color(0x00000000), Color(0x8C000000)],
                        stops: [0.55, 1],
                      ),
                    ),
                  ),
                ),
              ),
              // ---------- list
              Positioned(
                left: 56,
                top: 140,
                width: 1150,
                bottom: 112,
                child: list.isEmpty
                    ? Center(
                        child: tvText(tr('emptyList'),
                            TvText.body(26, color: TvColors.muted),
                            textAlign: TextAlign.center),
                      )
                    : SingleChildScrollView(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(children: [
                          for (int i = 0; i < list.length; i++) ...[
                            if (list[i] is Character ||
                                (list[i] is Monster && monsterVisible(list[i] as Monster)))
                              Padding(
                                key: _rowKeys.putIfAbsent(i, () => GlobalKey()),
                                padding: const EdgeInsets.only(bottom: 14),
                                child: TvListRow(
                                  gs: _gs,
                                  item: list[i],
                                  selectedKey: selected?.key,
                                  listFocused: listFocused && _reorderRow == null,
                                  reordering: _reorderRow == i,
                                ),
                              ),
                            if (list[i] is NoteRow)
                              Padding(
                                key: _rowKeys.putIfAbsent(i, () => GlobalKey()),
                                padding: const EdgeInsets.only(bottom: 14),
                                child: TvNoteRow(note: list[i] as NoteRow),
                              ),
                          ],
                        ]),
                      ),
              ),
              // ---------- right panels
              Positioned(
                left: 1250,
                right: 56,
                top: 140,
                bottom: 112,
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(children: [
                    TvSelectedPanel(target: selected),
                    const SizedBox(height: 10),
                    TvAbilityPanel(
                        gs: _gs,
                        monster: cardMonsterFor(_gs, selected),
                        compact: selected?.item is Monster),
                    const SizedBox(height: 10),
                    TvModifierPanel(gs: _gs, focused: false),
                  ]),
                ),
              ),
              // ---------- header / footer
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: TvHeader(
                    gs: _gs,
                    focusIndex: _zone == _Zone.header ? _headerIdx : null),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: TvFooter(
                  buttons: _footerButtons(),
                  focusIndex: _zone == _Zone.footer ? _footerIdx : null,
                  hint: hint,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
