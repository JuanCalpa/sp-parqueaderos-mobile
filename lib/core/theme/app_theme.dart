import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Tipografia: Plus Jakarta Sans para la interfaz y JetBrains Mono para placas, codigos y dinero.
class AppText {
  /// Aumento general del texto sobre el tamano que el usuario tenga configurado en su celular,
  /// para que la app se lea comodamente sin cambiar las proporciones del diseno.
  static const scale = 1.12;

  /// Escala final: preferencia del sistema x [scale], con limites para no romper la distribucion.
  static TextScaler scaler(TextScaler system) => TextScaler.linear((system.scale(100) / 100 * scale).clamp(1.0, 1.6));

  static TextStyle sans({double size = 13, FontWeight weight = FontWeight.w500, Color color = AppColors.text, double? letterSpacing}) =>
      GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: weight, color: color, letterSpacing: letterSpacing);

  static TextStyle mono({double size = 13, FontWeight weight = FontWeight.w700, Color color = AppColors.text, double? letterSpacing}) =>
      GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: weight, color: color, letterSpacing: letterSpacing);

  static TextStyle get display => sans(size: 26, weight: FontWeight.w800, letterSpacing: -0.5);
  static TextStyle get headline => sans(size: 18, weight: FontWeight.w700, letterSpacing: -0.2);
  static TextStyle get title => sans(size: 15, weight: FontWeight.w700);
  static TextStyle get body => sans(size: 13);
  static TextStyle get small => sans(size: 11, color: AppColors.textMuted);
  static TextStyle get metric => sans(size: 28, weight: FontWeight.w800, letterSpacing: -0.5);

  /// Etiquetas en mayusculas (VEHICULOS ADENTRO, TOTAL RECAUDADO...).
  static TextStyle get meta => mono(size: 10.5, weight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.6);
  static TextStyle get plate => mono(size: 15, weight: FontWeight.w800, letterSpacing: 1);
  static TextStyle get currency => mono(size: 13, weight: FontWeight.w700);
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.green,
        tertiary: AppColors.blue,
        error: AppColors.primaryDark,
        surface: AppColors.card,
      ),
      scaffoldBackgroundColor: AppColors.canvas,
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.border),
    );
    return base.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(bodyColor: AppColors.text, displayColor: AppColors.text),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.text,
        titleTextStyle: AppText.headline,
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.subtle,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        hintStyle: AppText.sans(color: AppColors.textDisabled),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        errorBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.primaryBorder)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppColors.primary : Colors.white),
        side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: AppText.sans(color: Colors.white, weight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
    );
  }
}
