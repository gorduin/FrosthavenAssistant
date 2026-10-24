import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Campaign tracking of the TV UI (not part of the original app): named
/// campaigns, each with an edition, scenario progress and a party.
/// Stored on the device as JSON in SharedPreferences.

enum ScenarioProgress { none, unlocked, completed }

class PartyMember {
  PartyMember({
    required this.classId,
    required this.edition,
    required this.name,
    required this.level,
    required this.xp,
  });

  factory PartyMember.fromJson(Map<String, dynamic> j) => PartyMember(
        classId: j['classId'] as String,
        edition: j['edition'] as String? ?? '',
        name: j['name'] as String? ?? '',
        level: j['level'] as int? ?? 1,
        xp: j['xp'] as int? ?? 0,
      );

  final String classId;
  final String edition;
  String name;
  int level;
  int xp;

  Map<String, dynamic> toJson() => {
        'classId': classId,
        'edition': edition,
        'name': name,
        'level': level,
        'xp': xp,
      };
}

/// A scenario treasure (the numbered treasure tile) the party has looted.
class TreasureNote {
  TreasureNote({required this.nr, required this.scenario, required this.by});

  factory TreasureNote.fromJson(Map<String, dynamic> j) => TreasureNote(
        nr: j['nr'] as int? ?? 0,
        scenario: j['scenario'] as String? ?? '',
        by: j['by'] as String? ?? '',
      );

  final int nr;
  final String scenario;

  /// Name of the character who picked it up ('' if not recorded).
  final String by;

  Map<String, dynamic> toJson() => {'nr': nr, 'scenario': scenario, 'by': by};
}

class TvCampaign {
  TvCampaign({
    required this.id,
    required this.name,
    required this.edition,
    Map<String, ScenarioProgress>? progress,
    List<PartyMember>? party,
    List<TreasureNote>? treasures,
    Set<String>? randomItems,
  })  : progress = progress ?? {},
        party = party ?? [],
        treasures = treasures ?? [],
        randomItems = randomItems ?? {};

  factory TvCampaign.fromJson(Map<String, dynamic> j) {
    final prog = <String, ScenarioProgress>{};
    final raw = j['progress'];
    if (raw is Map) {
      raw.forEach((k, v) {
        final i = v is int ? v : 0;
        if (i > 0 && i < ScenarioProgress.values.length) {
          prog[k as String] = ScenarioProgress.values[i];
        }
      });
    }
    final party = <PartyMember>[];
    final rawParty = j['party'];
    if (rawParty is List) {
      for (final p in rawParty) {
        if (p is Map<String, dynamic>) party.add(PartyMember.fromJson(p));
      }
    }
    final treasures = <TreasureNote>[];
    final rawTreasures = j['treasures'];
    if (rawTreasures is List) {
      for (final t in rawTreasures) {
        if (t is Map<String, dynamic>) treasures.add(TreasureNote.fromJson(t));
      }
    }
    return TvCampaign(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      edition: j['edition'] as String? ?? 'Frosthaven',
      progress: prog,
      party: party,
      treasures: treasures,
      randomItems: {
        if (j['randomItems'] is List)
          for (final s in j['randomItems'] as List)
            if (s is String) s
      },
    );
  }

  final String id;
  String name;
  final String edition;
  final Map<String, ScenarioProgress> progress;
  final List<PartyMember> party;
  final List<TreasureNote> treasures;

  /// Scenarios whose Random Item loot card has been looted: on a replay the
  /// card gives nothing again.
  final Set<String> randomItems;

  TreasureNote? treasure(int nr) => treasures.where((t) => t.nr == nr).firstOrNull;

  ScenarioProgress of(String scenario) =>
      progress[scenario] ?? ScenarioProgress.none;

