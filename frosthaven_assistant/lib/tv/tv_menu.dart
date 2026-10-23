import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tv_strings.dart';
import 'tv_theme.dart';

/// Remote-driven dialog: rows of buttons or steppers, navigated with the
/// D-pad. ▲▼ moves between rows, ◀▶ moves within a row (or changes a
/// stepper's value), OK runs the button, Back closes.

abstract class TvMenuRow {
  const TvMenuRow({this.label});
  final String? label;
}

class TvMenuButton {
  const TvMenuButton({
    required this.text,
    this.icon,
    this.onPressed,
    this.active = false,
    this.closes = false,
    this.primary = false,
    this.disabledNote,
    this.iconTint,
    this.subtitle,
    this.coverImage = false,
  });

  final String text;
  final String? icon;
  final VoidCallback? onPressed;

  /// Toggle state (e.g. a condition that is on).
  final bool active;

  /// Close the menu after running.
  final bool closes;
  final bool primary;

  /// Shown under the label when the button cannot be used (e.g. "immune").
  final String? disabledNote;
  final Color? iconTint;

  /// Second line on tile / picture styles.
  final String? subtitle;

  /// Picture style: fill the image area (monster art) instead of fitting.
  final bool coverImage;

  bool get enabled => onPressed != null;
}

enum TvRowStyle {
  /// Text buttons.
  buttons,

  /// Small icon tiles that light up when active (conditions).
  icons,

  /// Picture tiles with a name (classes, monsters).
  pictures,

  /// Text tiles with a title and a subtitle (scenarios).
  tiles,
}

class TvButtonsRow extends TvMenuRow {
  const TvButtonsRow(this.items,
      {super.label, bool iconGrid = false, TvRowStyle? style})
      : style = style ?? (iconGrid ? TvRowStyle.icons : TvRowStyle.buttons);
  final List<TvMenuButton> items;
  final TvRowStyle style;
}

/// Splits [items] into rows of [perRow], so the visual rows match the ▲▼ rows.
List<TvMenuRow> tvGrid(List<TvMenuButton> items, int perRow,
    {String? label, TvRowStyle style = TvRowStyle.buttons}) {
  final out = <TvMenuRow>[];
  for (int i = 0; i < items.length; i += perRow) {
    final end = i + perRow > items.length ? items.length : i + perRow;
    out.add(TvButtonsRow(items.sublist(i, end),
        label: i == 0 ? label : null, style: style));
  }
  return out;
}

/// A plain line of text between rows (not selectable).
class TvTextRow extends TvMenuRow {
  const TvTextRow(this.text) : super();
  final String text;
}

class TvStepperRow extends TvMenuRow {
  const TvStepperRow({
    required String label,
    required this.value,
    required this.onChange,
    this.format,
    this.min = 0,
    this.max = 999,
  }) : super(label: label);

  final int Function() value;

  /// Called with the new value (already clamped).
  final void Function(int value) onChange;
  final String Function(int value)? format;
  final int min;
  final int max;
}

Future<T?> showTvMenu<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  String? image,
  Color? imageTint,
  required List<TvMenuRow> Function() rows,
  Listenable? rebuildOn,
  double width = 1180,
  VoidCallback? onClose,
  bool Function()? closeWhen,
  (int, int)? start,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xB3000000),
    // no transition: on the stick, route animations started from the Back key
    // can stall until the next input, leaving the dialog invisible
    transitionDuration: Duration.zero,
    pageBuilder: (ctx, a1, a2) => TvMenu(
      title: title,
      subtitle: subtitle,
      image: image,
      imageTint: imageTint,
      rows: rows,
      rebuildOn: rebuildOn,
      width: width,
      onClose: onClose,
      closeWhen: closeWhen,
      start: start,
    ),
    transitionBuilder: (ctx, anim, _, child) => child,
  );
}

class TvMenu extends StatefulWidget {
  const TvMenu({
    super.key,
    required this.title,
    required this.rows,
    this.subtitle,
    this.image,
    this.imageTint,
    this.rebuildOn,
    this.width = 1180,
    this.onClose,
    this.closeWhen,
    this.start,
  });

