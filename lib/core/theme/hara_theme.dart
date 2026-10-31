import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../icons/hara_icons.dart';
import 'hara_colors.dart';
import 'hara_tokens.dart';
import 'hara_typography.dart';
import 'palettes.dart';

/// Assembles [ThemeData] for HaraPlay from a [HaraColors] palette.
abstract final class HaraTheme {
  static ThemeData get light => build(HaraPalettes.saffronLight);
  static ThemeData get dark => build(HaraPalettes.saffronDark);

  static ThemeData build(HaraColors c) {
    final isDark = c.brightness == Brightness.dark;
    final textTheme = HaraTypography.textTheme(c);

    final scheme = ColorScheme(
      brightness: c.brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primary,
      onPrimaryContainer: c.onPrimary,
      secondary: c.emphasis,
      onSecondary: c.background,
      secondaryContainer: c.surfaceAlt,
      onSecondaryContainer: c.foreground,
      tertiary: c.sky,
      onTertiary: c.foreground,
      error: c.danger,
      onError: c.onDanger,
      surface: c.background,
      onSurface: c.foreground,
      onSurfaceVariant: c.mutedForeground,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceAlt,
      surfaceContainerHighest: c.surfaceAlt,
      outline: c.border,
      outlineVariant: c.border.withValues(alpha: 0.25),
      shadow: c.shadow,
      scrim: c.overlay,
      inverseSurface: c.foreground,
      onInverseSurface: c.background,
      inversePrimary: c.primary,
      surfaceTint: Colors.transparent,
    );

    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: c.brightness,
      systemNavigationBarColor: c.background,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );

    final thinBorder = BorderSide(color: c.border, width: HaraBorder.thin);

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      fontFamily: HaraFonts.body,
      textTheme: textTheme,
      extensions: [c, HaraTypography.extras(c)],
      splashFactory: InkRipple.splashFactory,
      // Pushed pages slide along the horizontal shared axis.
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values)
            platform: SharedAxisPageTransitionsBuilder(
              transitionType: SharedAxisTransitionType.horizontal,
              fillColor: c.background,
            ),
        },
      ),
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) => const Icon(HaraIcons.arrowLeft),
        closeButtonIconBuilder: (_) => const Icon(HaraIcons.x),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
        systemOverlayStyle: overlayStyle,
      ),
      iconTheme: IconThemeData(color: c.foreground, size: HaraSizes.icon),
      dividerTheme: DividerThemeData(
        color: c.border.withValues(alpha: 0.25),
        thickness: 1,
        space: 1,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.emphasis,
        inactiveTrackColor: c.surfaceAlt,
        thumbColor: c.emphasis,
        overlayColor: c.emphasis.withValues(alpha: 0.12),
        trackHeight: 4,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.emphasis,
        linearTrackColor: c.surfaceAlt,
        circularTrackColor: c.surfaceAlt,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBackgroundColor: c.surface,
        modalBarrierColor: c.overlay,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: c.mutedForeground,
        dragHandleSize: const Size(40, 4),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(HaraRadius.xl),
          ),
          side: BorderSide(color: c.border, width: HaraBorder.regular),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HaraRadius.lg),
          side: BorderSide(color: c.border, width: HaraBorder.regular),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.foreground,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: c.background),
        // The bar is inverted (foreground colour), so the brand fill only
        // reads on the dark bar of the light theme.
        actionTextColor: snackBarActionColor(c),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HaraRadius.md),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        hintStyle: textTheme.bodyMedium?.copyWith(color: c.mutedForeground),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: HaraSpacing.lg,
          vertical: HaraSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HaraRadius.md),
          borderSide: thinBorder,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HaraRadius.md),
          borderSide: thinBorder,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HaraRadius.md),
          borderSide: BorderSide(color: c.border, width: HaraBorder.regular),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.foreground,
        selectionColor: c.primary.withValues(alpha: 0.5),
        selectionHandleColor: c.emphasis,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.foreground,
          borderRadius: BorderRadius.circular(HaraRadius.sm),
        ),
        textStyle: textTheme.labelMedium?.copyWith(color: c.background),
      ),
    );
  }
}

/// "Undo" on a snackbar: brand colour on the light theme's dark bar, the
/// page background on the dark theme's light bar.
Color snackBarActionColor(HaraColors c) =>
    c.brightness == Brightness.dark ? c.background : c.primary;
