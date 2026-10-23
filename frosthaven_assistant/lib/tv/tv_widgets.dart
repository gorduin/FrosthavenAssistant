import 'package:flutter/material.dart';

import '../Layout/ModifierCardWidget/modifier_card_front.dart';
import '../Layout/MonsterAbilityCardWidget/monster_ability_card_front.dart';
import '../Resource/app_constants.dart';
import '../Resource/enums.dart';
import '../Resource/game_methods.dart';
import '../Resource/state/game_state.dart';
import 'tv_model.dart';
import 'tv_strings.dart';
import 'tv_theme.dart';

Color elementColor(Elements e) {
  switch (e) {
    case Elements.fire:
      return TvColors.fire;
    case Elements.ice:
      return TvColors.ice;
    case Elements.air:
      return TvColors.air;
    case Elements.earth:
      return TvColors.earth;
    case Elements.light:
      return TvColors.light;
    case Elements.dark:
      return TvColors.dark;
  }
}

const _grey = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

Widget _img(String path,
        {double? w, double? h, BoxFit fit = BoxFit.contain, Color? color}) =>
    Image.asset(path,
        width: w,
        height: h,
        fit: fit,
        color: color,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => SizedBox(width: w, height: h));

// ======================================================================
// Header
// ======================================================================

class TvHeader extends StatelessWidget {
  const TvHeader({
    super.key,
    required this.gs,
    required this.focusIndex,
  });

  final GameState gs;

  /// 0-5 elements, 6 undo, 7 settings; null when the header is not focused.
  final int? focusIndex;

  @override
  Widget build(BuildContext context) {
    final scenario = gs.scenario.value;
    final chars = GameMethods.getCurrentCharacters().length;
    final campaign = gs.currentCampaign.value;
    final playing = gs.roundState.value == RoundState.playTurns;
    final round = gs.round.value;
    final total = gs.totalRounds.value;
    return Container(
      height: 116,
      padding: const EdgeInsets.symmetric(horizontal: 56),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF20A1018), Color(0x990A1018)],
        ),
        border: Border(bottom: BorderSide(color: TvColors.line)),
      ),
      child: Row(children: [
        SizedBox(
          width: 560,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(scenario.isEmpty ? 'X-haven' : scenario,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TvText.title(44)),
              const SizedBox(height: 4),
              Text(
                [campaign.toUpperCase(), trPlayers(chars).toUpperCase()]
                    .where((s) => s.isNotEmpty)
                    .join(' · '),
                style: TvText.label(19, color: TvColors.muted),
              ),
            ],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('$round', style: TvText.title(72)),
            if (total != round)
              Text(' ($total)', style: TvText.body(22, color: TvColors.muted)),
            const SizedBox(width: 12),
            Text(tr('round').toUpperCase(),
                style: TvText.label(19, color: TvColors.muted)),
          ],
        ),
        const SizedBox(width: 40),
        _chip(
            child: Row(children: [
          _img('assets/images/psd/level.png', w: 28, h: 28),
          const SizedBox(width: 10),
          Text('${tr('level')} ${gs.level.value}', style: TvText.body(22)),
        ])),
        const SizedBox(width: 12),
        _chip(
          highlight: !playing,
          child: Text(playing ? tr('phasePlay') : tr('phaseInit'),
              style: TvText.body(20,
                  color: playing ? TvColors.muted : TvColors.focus)),
        ),
        const Spacer(),
        for (final e in Elements.values) ...[
          TvElementTile(
              element: e,
              state: gs.elementState[e] ?? ElementState.inert,
              focused: focusIndex == e.index),
          const SizedBox(width: 14),
        ],
        const SizedBox(width: 18),
        _sysButton(Icons.undo, focusIndex == 6),
        const SizedBox(width: 12),
        _sysButton(Icons.settings, focusIndex == 7),
      ]),
    );
  }

  Widget _chip({required Widget child, bool highlight = false}) => Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: TvColors.panel2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: highlight ? const Color(0x664FF2FF) : TvColors.line),
        ),
        alignment: Alignment.center,
        child: child,
      );

  Widget _sysButton(IconData icon, bool focused) => Container(
        width: 60,
        height: 60,
        decoration: focused
            ? tvFocusRing(radius: 12, fill: TvColors.panel2)
            : tvPanel(color: TvColors.panel2, radius: 12),
        child: Icon(icon,
            size: 30, color: focused ? TvColors.fg : TvColors.muted),
      );
}

