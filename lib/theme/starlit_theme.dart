import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:starlitfilms/theme/tokens.dart';

ThemeData buildStarlitTheme() {
  const scheme = ColorScheme.dark(
    primary: SC.primary,
    onPrimary: Colors.white,
    secondary: SC.star,
    onSecondary: Colors.white,
    surface: SC.surface,
    onSurface: SC.text,
    surfaceContainerHighest: SC.surfaceHigher,
    error: SC.danger,
    outline: SC.outline,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Poppins',
    colorScheme: scheme,
    scaffoldBackgroundColor: SC.bg,
    splashFactory: InkSparkle.splashFactory,
  );

  final text = base.textTheme.apply(bodyColor: SC.text, displayColor: SC.text);

  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(SRadius.md),
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.15),
      titleLarge: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w600, letterSpacing: -0.3),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.45),
      bodySmall: text.bodySmall?.copyWith(color: SC.textMuted),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: SC.starSoft,
      selectionColor: SC.primary.withValues(alpha: 0.45),
      selectionHandleColor: SC.star,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: SC.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: SC.text,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SC.surfaceHigh.withValues(alpha: 0.7),
      hintStyle: const TextStyle(color: SC.textFaint),
      counterStyle: const TextStyle(color: SC.textFaint, fontSize: 11.5),
      labelStyle: const TextStyle(color: SC.textMuted),
      floatingLabelStyle: const TextStyle(color: SC.starSoft),
      prefixIconColor: SC.textMuted,
      suffixIconColor: SC.textMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border(Colors.transparent),
      enabledBorder: border(SC.outline.withValues(alpha: 0.35)),
      focusedBorder: border(SC.star, 1.5),
      errorBorder: border(SC.danger),
      focusedErrorBorder: border(SC.danger, 1.5),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SC.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: SC.surfaceHigher,
        disabledForegroundColor: SC.textFaint,
        elevation: 0,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SRadius.md)),
        textStyle: const TextStyle(
            fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SC.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SRadius.md)),
        textStyle: const TextStyle(
            fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: SC.starSoft,
        textStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: SC.text),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: SC.primary,
      foregroundColor: Colors.white,
      elevation: 6,
      shape: StadiumBorder(),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: SC.surfaceHigher,
      contentTextStyle: const TextStyle(fontFamily: 'Poppins', color: SC.text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SRadius.md)),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: SC.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SRadius.xl)),
      titleTextStyle: const TextStyle(
          fontFamily: 'Poppins', fontSize: 19, fontWeight: FontWeight.w600, color: SC.text),
      contentTextStyle:
          const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: SC.textMuted, height: 1.45),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: SC.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: SC.outline,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(SRadius.xl)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: SC.textMuted,
      textColor: SC.text,
      contentPadding: EdgeInsets.symmetric(horizontal: SSpace.page),
    ),
    dividerTheme: DividerThemeData(color: SC.outline.withValues(alpha: 0.4), thickness: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: SC.star),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(SC.star.withValues(alpha: 0.5)),
      radius: const Radius.circular(8),
      thickness: const WidgetStatePropertyAll(4),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: SC.surfaceHigher,
        borderRadius: BorderRadius.circular(SRadius.sm),
      ),
      textStyle: const TextStyle(fontFamily: 'Poppins', color: SC.text, fontSize: 12),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}
