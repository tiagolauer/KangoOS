import 'package:flutter/material.dart';

/// Status colors that mirror the roadmap artifact's done / next / later
/// chip system, for anything that needs a semantic (not brand) accent.
class KangoosStatusColors extends ThemeExtension<KangoosStatusColors> {
  const KangoosStatusColors({
    required this.done,
    required this.doneSoft,
    required this.next,
    required this.nextSoft,
    required this.later,
    required this.laterSoft,
  });

  final Color done;
  final Color doneSoft;
  final Color next;
  final Color nextSoft;
  final Color later;
  final Color laterSoft;

  static const dark = KangoosStatusColors(
    done: Color(0xFF4ADE80),
    doneSoft: Color(0x244ADE80),
    next: Color(0xFFF2C14E),
    nextSoft: Color(0x24F2C14E),
    later: Color(0xFF8EA69D),
    laterSoft: Color(0x1F8EA69D),
  );

  static const light = KangoosStatusColors(
    done: Color(0xFF1F9D55),
    doneSoft: Color(0x1F1F9D55),
    next: Color(0xFFA1730A),
    nextSoft: Color(0x1FA1730A),
    later: Color(0xFF66756F),
    laterSoft: Color(0x1466756F),
  );

  @override
  KangoosStatusColors copyWith({
    Color? done,
    Color? doneSoft,
    Color? next,
    Color? nextSoft,
    Color? later,
    Color? laterSoft,
  }) {
    return KangoosStatusColors(
      done: done ?? this.done,
      doneSoft: doneSoft ?? this.doneSoft,
      next: next ?? this.next,
      nextSoft: nextSoft ?? this.nextSoft,
      later: later ?? this.later,
      laterSoft: laterSoft ?? this.laterSoft,
    );
  }

  @override
  KangoosStatusColors lerp(ThemeExtension<KangoosStatusColors>? other, double t) {
    if (other is! KangoosStatusColors) return this;
    return KangoosStatusColors(
      done: Color.lerp(done, other.done, t)!,
      doneSoft: Color.lerp(doneSoft, other.doneSoft, t)!,
      next: Color.lerp(next, other.next, t)!,
      nextSoft: Color.lerp(nextSoft, other.nextSoft, t)!,
      later: Color.lerp(later, other.later, t)!,
      laterSoft: Color.lerp(laterSoft, other.laterSoft, t)!,
    );
  }
}

abstract final class KangoosTheme {
  static const monoFallback = [
    'Cascadia Code',
    'Consolas',
    'Courier New',
    'monospace',
  ];

  static TextTheme _textTheme(Color text, Color textDim) {
    final mono = TextStyle(fontFamilyFallback: monoFallback, color: text);
    return TextTheme(
      headlineLarge: mono.copyWith(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineMedium: mono.copyWith(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleLarge: mono.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: mono.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      labelSmall: mono.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
        color: textDim,
      ),
      bodyLarge: TextStyle(fontSize: 15, color: text, height: 1.5),
      bodyMedium: TextStyle(fontSize: 13.5, color: text, height: 1.5),
      bodySmall: TextStyle(fontSize: 12, color: textDim, height: 1.4),
    );
  }

  static ThemeData get dark {
    const bg = Color(0xFF0A100E);
    const surface = Color(0xFF121A17);
    const surfaceDim = Color(0xFF16201C);
    const border = Color(0xFF253129);
    const text = Color(0xFFE7F1EC);
    const textDim = Color(0xFF93A49C);
    const accent = Color(0xFF2BBFA1);
    const accentContrast = Color(0xFF06231D);

    final colorScheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: accent,
      onPrimary: accentContrast,
      primaryContainer: const Color(0x292BBFA1),
      onPrimaryContainer: accent,
      secondary: textDim,
      surface: surface,
      onSurface: text,
      surfaceContainerHighest: surfaceDim,
      onSurfaceVariant: textDim,
      outline: border,
      outlineVariant: border,
      error: const Color(0xFFF2555E),
      onError: const Color(0xFF2B0709),
    );

    return _build(colorScheme, bg: bg, border: border, text: text, textDim: textDim);
  }

  static ThemeData get light {
    const bg = Color(0xFFF5F7F6);
    const surface = Color(0xFFFFFFFF);
    const surfaceDim = Color(0xFFEEF2F0);
    const border = Color(0xFFD7E0DC);
    const text = Color(0xFF10201B);
    const textDim = Color(0xFF52645D);
    const accent = Color(0xFF0F8F7C);
    const accentContrast = Color(0xFFFFFFFF);

    final colorScheme = ColorScheme.light(
      brightness: Brightness.light,
      primary: accent,
      onPrimary: accentContrast,
      primaryContainer: const Color(0x1F0F8F7C),
      onPrimaryContainer: accent,
      secondary: textDim,
      surface: surface,
      onSurface: text,
      surfaceContainerHighest: surfaceDim,
      onSurfaceVariant: textDim,
      outline: border,
      outlineVariant: border,
      error: const Color(0xFFC62839),
      onError: const Color(0xFFFFFFFF),
    );

    return _build(colorScheme, bg: bg, border: border, text: text, textDim: textDim);
  }

  static ThemeData _build(
    ColorScheme colorScheme, {
    required Color bg,
    required Color border,
    required Color text,
    required Color textDim,
  }) {
    final statusColors =
        colorScheme.brightness == Brightness.dark ? KangoosStatusColors.dark : KangoosStatusColors.light;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      textTheme: _textTheme(text, textDim),
      fontFamily: null,
      extensions: [statusColors],
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamilyFallback: monoFallback,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
      dividerTheme: DividerThemeData(color: border, space: 1, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: textDim),
        labelStyle: TextStyle(color: textDim),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
      ),
      listTileTheme: ListTileThemeData(iconColor: textDim, textColor: text),
      iconTheme: IconThemeData(color: textDim),
      dialogTheme: DialogThemeData(backgroundColor: colorScheme.surface),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        contentTextStyle: TextStyle(color: text),
        behavior: SnackBarBehavior.floating,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