class TvElementTile extends StatelessWidget {
  const TvElementTile(
      {super.key,
      required this.element,
      required this.state,
      required this.focused});

  final Elements element;
  final ElementState state;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final c = elementColor(element);
    final on = state != ElementState.inert;
    final List<BoxShadow> shadows = [];
    if (state == ElementState.full) {
      shadows.add(BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 28));
    }
    if (focused) {
      shadows.add(const BoxShadow(color: Color(0x994FF2FF), blurRadius: 22));
    }
    Color border = TvColors.line;
    double bw = 1;
    if (state == ElementState.full) {
      border = c;
      bw = 2;
    } else if (state == ElementState.half) {
      border = c.withValues(alpha: 0.55);
      bw = 2;
    }
    if (focused) {
      border = TvColors.focus;
      bw = 3;
    }
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        color: TvColors.panel2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: bw),
        boxShadow: shadows,
      ),
      child: Stack(children: [
        Center(
          child: on
              ? _img(elementIconPath(element), w: 46, h: 46)
              : Opacity(
                  opacity: 0.3,
                  child: ColorFiltered(
                      colorFilter: _grey,
                      child: _img(elementIconPath(element), w: 46, h: 46)),
                ),
        ),
        if (on)
          Positioned(
            left: 10,
            right: 10,
            bottom: 7,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  colors: state == ElementState.full
                      ? [c, c]
                      : [c, c, const Color(0x1FFFFFFF), const Color(0x1FFFFFFF)],
                  stops: state == ElementState.full
                      ? const [0, 1]
                      : const [0, 0.5, 0.5, 1],
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

// ======================================================================
// List rows
// ======================================================================

class TvHpBar extends StatelessWidget {
  const TvHpBar({super.key, required this.hp, required this.max, this.height = 10});
  final int hp;
  final int max;
  final double height;

  @override
  Widget build(BuildContext context) {
    final f = max <= 0 ? 0.0 : (hp / max).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Container(
        height: height,
        color: TvColors.hpBg,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: f,
          heightFactor: 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              gradient: const LinearGradient(
                  colors: [TvColors.hpLight, TvColors.hp]),
            ),
          ),
        ),
      ),
    );
  }
}

class TvConditionIcons extends StatelessWidget {
  const TvConditionIcons(
      {super.key, required this.figure, this.size = 36, this.max = 6});
  final FigureState figure;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    final conds = figure.conditions.value;
    final shown = conds.take(max).toList();
    final extra = conds.length - shown.length;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final c in shown)
        Padding(
          padding: EdgeInsets.only(right: size * 0.15),
          child: _img(conditionIconPath(c),
              w: size, h: size, color: conditionTint(c)),
        ),
      if (extra > 0)
        Text('+$extra',
            style: TvText.body(size * 0.55,
                color: TvColors.muted, weight: FontWeight.w700)),
    ]);
  }
}

/// One row of the initiative list (character or monster group).
class TvListRow extends StatelessWidget {
  const TvListRow({
    super.key,
    required this.gs,
    required this.item,
    required this.selectedKey,
    required this.listFocused,
    required this.reordering,
  });

  final GameState gs;
  final ListItemData item;
  final String? selectedKey;
  final bool listFocused;
  final bool reordering;

  @override
  Widget build(BuildContext context) {
    final active = isRowActive(item) &&
        gs.roundState.value == RoundState.playTurns;
    final done = isRowDone(gs, item);
    final init = rowInitiative(gs, item);

    // the whole row is the selection target for characters and empty groups
    bool rowSelected = false;
    if (listFocused) {
      if (item is Character) rowSelected = selectedKey == '${item.id}|${item.id}';
      if (item is Monster && (item as Monster).monsterInstances.isEmpty) {
        rowSelected = selectedKey == '${item.id}|${item.id}';
      }
    }
    final dead = item is Character &&
        (item as Character).characterState.health.value <= 0;

    Widget body;
    if (item is Character) {
      body = _characterBody(item as Character);
    } else if (item is Monster) {
      body = _monsterBody(item as Monster);
    } else {
      body = const SizedBox(height: 60);
    }

    final decoration = BoxDecoration(
      color: active || reordering ? TvColors.panel2 : TvColors.panel,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: reordering
            ? TvColors.elite
            : rowSelected
                ? TvColors.focus
                : active
                    ? const Color(0x594FF2FF)
                    : TvColors.line,
        width: reordering || rowSelected ? 3 : 1,
      ),
      boxShadow: rowSelected
          ? const [BoxShadow(color: Color(0x664FF2FF), blurRadius: 24)]
          : reordering
              ? const [BoxShadow(color: Color(0x66F1C40F), blurRadius: 24)]
              : null,
    );

