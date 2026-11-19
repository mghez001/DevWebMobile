import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

/// =====================================================================
///  Direction artistique « Encre & Signal »
///   - Encre : bleu nuit profond pour la barre latérale et les écrans
///     d'appel (sérieux, « standard téléphonique »).
///   - Papier : fond ivoire chaud, cartes blanches arrondies.
///   - Signal : orange vif, utilisé avec parcimonie (sélection, filtrage
///     automatique, logo).
///   - Chaque issue d'appel a sa couleur : vert décroché, rouge manqué /
///     rejeté, bleu messagerie, ambre redirigé.
///   - Chiffres à chasse fixe (heures, numéros) pour un rendu « tableau
///     de bord ».
/// =====================================================================
class Couleurs {
  Couleurs._();

  static const encre = Color(0xFF161A2E);
  static const encreClair = Color(0xFF262B4D);
  static const fond = Color(0xFFF4F2EE);
  static const surface = Colors.white;
  static const trait = Color(0xFFE6E2DA);
  static const texte = Color(0xFF1D2033);
  static const texteDoux = Color(0xFF6B6F85);

  static const signal = Color(0xFFFF6B35);
  static const vert = Color(0xFF22A06B);
  static const rouge = Color(0xFFE5484D);
  static const bleu = Color(0xFF4C6EF5);
  static const ambre = Color(0xFFE8930C);
}

/// Chiffres à chasse fixe (heures, durées, numéros).
const chiffresFixes = [FontFeature.tabularFigures()];

/// Couleur d'avatar stable à partir d'un nom ou d'un numéro.
Color couleurAvatar(String cle) {
  const palette = [
    Color(0xFF33658A),
    Color(0xFF2F4858),
    Color(0xFF7D5BA6),
    Color(0xFFB5651D),
    Color(0xFF2A9D8F),
    Color(0xFFC0504D),
    Color(0xFF5C6B73),
  ];
  final somme = cle.codeUnits.fold<int>(0, (a, b) => a + b);
  return palette[somme % palette.length];
}

/// Style commun des champs de saisie.
InputDecoration champ(String libelle, {IconData? icone}) {
  return InputDecoration(
    labelText: libelle,
    prefixIcon: icone == null ? null : Icon(icone, size: 20),
    filled: true,
    fillColor: Couleurs.fond,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}

ThemeData construireTheme() {
  final schema = ColorScheme.fromSeed(seedColor: Couleurs.signal).copyWith(
    primary: Couleurs.signal,
    onPrimary: Colors.white,
    secondary: Couleurs.encre,
    onSecondary: Colors.white,
    surface: Couleurs.surface,
    onSurface: Couleurs.texte,
    error: Couleurs.rouge,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: schema,
    scaffoldBackgroundColor: Couleurs.fond,
    dividerTheme: const DividerThemeData(color: Couleurs.trait, thickness: 1),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Couleurs.encre,
      foregroundColor: Colors.white,
      shape: CircleBorder(),
      elevation: 3,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Couleurs.encre,
    ),
  );
}