  final String title;
  final String? subtitle;
  final String? image;
  final Color? imageTint;
  final List<TvMenuRow> Function() rows;
  final Listenable? rebuildOn;
  final double width;
  final VoidCallback? onClose;

  /// Checked after every button press; true closes the menu.
  final bool Function()? closeWhen;

  /// Initially selected (row, column); defaults to the first enabled item.
  final (int, int)? start;

  @override
  State<TvMenu> createState() => _TvMenuState();
}

class _TvMenuState extends State<TvMenu> {
  final _focus = FocusNode(debugLabel: 'tv-menu');
  int _row = 0;
  int _col = 0;
  DateTime _lastRepeat = DateTime.fromMillisecondsSinceEpoch(0);
  int _repeats = 0;
  bool _closed = false;
  bool _backDown = false;
  Timer? _refocusTimer;

  /// Pending stepper value (committed on change, shown immediately).
  int? _pending;
  final Map<int, GlobalKey> _rowKeys = {};

  void _scheduleScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _rowKeys[_row]?.currentContext;
      if (!mounted || ctx == null) return;
      Scrollable.ensureVisible(ctx,
          alignment: 0.5,
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit);
    });
  }

  bool _selectable(TvMenuRow row) =>
      row is TvStepperRow ||
      (row is TvButtonsRow && row.items.isNotEmpty);

  @override
  void initState() {
    super.initState();
    widget.rebuildOn?.addListener(_rebuild);
    TvLang.current.addListener(_rebuild);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
    // take the focus back if it gets lost while this menu is on top
    _refocusTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted || _closed || _focus.hasFocus) return;
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;
      _focus.requestFocus();
    });
    // start on the requested item, or the first enabled button
    final rows = widget.rows();
    final start = widget.start;
    if (start != null && start.$1 >= 0 && start.$1 < rows.length) {
      // column -1: the first enabled item from that row on
      if (start.$2 >= 0) {
        _row = start.$1;
        _col = start.$2.clamp(0, _rowLength(rows[_row]) - 1);
        _scheduleScroll();
        return;
      }
      for (int r = start.$1; r < rows.length; r++) {
        final row = rows[r];
        if (row is TvStepperRow) {
          _row = r;
          _scheduleScroll();
          return;
        }
        if (row is TvButtonsRow) {
          final c = row.items.indexWhere((b) => b.enabled);
          if (c >= 0) {
            _row = r;
            _col = c;
            _scheduleScroll();
            return;
          }
        }
      }
    }
    for (int r = 0; r < rows.length; r++) {
      final row = rows[r];
      if (row is TvStepperRow) {
        _row = r;
        break;
      }
      if (row is TvButtonsRow) {
        final c = row.items.indexWhere((b) => b.enabled);
        if (c >= 0) {
          _row = r;
          _col = c;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    widget.rebuildOn?.removeListener(_rebuild);
    TvLang.current.removeListener(_rebuild);
    _refocusTimer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    widget.onClose?.call();
    Navigator.of(context).pop();
  }

  int _rowLength(TvMenuRow row) =>
      row is TvButtonsRow ? (row.items.isEmpty ? 1 : row.items.length) : 1;

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    final k = e.logicalKey;
    final rows = widget.rows();
    if (rows.isEmpty) return KeyEventResult.ignored;
    _row = _row.clamp(0, rows.length - 1);
    final row = rows[_row];

    if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.goBack) {
      // act on key up, and only for a press that started in this menu
      if (e is KeyDownEvent) {
        _backDown = true;
      } else if (e is KeyUpEvent && _backDown) {
        _backDown = false;
        _close();
      }
      return KeyEventResult.handled;
    }
    if (e is KeyUpEvent) {
      if (k == LogicalKeyboardKey.arrowLeft ||
          k == LogicalKeyboardKey.arrowRight) {
        _repeats = 0;
      }
      return KeyEventResult.handled;
    }

    final isRepeat = e is KeyRepeatEvent;
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowDown) {
      final d = k == LogicalKeyboardKey.arrowUp ? -1 : 1;
      var next = _row + d;
      while (next >= 0 && next < rows.length && !_selectable(rows[next])) {
        next += d;
      }
      if (next >= 0 && next < rows.length && next != _row) {
        setState(() {
          _row = next;
          _col = _col.clamp(0, _rowLength(rows[_row]) - 1);
        });
        _scheduleScroll();
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowRight) {
      final d = k == LogicalKeyboardKey.arrowLeft ? -1 : 1;
      if (row is TvStepperRow) {
        if (isRepeat) {
          final now = DateTime.now();
          if (now.difference(_lastRepeat).inMilliseconds < 90) {
            return KeyEventResult.handled;
          }
          _lastRepeat = now;
          _repeats++;
        } else {
          _repeats = 0;
        }
        final step = _repeats > 12 ? 5 : 1;
        final cur = row.value();
        final v = (cur + d * step).clamp(row.min, row.max);
        if (v != cur) row.onChange(v);
        setState(() {});
        return KeyEventResult.handled;
      }
      if (isRepeat) return KeyEventResult.handled;
      final next = (_col + d).clamp(0, _rowLength(row) - 1);
      if (next != _col) setState(() => _col = next);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter ||
        k == LogicalKeyboardKey.gameButtonA) {
      if (isRepeat) return KeyEventResult.handled;
      if (row is TvButtonsRow) {
        final b = row.items[_col.clamp(0, row.items.length - 1)];
        if (b.enabled) {
          b.onPressed?.call();
          if (b.closes || (widget.closeWhen?.call() ?? false)) {
            _close();
          } else {
            setState(() {});
          }
        }
      } else if (row is TvStepperRow) {
        // OK on a stepper: move on to the next row
        if (_row < rows.length - 1) {
          setState(() => _row++);
          _scheduleScroll();
        }
      }
      return KeyEventResult.handled;
    }
    // number keys type a stepper value directly (keyboard / remotes with digits)
    if (row is TvStepperRow) {
      final digit = _digitOf(k);
      if (digit != null && !isRepeat) {
        final now = DateTime.now();
        final cur = row.value();
        int v;
        if (_pending != null &&
            now.difference(_lastRepeat).inMilliseconds < 1500 &&
            cur < 10) {
          v = cur * 10 + digit;
        } else {
          v = digit;
        }
        _pending = v;
        _lastRepeat = now;
        row.onChange(v.clamp(row.min, row.max));
        setState(() {});
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  int? _digitOf(LogicalKeyboardKey k) {
    const digits = [
      LogicalKeyboardKey.digit0,
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    const numpad = [
      LogicalKeyboardKey.numpad0,
      LogicalKeyboardKey.numpad1,
      LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.numpad3,
      LogicalKeyboardKey.numpad4,
      LogicalKeyboardKey.numpad5,
      LogicalKeyboardKey.numpad6,
      LogicalKeyboardKey.numpad7,
      LogicalKeyboardKey.numpad8,
      LogicalKeyboardKey.numpad9,
    ];
    final i = digits.indexOf(k);
    if (i >= 0) return i;
    final j = numpad.indexOf(k);
    return j >= 0 ? j : null;
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows();
    if (rows.isNotEmpty) _row = _row.clamp(0, rows.length - 1);
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_closed) {
          _closed = true;
          widget.onClose?.call();
        }
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: TvStage(
          child: Center(
            child: Container(
              width: widget.width,
              constraints: const BoxConstraints(maxHeight: 980),
              padding: const EdgeInsets.fromLTRB(36, 28, 36, 28),
              decoration: BoxDecoration(
                color: TvColors.panel,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: TvColors.line),
                boxShadow: const [
                  BoxShadow(color: Color(0xCC000000), blurRadius: 60)
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    const SizedBox(height: 18),
                    for (int r = 0; r < rows.length; r++)
                      KeyedSubtree(
                        key: _rowKeys.putIfAbsent(r, () => GlobalKey()),
                        child: _buildRow(rows[r], r),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(children: [
      if (widget.image != null)
        Container(
          width: 84,
          height: 84,
          margin: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: TvColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x24FFFFFF), width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          padding: widget.imageTint == null ? null : const EdgeInsets.all(12),
          child: Image.asset(widget.image!,
              fit: widget.imageTint == null ? BoxFit.cover : BoxFit.contain,
              color: widget.imageTint,
              errorBuilder: (_, _, _) => const SizedBox()),
        ),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title, style: TvText.title(46)),
          if (widget.subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(widget.subtitle!,
                  style: TvText.body(21, color: TvColors.muted)),
            ),
        ]),
      ),
    ]);
  }

  Widget _buildRow(TvMenuRow row, int r) {
    final selectedRow = r == _row;
    Widget content;
    if (row is TvStepperRow) {
      content = _stepper(row, selectedRow);
    } else if (row is TvButtonsRow) {
      Widget item(int c) {
        final sel = selectedRow && c == _col;
        switch (row.style) {
          case TvRowStyle.icons:
            return _iconTile(row.items[c], sel);
          case TvRowStyle.pictures:
            return _pictureTile(row.items[c], sel);
          case TvRowStyle.tiles:
            return _textTile(row.items[c], sel);
          case TvRowStyle.buttons:
            return _button(row.items[c], sel);
        }
      }

      content = Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [for (int c = 0; c < row.items.length; c++) item(c)],
      );
    } else if (row is TvTextRow) {
      content = tvText(row.text, TvText.body(20, color: TvColors.muted));
    } else {
      content = const SizedBox();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (row.label != null && row is! TvStepperRow)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(row.label!.toUpperCase(), style: TvText.label(15)),
          ),
        content,
      ]),
    );
  }

  Widget _stepper(TvStepperRow row, bool selected) {
    final v = row.value();
    final text = row.format?.call(v) ?? '$v';
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: selected
          ? tvFocusRing(radius: 14, fill: TvColors.panel2)
          : tvPanel(color: TvColors.panel2, radius: 14),
      child: Row(children: [
        SizedBox(
            width: 300,
            child: Text(row.label!, style: TvText.body(26, weight: FontWeight.w600))),
        tvText('◀', TvText.body(26, color: selected ? TvColors.focus : TvColors.dim)),
        SizedBox(
          width: 150,
          child: Text(text,
              textAlign: TextAlign.center,
              style: TvText.body(40, weight: FontWeight.w700)),
        ),
        tvText('▶', TvText.body(26, color: selected ? TvColors.focus : TvColors.dim)),
        const Spacer(),
        if (selected) tvText(tr('stepperHint'), TvText.body(17, color: TvColors.muted)),
      ]),
    );
  }

  Widget _button(TvMenuButton b, bool selected) {
    final bg = b.primary
        ? TvColors.focus
        : (b.active ? const Color(0xFF214057) : TvColors.panel2);
    final fg = b.primary ? TvColors.onFocus : TvColors.fg;
    return Opacity(
      opacity: b.enabled ? 1 : 0.4,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 26),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? TvColors.focus : TvColors.line,
              width: selected ? 3 : 1),
          boxShadow: selected
              ? const [BoxShadow(color: Color(0x804FF2FF), blurRadius: 22)]
              : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (b.icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Image.asset(b.icon!, width: 32, height: 32, color: b.iconTint),
            ),
          Text(b.text, style: TvText.body(23, color: fg, weight: FontWeight.w600)),
          if (b.active && !b.primary)
            const Padding(
              padding: EdgeInsets.only(left: 10),
              child: Icon(Icons.check, color: TvColors.focus, size: 26),
            ),
        ]),
      ),
    );
  }

  BoxDecoration _tileDeco(TvMenuButton b, bool selected) => BoxDecoration(
        color: b.active ? const Color(0xFF1E3A50) : TvColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: selected
                ? TvColors.focus
                : (b.active ? const Color(0x994FF2FF) : TvColors.line),
            width: selected ? 3 : (b.active ? 2 : 1)),
        boxShadow: selected
            ? const [BoxShadow(color: Color(0x804FF2FF), blurRadius: 22)]
            : null,
      );

  Widget _pictureTile(TvMenuButton b, bool selected) {
    return Opacity(
      opacity: b.enabled ? 1 : 0.35,
      child: Container(
        width: 170,
        height: 168,
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
        decoration: _tileDeco(b, selected),
        child: Column(children: [
          Expanded(
            child: Stack(clipBehavior: Clip.none, children: [
              Center(
                child: b.icon == null
                    ? const SizedBox()
                    : b.coverImage
                        ? ClipOval(
                            child: Image.asset(b.icon!,
                                width: 92,
                                height: 92,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const SizedBox()),
                          )
                        : Image.asset(b.icon!,
                            height: 80,
                            color: b.iconTint,
                            errorBuilder: (_, _, _) => const SizedBox()),
              ),
              if (b.active)
                const Positioned(
                  right: 0,
                  top: -2,
                  child: Icon(Icons.check_circle, color: TvColors.focus, size: 26),
                ),
            ]),
          ),
          const SizedBox(height: 6),
          Text(b.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TvText.body(19, weight: FontWeight.w600)),
          if (b.subtitle != null || b.disabledNote != null)
            Text(b.disabledNote ?? b.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TvText.body(15, color: TvColors.muted)),
        ]),
      ),
    );
  }

  Widget _textTile(TvMenuButton b, bool selected) {
    return Opacity(
      opacity: b.enabled ? 1 : 0.4,
      child: Container(
        width: 266,
        height: 92,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: _tileDeco(b, selected),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(children: [
              Expanded(
                child: Text(b.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TvText.title(28,
                        color: b.active ? TvColors.focus : TvColors.fg)),
              ),
              if (b.active)
                const Icon(Icons.check_circle, color: TvColors.focus, size: 22),
            ]),
            if (b.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(b.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TvText.body(16, color: TvColors.muted)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _iconTile(TvMenuButton b, bool selected) {
    return Opacity(
      opacity: b.enabled ? 1 : 0.35,
      child: Container(
        width: 166,
        height: 120,
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        decoration: BoxDecoration(
          color: b.active ? const Color(0xFF1E3A50) : TvColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected
                  ? TvColors.focus
                  : (b.active ? const Color(0x994FF2FF) : TvColors.line),
              width: selected ? 3 : (b.active ? 2 : 1)),
          boxShadow: selected
              ? const [BoxShadow(color: Color(0x804FF2FF), blurRadius: 22)]
              : null,
        ),
        child: Column(children: [
          Expanded(
            child: Stack(clipBehavior: Clip.none, children: [
              Center(
                child: Opacity(
                  opacity: b.active ? 1 : 0.55,
                  child: b.icon == null
                      ? const SizedBox()
                      : Image.asset(b.icon!,
                          height: 50,
                          color: b.iconTint,
                          errorBuilder: (_, _, _) => const SizedBox()),
                ),
              ),
              if (b.active)
                const Positioned(
                  right: 0,
                  top: -4,
                  child: Icon(Icons.check_circle, color: TvColors.focus, size: 26),
                ),
            ]),
          ),
          const SizedBox(height: 6),
          Text(
            b.disabledNote ?? b.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TvText.body(18,
                color: b.active ? TvColors.fg : TvColors.muted,
                weight: b.active ? FontWeight.w600 : FontWeight.w400),
          ),
        ]),
      ),
    );
  }
}

/// Scales a 1920×1080 authored layout to the actual screen.
class TvStage extends StatelessWidget {
  const TvStage({super.key, required this.child});
  final Widget child;

  static const Size size = Size(1920, 1080);

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
                size: size, textScaler: TextScaler.noScaling),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Short message at the bottom of the screen.
class TvToast {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(BuildContext context, String text, {int seconds = 3}) {
    _timer?.cancel();
    _entry?.remove();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: TvStage(
          child: Align(
            alignment: const Alignment(0, 0.72),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xF0182431),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x664FF2FF)),
                boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 30)],
              ),
              constraints: const BoxConstraints(maxWidth: 1500),
              child: tvText(text, TvText.body(24, weight: FontWeight.w500),
                  textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_entry!);
    _timer = Timer(Duration(seconds: seconds), () {
      _entry?.remove();
      _entry = null;
    });
  }
}