    return Opacity(
      opacity: (done || dead) && !rowSelected && !reordering ? 0.5 : 1,
      child: Container(
        constraints: const BoxConstraints(minHeight: 112),
        decoration: decoration,
        child: Stack(children: [
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                width: 118,
                decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: TvColors.line))),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(init == null ? '–' : init.toString().padLeft(2, '0'),
                          style: TvText.title(54,
                              color: init == null ? TvColors.dim : TvColors.fg)),
                      const SizedBox(height: 4),
                      Text(tr('init').toUpperCase(), style: TvText.label(13)),
                    ]),
              ),
              Expanded(child: body),
            ]),
          ),
          if (active)
            Positioned(
              left: 0,
              top: 14,
              bottom: 14,
              child: Container(
                width: 6,
                decoration: BoxDecoration(
                    color: TvColors.focus,
                    borderRadius: BorderRadius.circular(3)),
              ),
            ),
          if (reordering)
            Positioned(
              right: 14,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                    color: TvColors.elite, borderRadius: BorderRadius.circular(8)),
                child: tvText('⇅ ${tr('reordering')}',
                    TvText.body(16,
                        color: TvColors.bg, weight: FontWeight.w700)),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _who(
      {required Widget avatar,
      required String name,
      required String sub,
      double width = 310}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(children: [
          avatar,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TvText.body(26, weight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TvText.body(17, color: TvColors.muted)),
                ]),
          ),
        ]),
      ),
    );
  }

  Widget _characterBody(Character c) {
    final st = c.characterState;
    final hp = st.health.value;
    final max = st.maxHealth.value;
    final isObjective = GameMethods.isObjectiveOrEscort(c.characterClass);
    final avatar = Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: const Color(0xFF0B141D),
        shape: BoxShape.circle,
        border: Border.all(
            color: c.characterClass.color.withValues(alpha: 0.8), width: 2),
      ),
      alignment: Alignment.center,
      child: _img(classIconPath(c), w: 54, h: 54, color: classTint(c)),
    );
    final summons = st.summonList;
    return Row(children: [
      _who(
        avatar: avatar,
        name: st.display.value,
        sub: characterSubline(c),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 22,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 210,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('$hp',
                                style: TvText.body(34, weight: FontWeight.w700)),
                            const SizedBox(width: 8),
                            Text('/ $max',
                                style: TvText.body(18, color: TvColors.muted)),
                          ]),
                      const SizedBox(height: 8),
                      TvHpBar(hp: hp, max: max),
                    ]),
              ),
              if (!isObjective)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  _img('assets/images/psd/xp.png', w: 30, h: 30),
                  const SizedBox(width: 8),
                  Text('${st.xp.value}',
                      style: TvText.body(24, color: TvColors.xp)),
                ]),
              TvConditionIcons(figure: st),
              for (final s in summons)
                TvStandeeChip(
                  instance: s,
                  ownerId: c.id,
                  selected: listFocused && selectedKey == '${c.id}|${s.getId()}',
                  summon: true,
                ),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _monsterBody(Monster m) {
    final instances = m.monsterInstances;
    final avatar = Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: const Color(0xFF0B141D),
        shape: BoxShape.circle,
        border: Border.all(
            color: m.isAlly ? TvColors.earth : const Color(0x24FFFFFF),
            width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: _img(monsterImagePath(m), w: 76, h: 76, fit: BoxFit.cover),
    );
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _who(
        avatar: avatar,
        name: m.type.display,
        sub: '${trLevel(m.level.value)} · ${trStandees(instances.length)}',
        width: 300,
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: instances.isEmpty
                ? Text(tr('noStandees'),
                    style: TvText.body(19, color: TvColors.dim))
                : Wrap(spacing: 10, runSpacing: 10, children: [
                    for (final s in instances)
                      TvStandeeChip(
                        instance: s,
                        ownerId: m.id,
                        selected:
                            listFocused && selectedKey == '${m.id}|${s.getId()}',
                      ),
                  ]),
          ),
        ),
      ),
      _abilitySummary(m),
    ]);
  }

  Widget _abilitySummary(Monster m) {
    final deck = GameMethods.getDeck(m.type.deck);
    final playing = gs.roundState.value == RoundState.playTurns;
    final showFront = playing &&
        (m.isActive || m.monsterInstances.isNotEmpty) &&
        deck != null &&
        deck.discardPileIsNotEmpty;
    final card = showFront ? deck.discardPileTop : null;
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: TvColors.line))),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('abilityCard').toUpperCase(), style: TvText.label(13)),
          const SizedBox(height: 6),
          if (card != null) ...[
            Text(card.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TvText.title(28)),
            if (card.shuffle)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: tvText('⟳ ${tr('shuffle')}',
                    TvText.body(16, color: TvColors.muted)),
              ),
          ] else
            Text(deck == null ? '' : trInDeck(deck.drawPileSize),
                style: TvText.body(18, color: TvColors.muted)),
        ],
      ),
    );
  }
}

