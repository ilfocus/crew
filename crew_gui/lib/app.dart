// crew_gui/lib/app.dart
import 'package:flutter/material.dart';

/// Crew GUI 设计 token 与主题。
///
/// 设计语言：桌面端开发工具风格，暗色优先 + 单一强调色（electric blue），
/// 中性灰冷调（zinc 系），统一圆角与紧凑桌面节奏。
class CrewApp extends StatelessWidget {
  final Widget home;
  const CrewApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crew',
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: ThemeMode.dark,
      home: home,
    );
  }
}

// ─── 色彩 token ────────────────────────────────────────────
// 暗色：zinc-950 底 + electric blue 强调
const _darkScheme = ColorScheme.dark(
  brightness: Brightness.dark,
  primary: Color(0xFF4A9EFF),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFF1E3A5F),
  onPrimaryContainer: Color(0xFFB4D4FF),
  secondary: Color(0xFF7C8595),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFF2A2D33),
  onSecondaryContainer: Color(0xFFCBD0D8),
  tertiary: Color(0xFF6E7681),
  tertiaryContainer: Color(0xFF2E3138),
  onTertiaryContainer: Color(0xFFC8CDD4),
  error: Color(0xFFFF5C5C),
  onError: Color(0xFFFFFFFF),
  surface: Color(0xFF16171A),
  onSurface: Color(0xFFE4E4E7),
  surfaceContainerLow: Color(0xFF1C1D21),
  surfaceContainer: Color(0xFF212228),
  surfaceContainerHigh: Color(0xFF26272D),
  onSurfaceVariant: Color(0xFF9CA0A8),
  outline: Color(0xFF3A3C42),
  outlineVariant: Color(0xFF2A2C32),
);

// 亮色：zinc-50 底 + 同色系强调
const _lightScheme = ColorScheme.light(
  brightness: Brightness.light,
  primary: Color(0xFF2563EB),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFE0ECFF),
  onPrimaryContainer: Color(0xFF1E3A5F),
  secondary: Color(0xFF52525B),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFE4E4E7),
  onSecondaryContainer: Color(0xFF3F3F46),
  tertiary: Color(0xFF6E7681),
  tertiaryContainer: Color(0xFFE9EBEE),
  onTertiaryContainer: Color(0xFF3F3F46),
  error: Color(0xFFDC2626),
  onError: Color(0xFFFFFFFF),
  surface: Color(0xFFFAFAFA),
  onSurface: Color(0xFF18181B),
  surfaceContainerLow: Color(0xFFF4F4F5),
  surfaceContainer: Color(0xFFEFEFF1),
  surfaceContainerHigh: Color(0xFFE9E9EC),
  onSurfaceVariant: Color(0xFF52525B),
  outline: Color(0xFFD4D4D8),
  outlineVariant: Color(0xFFE4E4E7),
);

// ─── 圆角 token ────────────────────────────────────────────
const _radiusSm = 6.0;
const _radiusMd = 10.0;
const _radiusLg = 14.0;

ThemeData get _darkTheme => _buildTheme(_darkScheme);
ThemeData get _lightTheme => _buildTheme(_lightScheme);

ThemeData _buildTheme(ColorScheme c) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: c,
    visualDensity: VisualDensity.compact,
    fontFamily: _fontFamily,
  );

  return base.copyWith(
    scaffoldBackgroundColor: c.surface,
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: c.primary.withValues(alpha: 0.06),
    hoverColor: c.primary.withValues(alpha: 0.08),
    textTheme: _buildTextTheme(base.textTheme, c),
    appBarTheme: AppBarTheme(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: _buildTextTheme(base.textTheme, c)
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w600, color: c.onSurface),
      iconTheme: IconThemeData(color: c.onSurfaceVariant, size: 20),
    ),
    cardTheme: CardThemeData(
      color: c.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusMd),
        side: BorderSide(color: c.outlineVariant, width: 1),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.onSurfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusSm),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: c.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceContainer,
      hintStyle: TextStyle(color: c.onSurfaceVariant.withValues(alpha: 0.6)),
      labelStyle: TextStyle(color: c.onSurfaceVariant),
      floatingLabelStyle: TextStyle(color: c.primary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusSm),
        borderSide: BorderSide(color: c.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusSm),
        borderSide: BorderSide(color: c.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusSm),
        borderSide: BorderSide(color: c.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusSm),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        minimumSize: const Size(0, 38),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: c.surfaceContainerHigh,
        foregroundColor: c.onSurface,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusSm),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        minimumSize: const Size(0, 38),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusSm),
        ),
        side: BorderSide(color: c.outline),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        minimumSize: const Size(0, 38),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusSm),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: c.onSurfaceVariant,
        iconSize: 18,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusSm),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surfaceContainer,
      selectedColor: c.primaryContainer,
      labelStyle: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
      side: BorderSide(color: c.outlineVariant),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusSm),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return c.primary;
        return c.outline;
      }),
      trackColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) {
          return c.primary.withValues(alpha: 0.4);
        }
        return c.surfaceContainerHigh;
      }),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return c.primary;
        return c.onSurfaceVariant;
      }),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return c.primary;
        return Colors.transparent;
      }),
      side: BorderSide(color: c.outline, width: 1.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusSm * 0.6),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.surfaceContainerHigh,
      contentTextStyle: TextStyle(color: c.onSurface, fontSize: 13),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusSm),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusLg),
      ),
      titleTextStyle: TextStyle(
        color: c.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.primary,
      linearTrackColor: c.surfaceContainerHigh,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.primary,
      foregroundColor: c.onPrimary,
      elevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusMd),
      ),
      extendedTextStyle:
          const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      extendedPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.hovered) ||
            s.contains(WidgetState.dragged)) {
          return c.outline;
        }
        return c.outlineVariant;
      }),
      thickness: const WidgetStatePropertyAll(8),
      radius: const Radius.circular(4),
      thumbVisibility: const WidgetStatePropertyAll(false),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(_radiusSm),
        border: Border.all(color: c.outlineVariant),
      ),
      textStyle: TextStyle(color: c.onSurface, fontSize: 12),
      waitDuration: const Duration(milliseconds: 400),
    ),
  );
}

TextTheme _buildTextTheme(TextTheme base, ColorScheme c) {
  return base.copyWith(
    displayLarge: base.displayLarge?.copyWith(fontFamily: _fontFamily),
    headlineMedium: base.headlineMedium?.copyWith(fontFamily: _fontFamily),
    titleLarge: base.titleLarge?.copyWith(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
    ),
    titleSmall: base.titleSmall?.copyWith(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: base.bodyLarge?.copyWith(fontFamily: _fontFamily),
    bodyMedium: base.bodyMedium?.copyWith(fontFamily: _fontFamily),
    bodySmall: base.bodySmall?.copyWith(
      fontFamily: _fontFamily,
      color: c.onSurfaceVariant,
    ),
    labelLarge: base.labelLarge?.copyWith(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w600,
    ),
  );
}

// macOS / iOS 用系统字体，其它平台回落到默认
const _fontFamily = null;
