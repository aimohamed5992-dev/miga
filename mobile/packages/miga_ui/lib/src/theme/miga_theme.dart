import 'package:flutter/material.dart';

import 'miga_colors.dart';

class MigaSpacing {
  MigaSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const page = EdgeInsets.symmetric(horizontal: 20);
}

class MigaRadius {
  MigaRadius._();
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const pill = 100.0;
  static BorderRadius all(double r) => BorderRadius.circular(r);
}

class MigaShadows {
  MigaShadows._();
  static const soft = [BoxShadow(color: Color(0x0F16161A), blurRadius: 18, offset: Offset(0, 6))];
  static const card = [BoxShadow(color: Color(0x0A16161A), blurRadius: 12, offset: Offset(0, 4))];
  static List<BoxShadow> glow([Color c = MigaColors.primary]) => [
    BoxShadow(color: c.withValues(alpha: .35), blurRadius: 20, offset: const Offset(0, 8)),
  ];
}

/// Which app is running — drives small branding differences.
enum MigaRole {
  customer('ميجا', 'اشترِ مع الجماعة بسعر الجملة', MigaColors.primary),
  merchant('ميجا للتجار', 'بِع بالجملة لآلاف العملاء', MigaColors.merchantAccent),
  driver('ميجا كابتن', 'وصّل واكسب مع كل طلب', MigaColors.driverAccent),
  admin('ميجا — لوحة الإدارة', 'إدارة منصة الشراء الجماعي', MigaColors.primary);

  const MigaRole(this.appName, this.tagline, this.accent);
  final String appName;
  final String tagline;
  final Color accent;
}

class MigaTheme {
  MigaTheme._();

  static const fontFamily = 'packages/miga_ui/Tajawal';

  static TextTheme _textTheme() {
    // Bundled in miga_ui; package fonts are addressed as packages/<pkg>/<family>.
    final base = Typography.material2021().black.apply(fontFamily: fontFamily);
    TextStyle s(TextStyle? t, double size, FontWeight w, [Color c = MigaColors.textPrimary]) =>
        (t ?? const TextStyle()).copyWith(fontSize: size, fontWeight: w, color: c, height: 1.4);
    return base.copyWith(
      displayLarge: s(base.displayLarge, 34, FontWeight.w800),
      displayMedium: s(base.displayMedium, 28, FontWeight.w800),
      headlineLarge: s(base.headlineLarge, 24, FontWeight.w800),
      headlineMedium: s(base.headlineMedium, 22, FontWeight.w700),
      headlineSmall: s(base.headlineSmall, 20, FontWeight.w700),
      titleLarge: s(base.titleLarge, 18, FontWeight.w700),
      titleMedium: s(base.titleMedium, 16, FontWeight.w700),
      titleSmall: s(base.titleSmall, 14, FontWeight.w700),
      bodyLarge: s(base.bodyLarge, 16, FontWeight.w500),
      bodyMedium: s(base.bodyMedium, 14, FontWeight.w500),
      bodySmall: s(base.bodySmall, 12, FontWeight.w500, MigaColors.textSecondary),
      labelLarge: s(base.labelLarge, 15, FontWeight.w700),
      labelMedium: s(base.labelMedium, 13, FontWeight.w600),
      labelSmall: s(base.labelSmall, 11, FontWeight.w600, MigaColors.textSecondary),
    );
  }

  static ThemeData light([MigaRole role = MigaRole.customer]) {
    // Customer keeps brand red for actions; merchant / driver use their accent (red stays for brand marks).
    final main = role.accent;
    final text = _textTheme();
    final scheme = ColorScheme.fromSeed(
      seedColor: MigaColors.primary,
      primary: main,
      onPrimary: Colors.white,
      secondary: role.accent,
      surface: MigaColors.surface,
      error: MigaColors.error,
    );
    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: MigaRadius.all(MigaRadius.md), borderSide: BorderSide(color: c, width: w));

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: MigaColors.background,
      textTheme: text,
      fontFamily: fontFamily,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: MigaColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: MigaColors.textPrimary,
        titleTextStyle: text.titleLarge,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: main,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(54),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: MigaRadius.all(MigaRadius.md)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: main,
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: main, width: 1.4),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: MigaRadius.all(MigaRadius.md)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: main, textStyle: text.labelLarge)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MigaColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: text.bodyMedium?.copyWith(color: MigaColors.textHint),
        labelStyle: text.bodyMedium?.copyWith(color: MigaColors.textSecondary),
        border: border(MigaColors.border),
        enabledBorder: border(MigaColors.border),
        focusedBorder: border(main, 1.5),
        errorBorder: border(MigaColors.error),
        focusedErrorBorder: border(MigaColors.error, 1.5),
      ),
      cardTheme: CardThemeData(
        color: MigaColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: MigaRadius.all(MigaRadius.lg)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: MigaColors.surface,
        selectedColor: main,
        side: const BorderSide(color: MigaColors.border),
        labelStyle: text.labelMedium,
        secondaryLabelStyle: text.labelMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: MigaRadius.all(MigaRadius.pill)),
        showCheckmark: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: MigaColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: main.withValues(alpha: .1),
        height: 70,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelSmall?.copyWith(
            color: s.contains(WidgetState.selected) ? main : MigaColors.textSecondary,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? main : MigaColors.textSecondary),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: MigaColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(MigaRadius.xl))),
      ),
      dividerTheme: const DividerThemeData(color: MigaColors.divider, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: MigaColors.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: MigaRadius.all(MigaRadius.md)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? MigaColors.success : MigaColors.border),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}