class TvStandeeChip extends StatelessWidget {
  const TvStandeeChip({
    super.key,
    required this.instance,
    required this.ownerId,
    required this.selected,
    this.summon = false,
  });

  final MonsterInstance instance;
  final String ownerId;
  final bool selected;
  final bool summon;

  @override
  Widget build(BuildContext context) {
    final hp = instance.health.value;
    final max = instance.maxHealth.value;
    final dead = hp <= 0;
    Color nrBg = TvColors.fg;
    Color border = TvColors.line;
    if (instance.type == MonsterType.elite) {
      nrBg = TvColors.elite;
      border = const Color(0x73F1C40F);
    } else if (instance.type == MonsterType.boss) {
      nrBg = TvColors.boss;
      border = const Color(0x73E05050);
    } else if (summon) {
      nrBg = TvColors.earth;
      border = const Color(0x738BD17C);
    }
    final conds = instance.conditions.value;
    return Opacity(
      opacity: dead && !selected ? 0.35 : 1,
      child: Container(
        width: 136,
        height: 84,
        decoration: selected
            ? tvFocusRing(radius: 12)
            : BoxDecoration(
                color: TvColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
              ),
        child: Stack(children: [
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: nrBg, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: summon && instance.gfx.isNotEmpty
                    ? ClipOval(
                        child: _img(summonImagePath(instance),
                            w: 32, h: 32, fit: BoxFit.cover))
                    : Text('${instance.standeeNr}',
                        style: TvText.body(18,
                            color: TvColors.bg, weight: FontWeight.w800)),
              ),
            ),
          ),
          Positioned(
            left: 48,
            right: 10,
            top: 0,
            bottom: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$hp',
                          style: TvText.body(22, weight: FontWeight.w700)),
                      Text(' / $max',
                          style: TvText.body(15, color: TvColors.muted)),
                    ]),
                const SizedBox(height: 6),
                TvHpBar(hp: hp, max: max, height: 6),
              ],
            ),
          ),
          if (conds.isNotEmpty)
            Positioned(
              right: 6,
              top: 5,
              child: TvConditionIcons(figure: instance, size: 22, max: 2),
            ),
        ]),
      ),
    );
  }
}

// ======================================================================
// Right side panels
// ======================================================================

class TvPanel extends StatelessWidget {
  const TvPanel({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: tvPanel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title.toUpperCase(), style: TvText.label(14)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Kbd extends StatelessWidget {
  const _Kbd(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: TvColors.panel2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: TvColors.line),
        ),
        child: tvText(text, TvText.body(16)),
      );
}

class TvSelectedPanel extends StatelessWidget {
  const TvSelectedPanel({super.key, required this.target});
  final TvTarget? target;

