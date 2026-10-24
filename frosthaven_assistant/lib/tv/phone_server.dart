import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Resource/commands/add_condition_command.dart';
import '../Resource/commands/change_stat_commands/change_health_command.dart';
import '../Resource/commands/change_stat_commands/change_xp_command.dart';
import '../Resource/commands/remove_condition_command.dart';
import '../Resource/commands/set_init_command.dart';
import '../Resource/commands/turn_done_command.dart';
import '../Resource/enums.dart';
import '../Resource/game_methods.dart';
import '../Resource/state/game_state.dart';
import '../services/service_locator.dart';
import 'phone_page.dart';
import 'tv_model.dart';
import 'tv_strings.dart';

/// Phone companion: the stick serves a small web page (http://ip:8080) that
/// players open by scanning the QR code on the TV. The page talks to this
/// server over a WebSocket: it receives the game state and sends commands,
/// which run through the normal GameState.action() path.
class PhoneServer {
  static const int port = 8080;
  static const _prefKey = 'tv_phone_server';

  static final running = ValueNotifier<bool>(false);
  static final clients = ValueNotifier<int>(0);
  static final url = ValueNotifier<String>('');

  static HttpServer? _server;
  static final List<WebSocket> _sockets = [];
  static String _code = '';
  static Timer? _debounce;
  static Listenable? _listening;

  static String get code => _code;

