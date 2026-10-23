import 'package:flutter/material.dart';

/// Colours and text styles of the TV UI (gorduin/tv fork).
/// Mirrors tv-design/main.html; the layout is authored for 1920×1080.
class TvColors {
  static const bg = Color(0xFF0A1018);
  static const panel = Color(0xFF121B26);
  static const panel2 = Color(0xFF182431);
  static const card = Color(0xFF0B141D);
  static const line = Color(0x1FBED7EB);
  static const fg = Color(0xFFE9F1F7);
  static const muted = Color(0x8CE9F1F7);
  static const dim = Color(0x52E9F1F7);
  static const focus = Color(0xFF4FF2FF);
  static const onFocus = Color(0xFF06202A);
  static const hp = Color(0xFFE04E4E);
  static const hpLight = Color(0xFFFF6B6B);
  static const hpBg = Color(0x2EE04E4E);
  static const elite = Color(0xFFF1C40F);
  static const boss = Color(0xFFE05050);
  static const xp = Color(0xFF9FD6FF);

  static const fire = Color(0xFFFF7A3D);
  static const ice = Color(0xFF8FD8FF);
  static const air = Color(0xFFD9E8EF);
  static const earth = Color(0xFF8BD17C);
  static const light = Color(0xFFFFE68A);
  static const dark = Color(0xFF9B8CFF);
}

class TvText {
  static const _base = TextStyle(
    color: TvColors.fg,
    decoration: TextDecoration.none,
    fontFamily: 'Roboto',
    height: 1.15,
  );

  static TextStyle body(double size,
          {Color color = TvColors.fg, FontWeight weight = FontWeight.w400}) =>
      _base.copyWith(fontSize: size, color: color, fontWeight: weight);

  static TextStyle title(double size, {Color color = TvColors.fg}) =>
      _base.copyWith(
          fontFamily: 'Pirata', fontSize: size, color: color, height: 1.0);

  /// Small uppercase label with letter spacing (panel headers, "KEZD.").
  static TextStyle label(double size, {Color color = TvColors.dim}) =>
      _base.copyWith(
          fontSize: size,
          color: color,
          letterSpacing: size * 0.18,
          fontWeight: FontWeight.w500);
}

BoxDecoration tvPanel({Color color = TvColors.panel, double radius = 16}) =>
    BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: TvColors.line),
    );

/// The cyan focus ring used everywhere a remote selection is shown.
BoxDecoration tvFocusRing({double radius = 12, Color fill = TvColors.card}) =>
    BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: TvColors.focus, width: 3),
      boxShadow: const [
        BoxShadow(color: Color(0x804FF2FF), blurRadius: 24),
      ],
    );

const Map<String, IconData> _glyphIcons = {
  '◀': Icons.arrow_left,
  '▶': Icons.arrow_right,
  '▲': Icons.arrow_drop_up,
  '▼': Icons.arrow_drop_down,
  '⚙': Icons.settings,
  '⟳': Icons.sync,
  '⇅': Icons.swap_vert,
  '✎': Icons.edit_note,
  '→': Icons.arrow_forward,
};

/// Text that renders ◀ ▶ ▲ ▼ ⚙ ⟳ ⇅ as Material icons, so it does not depend
/// on the device font having those glyphs.
Widget tvText(String s, TextStyle st,
    {TextAlign? textAlign, int? maxLines, TextOverflow? overflow}) {
  if (!_glyphIcons.keys.any(s.contains)) {
    return Text(s,
        style: st,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow);
  }
  final size = (st.fontSize ?? 20) * 1.25;
  final spans = <InlineSpan>[];
  final buf = StringBuffer();
  for (final ch in s.characters) {
    final icon = _glyphIcons[ch];
    if (icon == null) {
      buf.write(ch);
      continue;
    }
    if (buf.isNotEmpty) {
      spans.add(TextSpan(text: buf.toString()));
      buf.clear();
    }
    spans.add(WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Icon(icon, size: size, color: st.color),
    ));
  }
  if (buf.isNotEmpty) spans.add(TextSpan(text: buf.toString()));
  return Text.rich(TextSpan(children: spans),
      style: st, textAlign: textAlign, maxLines: maxLines, overflow: overflow);
}