  @override
  Widget build(BuildContext context) {
    final t = target;
    String image = '';
    String title = '';
    String sub = '';
    bool coverImage = true;
    Color? tint;
    if (t != null) {
      final item = t.item;
      final fig = t.figure;
      final hpText = fig == null
          ? ''
          : '${tr('hp')} ${fig.health.value}/${fig.maxHealth.value}';
      final condText = fig == null
          ? ''
          : fig.conditions.value.map((c) => trCondition(c).toLowerCase()).join(', ');
      if (t.isCharacter && item is Character) {
        image = classIconPath(item);
        coverImage = false;
        tint = classTint(item);
        title = item.characterState.display.value;
        sub = [
          characterSubline(item),
          hpText,
          condText
        ].where((s) => s.isNotEmpty).join(' · ');
      } else if (t.isSummon) {
        final s = t.instance!;
        image = summonImagePath(s);
        title = '${s.name} · ${trStandeeNr(s.standeeNr)}';
        sub = [tr('summon'), hpText, condText].where((s) => s.isNotEmpty).join(' · ');
      } else if (item is Monster) {
        image = monsterImagePath(item);
        final s = t.instance;
        if (s == null) {
          title = item.type.display;
          sub = tr('noStandees');
        } else {
          title = '${item.type.display} · ${trStandeeNr(s.standeeNr)}';
          final type = s.type == MonsterType.elite
              ? tr('elite')
              : s.type == MonsterType.boss
                  ? tr('boss')
                  : tr('normal');
          sub = [type, hpText, condText].where((s) => s.isNotEmpty).join(' · ');
        }
      }
    }
    return TvPanel(
      title: tr('selected'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: TvColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x24FFFFFF), width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            padding: coverImage ? EdgeInsets.zero : const EdgeInsets.all(14),
            child: image.isEmpty
                ? const SizedBox()
                : _img(image,
                    fit: coverImage ? BoxFit.cover : BoxFit.contain,
                    color: tint),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TvText.body(26, weight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(sub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TvText.body(18, color: TvColors.muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const _Kbd('◀ ▶'),
            Text(tr('keyHp'), style: TvText.body(17, color: TvColors.muted)),
            const SizedBox(width: 10),
            const _Kbd('▲ ▼'),
            Text(tr('keyUpDown'), style: TvText.body(17, color: TvColors.muted)),
            const SizedBox(width: 10),
            const _Kbd('OK'),
            Text('${tr('keyOk')} · ${tr('keyLongOk')}',
                style: TvText.body(17, color: TvColors.muted)),
          ],
        ),
      ]),
    );
  }
}

class TvAbilityPanel extends StatelessWidget {
  const TvAbilityPanel({super.key, required this.gs, required this.monster});
  final GameState gs;
  final Monster? monster;

  static const double _cardScale = 3.3;

  @override
  Widget build(BuildContext context) {
    final m = monster;
    if (m == null) {
      return TvPanel(
        title: tr('abilityCard'),
        child: Text(tr('noMonsters'),
            style: TvText.body(20, color: TvColors.muted)),
      );
    }
    final deck = GameMethods.getDeck(m.type.deck);
    final playing = gs.roundState.value == RoundState.playTurns;
    final showFront = playing &&
        (m.isActive || m.monsterInstances.isNotEmpty) &&
        deck != null &&
        deck.discardPileIsNotEmpty;
    final cardW = (kAbilityCardWidth + 2 * kMonsterCardMargin) * _cardScale;
    final cardH = (94.4 + 2 * kMonsterCardMargin) * _cardScale;
    return TvPanel(
      title: '${m.type.display} · ${tr('abilityCard')}',
      child: Column(children: [
        SizedBox(
          height: cardH,
          child: Center(
            child: showFront
                ? SizedBox(
                    width: cardW,
                    height: cardH,
                    child: MonsterAbilityCardFront(
                      card: deck.discardPileTop,
                      data: m,
                      scale: _cardScale,
                      calculateAll: false,
                    ),
                  )
                : Container(
                    width: cardW,
                    height: cardH,
                    decoration: BoxDecoration(
                      color: TvColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: TvColors.line),
                    ),
                    alignment: Alignment.center,
                    child: Text(playing ? tr('notOnBoard') : tr('noCard'),
                        style: TvText.body(22, color: TvColors.dim)),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Text(deck == null ? '' : trInDeck(deck.drawPileSize).toUpperCase(),
              style: TvText.label(14)),
          const Spacer(),
          if (showFront && deck.discardPileTop.shuffle)
            Text(tr('shuffle').toUpperCase(),
                style: TvText.label(14, color: TvColors.elite)),
        ]),
      ]),
    );
  }
}

