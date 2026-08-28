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
    done: Color(0xFF61D5B5),
    doneSoft: Color(0x2461D5B5),
    next: Color(0xFFFF8A76),
    nextSoft: Color(0x24FF8A76),
    later: Color(0xFF9B9EAE),
    laterSoft: Color(0x1F9B9EAE),
  );

  static const light = KangoosStatusColors(
    done: Color(0xFF187D69),
    doneSoft: Color(0x1F187D69),
    next: Color(0xFFC64F45),
    nextSoft: Color(0x1FC64F45),
    later: Color(0xFF666978),
    laterSoft: Color(0x14666978),
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
  KangoosStatusColors lerp(
      ThemeExtension<KangoosStatusColors>? other, double t) {
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
    'Cascadia Mono',
    'Consolas',
    'Courier New',
    'monospace',
  ];

  static TextTheme _textTheme(Color text, Color textDim) {
    final display = TextStyle(
      fontFamily: 'Bahnschrift',
      fontFamilyFallback: const ['Arial Narrow', 'Segoe UI', 'Arial'],
      color: text,
    );
    final body = TextStyle(
      fontFamily: 'Segoe UI Variable Text',
      fontFamilyFallback: const ['Segoe UI', 'Arial'],
      color: text,
    );
    return TextTheme(
      headlineLarge: display.copyWith(
        fontSize: 42,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.5,
        height: 1.02,
      ),
      headlineMedium: display.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.7,
      ),
      titleLarge: display.copyWith(fontSize: 21, fontWeight: FontWeight.w600),
      titleMedium: display.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      labelLarge: body.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
      labelMedium: body.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
      labelSmall: TextStyle(
        fontFamilyFallback: monoFallback,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.45,
        color: textDim,
      ),
      bodyLarge: body.copyWith(fontSize: 15.5, height: 1.55),
      bodyMedium: body.copyWith(fontSize: 14, height: 1.5),
      bodySmall: body.copyWith(fontSize: 12.5, color: textDim, height: 1.45),
    );
  }

  static ThemeData get dark {
    const bg = Color(0xFF101119);
    const surface = Color(0xFF171923);
    const surfaceDim = Color(0xFF202331);
    const border = Color(0xFF303445);
    const text = Color(0xFFF2F0EB);
    const textDim = Color(0xFF9B9EAE);
    const accent = Color(0xFF9A8CFF);
    const accentContrast = Color(0xFF17142F);

    final colorScheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: accent,
      onPrimary: accentContrast,
      primaryContainer: const Color(0xFF302B5B),
      onPrimaryContainer: accent,
      secondary: const Color(0xFFFF8A76),
      secondaryContainer: const Color(0xFF542C2B),
      onSecondaryContainer: const Color(0xFFFFD9D2),
      surface: surface,
      onSurface: text,
      surfaceContainerHighest: surfaceDim,
      onSurfaceVariant: textDim,
      outline: border,
      outlineVariant: border,
      error: const Color(0xFFFF727D),
      onError: const Color(0xFF3C090D),
    );

    return _build(colorScheme,
        bg: bg, border: border, text: text, textDim: textDim);
  }

  static ThemeData get light {
    const bg = Color(0xFFF2EFEA);
    const surface = Color(0xFFFCFAF7);
    const surfaceDim = Color(0xFFE8E5E1);
    const border = Color(0xFFD4D0C9);
    const text = Color(0xFF181922);
    const textDim = Color(0xFF666978);
    const accent = Color(0xFF6558D8);
    const accentContrast = Color(0xFFFFFFFF);

    final colorScheme = ColorScheme.light(
      brightness: Brightness.light,
      primary: accent,
      onPrimary: accentContrast,
      primaryContainer: const Color(0xFFE3DFFF),
      onPrimaryContainer: const Color(0xFF352C94),
      secondary: const Color(0xFFC64F45),
      secondaryContainer: const Color(0xFFFFDAD4),
      onSecondaryContainer: const Color(0xFF77251F),
      surface: surface,
      onSurface: text,
      surfaceContainerHighest: surfaceDim,
      onSurfaceVariant: textDim,
      outline: border,
      outlineVariant: border,
      error: const Color(0xFFC62839),
      onError: const Color(0xFFFFFFFF),
    );

    return _build(colorScheme,
        bg: bg, border: border, text: text, textDim: textDim);
  }

  static ThemeData _build(
    ColorScheme colorScheme, {
    required Color bg,
    required Color border,
    required Color text,
    required Color textDim,
  }) {
    final statusColors = colorScheme.brightness == Brightness.dark
        ? KangoosStatusColors.dark
        : KangoosStatusColors.light;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      textTheme: _textTheme(text, textDim),
      fontFamily: 'Segoe UI Variable Text',
      fontFamilyFallback: const ['Segoe UI', 'Arial'],
      extensions: [statusColors],
      focusColor: colorScheme.primary.withValues(alpha: 0.22),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Bahnschrift',
          fontFamilyFallback: const ['Arial Narrow', 'Segoe UI', 'Arial'],
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
      dividerTheme: DividerThemeData(color: border, space: 1, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: textDim),
        labelStyle: TextStyle(color: textDim),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: border),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textDim,
        textColor: text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      iconTheme: IconThemeData(color: textDim),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        modalBackgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        contentTextStyle: TextStyle(color: text),
        behavior: SnackBarBehavior.floating,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textDim,
          highlightColor: colorScheme.primary.withValues(alpha: 0.14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
      ),
    );
  }
}