  /// Starts the server if it was on last time.
  static Future<void> restore() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_prefKey) ?? false) await start();
    } catch (_) {}
  }

  static Future<void> setEnabled(bool on) async {
    if (on) {
      await start();
    } else {
      await stop();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, on);
    } catch (_) {}
  }

  static Future<void> start() async {
    if (kIsWeb || _server != null) return;
    try {
      final server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
      _server = server;
      _code = await _loadOrCreateCode();
      server.listen(_handle, onError: (Object e) => debugPrint('phone: $e'));
      running.value = true;
      url.value = 'http://${await _localIp()}:$port/?k=$_code';
      _watchGame();
    } catch (e) {
      debugPrint('phone: start failed: $e');
      running.value = false;
    }
  }

  static Future<void> stop() async {
    _listening?.removeListener(_scheduleBroadcast);
    _listening = null;
    for (final s in List.of(_sockets)) {
      await s.close();
    }
    _sockets.clear();
    clients.value = 0;
    await _server?.close(force: true);
    _server = null;
    running.value = false;
    url.value = '';
  }

  /// The join code stays the same across restarts, so phones that already
  /// scanned the QR code reconnect by themselves.
  static Future<String> _loadOrCreateCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('tv_phone_code');
      if (saved != null && saved.length == 4) return saved;
      final c = (1000 + Random.secure().nextInt(9000)).toString();
      await prefs.setString('tv_phone_code', c);
      return c;
    } catch (_) {
      return (1000 + Random.secure().nextInt(9000)).toString();
    }
  }

  static Future<String> _localIp() async {
    try {
      final ifs = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final i in ifs) {
        for (final a in i.addresses) {
          if (!a.isLoopback && a.address.startsWith('192.168.')) return a.address;
        }
      }
      for (final i in ifs) {
        for (final a in i.addresses) {
          if (!a.isLoopback) return a.address;
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  static void _watchGame() {
    final gs = getIt<GameState>();
    _listening?.removeListener(_scheduleBroadcast);
    _listening = Listenable.merge([
      gs.commandIndex,
      gs.updateList,
      gs.currentListNotifier,
      gs.roundState,
      gs.round,
      TvLang.current,
    ]);
    _listening!.addListener(_scheduleBroadcast);
  }

  // ------------------------------------------------------------- http

  static Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
      final path = req.uri.path;
      final key = req.uri.queryParameters['k'];
      if (path == '/ws') {
        if (key != _code || !WebSocketTransformer.isUpgradeRequest(req)) {
          res.statusCode = HttpStatus.forbidden;
          await res.close();
          return;
        }
        final ws = await WebSocketTransformer.upgrade(req);
        _sockets.add(ws);
        clients.value = _sockets.length;
        ws.add(jsonEncode(_state()));
        ws.listen(
          (data) => _onMessage(data),
          onDone: () {
            _sockets.remove(ws);
            clients.value = _sockets.length;
          },
          onError: (_) {
            _sockets.remove(ws);
            clients.value = _sockets.length;
          },
        );
        return;
      }
      if (path.startsWith('/assets/images/') && !path.contains('..')) {
        // game artwork (class icons, condition icons, monsters)
        final asset = Uri.decodeComponent(path.substring(1));
        try {
          final data = await rootBundle.load(asset);
          res.headers.contentType = ContentType('image', 'png');
          res.headers.set('Cache-Control', 'max-age=86400');
          res.add(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
        } catch (_) {
          res.statusCode = HttpStatus.notFound;
        }
        await res.close();
        return;
      }
      if (path == '/' || path == '/index.html') {
        res.headers.contentType = ContentType.html;
        res.headers.set('Cache-Control', 'no-store');
        res.write(key == _code ? phonePageHtml : phoneLockedHtml);
        await res.close();
        return;
      }
      res.statusCode = HttpStatus.notFound;
      await res.close();
    } catch (e) {
      debugPrint('phone: request failed: $e');
      try {
        await res.close();
      } catch (_) {}
    }
  }

  // ------------------------------------------------------------- state

  static void _scheduleBroadcast() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), _broadcast);
  }

  static void _broadcast() {
    if (_sockets.isEmpty) return;
    final msg = jsonEncode(_state());
    for (final s in List.of(_sockets)) {
      try {
        s.add(msg);
      } catch (_) {}
    }
  }

  static String _hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  static Map<String, dynamic> _figure(FigureState f) => {
        'hp': f.health.value,
        'maxHp': f.maxHealth.value,
        'conditions': [
          for (final c in f.conditions.value)
            {'id': c.name, 'icon': conditionIconPath(c), 'name': trCondition(c)}
        ],
      };

  static Map<String, dynamic> _state() {
    final gs = getIt<GameState>();
    final chars = <Map<String, dynamic>>[];
    final monsters = <Map<String, dynamic>>[];
    for (final item in gs.currentList) {
      if (item is Character) {
        final st = item.characterState;
        final t = TvTarget(
            rowIndex: 0,
            item: item,
            figureId: item.id,
            ownerId: item.id,
            figure: st);
        chars.add({
          'id': item.id,
          'name': st.display.value,
          'className': item.characterClass.name,
          'color': _hex(item.characterClass.color.toARGB32()),
          'icon': classIconPath(item),
          'player': !GameMethods.isObjectiveOrEscort(item.characterClass),
          'level': st.level.value,
          'xp': st.xp.value,
          'init': st.initiative.value,
          'turn': item.turnState.value.name,
          ..._figure(st),
          'available': [
            for (final c in conditionsFor(t))
              {'id': c.name, 'icon': conditionIconPath(c), 'name': trCondition(c)}
          ],
          'summons': [
            for (final s in st.summonList)
              {
                'id': s.getId(),
                'name': s.name,
                'nr': s.standeeNr,
                ..._figure(s),
              }
          ],
        });
      } else if (item is Monster) {
        monsters.add({
          'id': item.id,
          'name': item.type.display,
          'icon': monsterImagePath(item),
          'init': rowInitiative(gs, item),
          'turn': item.turnState.value.name,
          'standees': [
            for (final m in item.monsterInstances)
              {
                'nr': m.standeeNr,
                'type': m.type.name,
                ..._figure(m),
              }
          ],
        });
      }
    }
    return {
      'type': 'state',
      'lang': TvLang.current.value,
      'scenario': gs.scenario.value,
      'round': gs.round.value,
      'phase': gs.roundState.value == RoundState.playTurns ? 'play' : 'init',
      'level': gs.level.value,
      'characters': chars,
      'monsters': monsters,
    };
  }

  // ------------------------------------------------------------- commands

  static void _onMessage(dynamic data) {
    if (data is! String) return;
    Map<String, dynamic> m;
    try {
      m = jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final gs = getIt<GameState>();
    final id = m['id'] as String? ?? '';
    final owner = m['owner'] as String? ?? id;
    final ch = gs.currentList.whereType<Character>().firstWhereOrNull((c) => c.id == owner);
    if (ch == null) return;
    // the figure: the character itself or one of its summons
    final FigureState? fig = id == ch.id
        ? ch.characterState
        : ch.characterState.summonList.firstWhereOrNull((s) => s.getId() == id);
    if (fig == null) return;

    switch (m['type']) {
      case 'hp':
        final d = (m['delta'] as num?)?.toInt() ?? 0;
        if (d == 0) return;
        if (d > 0 && fig.health.value >= hpCeiling(fig)) return;
        if (d < 0 && fig.health.value <= 0) return;
        gs.action(ChangeHealthCommand(d, id, ch.id, gameState: gs));
        break;
      case 'xp':
        final d = (m['delta'] as num?)?.toInt() ?? 0;
        if (d == 0 || id != ch.id) return;
        if (d < 0 && ch.characterState.xp.value <= 0) return;
        gs.action(ChangeXPCommand(d, ch.id, ch.id, gameState: gs));
        break;
      case 'init':
        final v = (m['value'] as num?)?.toInt() ?? 0;
        if (v < 1 || v > 99 || id != ch.id) return;
        if (gs.roundState.value != RoundState.chooseInitiative) return;
        gs.action(SetInitCommand(ch.id, v, gameState: gs));
        break;
      case 'cond':
        final c = Condition.values.firstWhereOrNull((e) => e.name == m['cond']);
        if (c == null) return;
        final has = fig.conditions.value.contains(c);
        final on = m['on'] == true;
        if (on && !has) {
          gs.action(AddConditionCommand(c, id, ch.id, gameState: gs));
        } else if (!on && has) {
          gs.action(RemoveConditionCommand(c, id, ch.id, gameState: gs));
        }
        break;
      case 'turnDone':
        if (gs.roundState.value != RoundState.playTurns) return;
        if (ch.turnState.value == TurnsState.done) return;
        gs.action(TurnDoneCommand(ch.id, gameState: gs));
        break;
    }
  }
}
