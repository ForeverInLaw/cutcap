import 'package:flutter/material.dart';

import 'cutcap_tokens.dart';

/// The Material 3 theme built from [CutcapTokens]: one grotesk, flat
/// fields, hairline paper rules, 2 px corners, no shadows, tints or glow.
/// There is one dark scheme, whatever the system theme.
abstract final class CutcapTheme {
  static const fontFamily = 'GolosText';

  static final ThemeData data = _build(CutcapTokens.graphite);

  /// Material type roles mapped to the editor's type scale.
  static const TextTheme _type = TextTheme(
    // Headline timecode, desktop and phone.
    displayLarge: TextStyle(
      fontSize: 80,
      fontWeight: FontWeight.w700,
      height: 1,
      letterSpacing: -3.2,
    ),
    displaySmall: TextStyle(
      fontSize: 44,
      fontWeight: FontWeight.w700,
      height: 1,
      letterSpacing: -1.3,
    ),
    // Empty-state heading.
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing: -0.8,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: -0.5,
    ),
    // Total duration beside the headline timecode.
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w400,
      height: 1,
      letterSpacing: -0.6,
    ),
    // Wordmark.
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      height: 1,
      letterSpacing: -0.66,
    ),
    // The "File not found" chip on a missing clip.
    titleSmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.2,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.4,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.35,
    ),
    // Status line, ruler labels.
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.3,
    ),
    // Buttons.
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.2,
    ),
    // Ruler guide words.
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
    // Caption above the timecode, clip labels.
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 1.2,
      letterSpacing: 0.4,
    ),
  );

  static ThemeData _build(CutcapTokens t) {
    const brightness = Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: t.ink,
      onPrimary: t.workspace,
      secondary: t.ink,
      onSecondary: t.workspace,
      // Errors are told with text and an icon in ink; red stays reserved
      // for time and cuts.
      error: t.ink,
      onError: t.workspace,
      surface: t.workspace,
      onSurface: t.ink,
      onSurfaceVariant: t.inkSecondary,
      surfaceContainerLowest: t.workspace,
      surfaceContainerLow: t.workspace,
      surfaceContainer: t.workspace,
      surfaceContainerHigh: t.workspace,
      surfaceContainerHighest: t.frame,
      outline: t.ink,
      outlineVariant: t.inkMuted,
      inverseSurface: t.ink,
      onInverseSurface: t.workspace,
      shadow: Colors.transparent,
      surfaceTint: Colors.transparent,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: CutcapTokens.radius.controlRadius,
    );
    final textTheme = _type.apply(
      fontFamily: fontFamily,
      bodyColor: t.ink,
      displayColor: t.ink,
    );
    final disabledInk = t.ink.withValues(alpha: 0.38);
    const padding = EdgeInsets.symmetric(horizontal: 14);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: t.workspace,
      extensions: [t],
      splashFactory: InkRipple.splashFactory,
      hoverColor: t.ink.withValues(alpha: 0.06),
      focusColor: t.ink.withValues(alpha: 0.10),
      dividerTheme: DividerThemeData(color: t.ink, thickness: 1, space: 1),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: shape,
          padding: padding,
          minimumSize: const Size(0, 48),
          foregroundColor: t.ink,
          disabledForegroundColor: disabledInk,
          textStyle: textTheme.labelLarge,
          iconSize: 20,
        ).copyWith(side: _outline(t)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          minimumSize: const Size(0, 48),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          iconSize: 20,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 48),
          foregroundColor: t.ink,
          textStyle: textTheme.labelLarge,
          iconSize: 20,
        ),
      ),
      // Menus are a graphite field cut out by a hairline, never a raised
      // card; items are 48 dp rows.
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(t.workspace),
          elevation: const WidgetStatePropertyAll(0),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          shape: WidgetStatePropertyAll(
            shape.copyWith(side: BorderSide(color: t.ink)),
          ),
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: MenuItemButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          foregroundColor: t.ink,
          disabledForegroundColor: disabledInk,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(shape: shape, iconSize: 22),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: t.ink,
          borderRadius: CutcapTokens.radius.controlRadius,
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: t.workspace),
        waitDuration: const Duration(milliseconds: 500),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.ink,
        linearTrackColor: t.inkMuted.withValues(alpha: 0.35),
        linearMinHeight: 2,
        borderRadius: BorderRadius.zero,
      ),
    );
  }

  /// Hairline ink outline that fades when disabled.
  static WidgetStateProperty<BorderSide> _outline(CutcapTokens t) =>
      WidgetStateProperty.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.disabled)
              ? t.ink.withValues(alpha: 0.2)
              : t.ink,
        ),
      );
}
