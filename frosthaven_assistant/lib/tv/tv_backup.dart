import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Resource/commands/load_save_command.dart';
import '../Resource/state/game_state.dart';
import 'tv_campaign.dart';

/// Off-device backup of the game state and the campaigns to the own web
/// space (backup-server/index.php). Address and key come from the build:
/// --dart-define-from-file=~/claude/keys/xhaven-backup.json
class TvBackup {
  static const _url = String.fromEnvironment('BACKUP_URL');
  static const _key = String.fromEnvironment('BACKUP_KEY');
  static const _lastKey = 'tv_backup_last_ok';

  static bool get configured => !kIsWeb && _url.isNotEmpty && _key.isNotEmpty;

  /// Time of the last successful backup, and the last error (empty if none).
  static final lastOk = ValueNotifier<DateTime?>(null);
  static final lastError = ValueNotifier<String>('');
  static final busy = ValueNotifier<bool>(false);

  static GameState? _gs;
  static Timer? _debounce;
  static String _lastSent = '';
  static Listenable? _watching;

  /// Starts the automatic backups: after a round ends, the scenario changes
  /// or the campaigns change (debounced), and retries while offline.
  static Future<void> start(GameState gs) async {
    if (!configured || _gs != null) return;
    _gs = gs;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_lastKey);
      if (ms != null) lastOk.value = DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {}
    _watching = Listenable.merge([gs.round, gs.scenario, TvCampaigns.version]);
    _watching!.addListener(_schedule);
    // retry while the last attempt failed (e.g. no network)
    Timer.periodic(const Duration(minutes: 10), (_) {
      if (lastError.value.isNotEmpty) backupNow('retry');
    });
  }

  static void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 8), () => backupNow('auto'));
  }

  static Map<String, dynamic> _payload(GameState gs, String reason) {
    final c = TvCampaigns.active;
    return {
      'created': DateTime.now().toIso8601String(),
      'reason': reason,
      'scenario': gs.scenario.value,
      'round': gs.round.value,
      'campaign': c?.name,
      'app': 'gorduin.xhaven',
      'gameState': gs.toString(),
      'tvCampaigns': TvCampaigns.exportJson(),
    };
  }

  static Uri _uri([String query = '']) {
    final base = _url.endsWith('/') ? _url : '$_url/';
    return Uri.parse(query.isEmpty ? base : '$base?$query');
  }

  static Future<(int, String)> _request(String method, Uri uri, {String? body}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.openUrl(method, uri);
      req.headers.set('X-Backup-Key', _key);
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.add(utf8.encode(body));
      }
      final res = await req.close().timeout(const Duration(seconds: 20));
      final text = await res.transform(utf8.decoder).join();
      return (res.statusCode, text);
    } finally {
      client.close(force: true);
    }
  }

  /// Uploads a backup now. Skips it when nothing changed since the last one
  /// (unless [force]). Returns true on success or when skipped.
  static Future<bool> backupNow(String reason, {bool force = false}) async {
    final gs = _gs;
    if (!configured || gs == null || busy.value) return false;
    final payload = _payload(gs, reason);
    final fingerprint = '${payload['gameState']}|${jsonEncode(payload['tvCampaigns'])}';
    if (!force && fingerprint == _lastSent) return true;
    busy.value = true;
    try {
      final (code, text) = await _request('POST', _uri(), body: jsonEncode(payload));
      if (code == 200) {
        _lastSent = fingerprint;
        lastError.value = '';
        lastOk.value = DateTime.now();
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(_lastKey, lastOk.value!.millisecondsSinceEpoch);
        } catch (_) {}
        return true;
      }
      lastError.value = 'HTTP $code ${text.length > 80 ? text.substring(0, 80) : text}';
    } catch (e) {
      lastError.value = e.toString().split('\n').first;
    } finally {
      busy.value = false;
    }
    return false;
  }

  /// Backups on the server, newest first.
  static Future<List<Map<String, dynamic>>> list() async {
    final (code, text) = await _request('GET', _uri('list'));
    if (code != 200) throw Exception('HTTP $code');
    final j = jsonDecode(text);
    final list = j is Map ? j['backups'] : null;
    if (list is! List) return [];
    return [for (final b in list) if (b is Map<String, dynamic>) b];
  }

  /// Loads a backup back: the game state (one undo step) and the campaigns.
  static Future<void> restore(String name) async {
    final gs = _gs;
    if (gs == null) return;
    final (code, text) = await _request('GET', _uri('file=${Uri.encodeQueryComponent(name)}'));
    if (code != 200) throw Exception('HTTP $code');
    final j = jsonDecode(text);
    if (j is! Map<String, dynamic> || j['gameState'] is! String) {
      throw Exception('not a backup');
    }
    gs.action(LoadSaveCommand(name, j['gameState'] as String, gameState: gs));
    final camps = j['tvCampaigns'];
    if (camps is Map<String, dynamic>) TvCampaigns.importJson(camps);
    // the restored state is the latest one: no need to upload it again
    _lastSent = '${gs.toString()}|${jsonEncode(TvCampaigns.exportJson())}';
  }
}