  int get completedCount =>
      progress.values.where((p) => p == ScenarioProgress.completed).length;
  int get unlockedCount =>
      progress.values.where((p) => p == ScenarioProgress.unlocked).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'edition': edition,
        'progress': {
          for (final e in progress.entries)
            if (e.value != ScenarioProgress.none) e.key: e.value.index,
        },
        'party': [for (final p in party) p.toJson()],
        'treasures': [for (final t in treasures) t.toJson()],
        'randomItems': randomItems.toList()..sort(),
      };
}

class TvCampaigns {
  static const _key = 'tv_campaigns';
  static const _activeKey = 'tv_campaign_active';

  /// Bumped on every change, so the UI can listen to one notifier.
  static final version = ValueNotifier<int>(0);
  static final List<TvCampaign> all = [];
  static String? _activeId;
  static bool _loaded = false;

  static TvCampaign? get active =>
      all.where((c) => c.id == _activeId).firstOrNull;

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final list = jsonDecode(raw);
        if (list is List) {
          for (final c in list) {
            if (c is Map<String, dynamic>) all.add(TvCampaign.fromJson(c));
          }
        }
      }
      _activeId = prefs.getString(_activeKey);
    } catch (e) {
      debugPrint('campaigns: load failed: $e');
    }
    version.value++;
  }

  static Future<void> _save() async {
    version.value++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key, jsonEncode([for (final c in all) c.toJson()]));
      final id = _activeId;
      if (id == null) {
        await prefs.remove(_activeKey);
      } else {
        await prefs.setString(_activeKey, id);
      }
    } catch (e) {
      debugPrint('campaigns: save failed: $e');
    }
  }

  static TvCampaign create(String name, String edition) {
    final c = TvCampaign(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      edition: edition,
    );
    all.add(c);
    _activeId = c.id;
    _save();
    return c;
  }

  static void activate(TvCampaign? c) {
    _activeId = c?.id;
    _save();
  }

  static void rename(TvCampaign c, String name) {
    c.name = name;
    _save();
  }

  static void delete(TvCampaign c) {
    all.remove(c);
    if (_activeId == c.id) _activeId = null;
    _save();
  }

  static void setProgress(TvCampaign c, String scenario, ScenarioProgress p) {
    if (p == ScenarioProgress.none) {
      c.progress.remove(scenario);
    } else {
      c.progress[scenario] = p;
    }
    _save();
  }

  /// none → unlocked → completed → none
  static void cycleProgress(TvCampaign c, String scenario) {
    final next = ScenarioProgress
        .values[(c.of(scenario).index + 1) % ScenarioProgress.values.length];
    setProgress(c, scenario, next);
  }

  /// Everything for a backup: all campaigns and the active one.
  static Map<String, dynamic> exportJson() => {
        'campaigns': [for (final c in all) c.toJson()],
        'active': _activeId,
      };

  /// Replaces the campaigns with the ones of a backup.
  static void importJson(Map<String, dynamic> j) {
    final list = j['campaigns'];
    if (list is! List) return;
    all
      ..clear()
      ..addAll([
        for (final c in list)
          if (c is Map<String, dynamic>) TvCampaign.fromJson(c)
      ]);
    final active = j['active'];
    _activeId = active is String && all.any((c) => c.id == active) ? active : null;
    _save();
  }

  /// Persist after editing a campaign or party member in place.
  static void changed() => _save();

  /// Records a looted treasure; the same number again replaces the old entry.
  static void addTreasure(TvCampaign c, TreasureNote t) {
    c.treasures
      ..removeWhere((e) => e.nr == t.nr)
      ..add(t)
      ..sort((a, b) => a.nr.compareTo(b.nr));
    _save();
  }

  static void setRandomItem(TvCampaign c, String scenario, bool looted) {
    if (looted) {
      c.randomItems.add(scenario);
    } else {
      c.randomItems.remove(scenario);
    }
    _save();
  }

  static void removeTreasure(TvCampaign c, TreasureNote t) {
    c.treasures.remove(t);
    _save();
  }

  static void setParty(TvCampaign c, List<PartyMember> party) {
    c.party
      ..clear()
      ..addAll(party);
    _save();
  }
}