class TvModifierPanel extends StatelessWidget {
  const TvModifierPanel({super.key, required this.gs, required this.focused});
  final GameState gs;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final deck = gs.modifierDeck;
    final discards = deck.discardPileContents.toList();
    final top = discards.isNotEmpty ? deck.discardPileTop : null;
    // earlier draws, newest first (the top card is shown big)
    final earlier = discards.length > 1
        ? discards.sublist(0, discards.length - 1).reversed.take(4).toList()
        : <ModifierCard>[];
    final draw = deck.drawPileContents;
    final bless = draw.where((c) => c.gfx == 'bless').length;
    final curse = draw.where((c) => c.gfx == 'curse').length;
    return TvPanel(
      title: tr('monsterModDeck'),
      child: Row(children: [
        SizedBox(
          width: kModifierCardBaseWidth * 2.2 + 8,
          height: 39 * 2.2 + 8,
          child: top == null
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
              : ModifierCardFront(card: top, name: '', scale: 2.2),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(trCardsLeft(deck.drawPileSize), style: TvText.body(22)),
              if (deck.needsShuffle)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: tvText('⟳ ${tr('shuffle')}',
                      TvText.body(17, color: TvColors.elite)),
                ),
            ]),
            if (bless > 0 || curse > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  if (bless > 0) ...[
                    _img('assets/images/abilities/bless.png', w: 22, h: 22),
                    Text(' $bless   ', style: TvText.body(18)),
                  ],
                  if (curse > 0) ...[
                    _img('assets/images/abilities/curse.png', w: 22, h: 22),
                    Text(' $curse', style: TvText.body(18)),
                  ],
                ]),
              ),
            const SizedBox(height: 8),
            Row(children: [
              for (final c in earlier)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Opacity(
                    opacity: 0.6,
                    child: SizedBox(
                      width: kModifierCardBaseWidth * 0.9 + 4,
                      height: 39 * 0.9 + 4,
                      child: ModifierCardFront(card: c, name: '', scale: 0.9),
                    ),
                  ),
                ),
              if (earlier.isNotEmpty)
                Text(tr('discarded'), style: TvText.body(15, color: TvColors.dim)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ======================================================================
// Footer
// ======================================================================

class TvFooterButton {
  const TvFooterButton(this.text, {this.primary = false, this.icon});
  final String text;
  final bool primary;
  final IconData? icon;
}

class TvFooter extends StatelessWidget {
  const TvFooter(
      {super.key,
      required this.buttons,
      required this.focusIndex,
      required this.hint});
  final List<TvFooterButton> buttons;
  final int? focusIndex;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 56),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xF70A1018), Color(0xB30A1018)],
        ),
        border: Border(top: BorderSide(color: TvColors.line)),
      ),
      child: Row(children: [
        for (int i = 0; i < buttons.length; i++) ...[
          _btn(buttons[i], focusIndex == i),
          const SizedBox(width: 14),
        ],
        const Spacer(),
        tvText(hint, TvText.body(18, color: TvColors.dim)),
      ]),
    );
  }

  Widget _btn(TvFooterButton b, bool focused) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      decoration: BoxDecoration(
        color: b.primary ? TvColors.focus : TvColors.panel2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: focused
              ? (b.primary ? Colors.white : TvColors.focus)
              : (b.primary ? Colors.transparent : TvColors.line),
          width: focused ? 3 : 1,
        ),
        boxShadow: focused
            ? const [BoxShadow(color: Color(0x994FF2FF), blurRadius: 26)]
            : null,
      ),
      alignment: Alignment.center,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (b.icon != null)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Icon(b.icon,
                size: 26, color: b.primary ? TvColors.onFocus : TvColors.fg),
          ),
        Text(b.text,
            style: TvText.body(22,
                color: b.primary ? TvColors.onFocus : TvColors.fg,
                weight: FontWeight.w600)),
      ]),
    );
  }
}
