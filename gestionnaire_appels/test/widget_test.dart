import 'package:flutter_test/flutter_test.dart';
import 'package:gestionnaire_appels/widgets/formats.dart';

/// Tests des petits outils d'affichage.
/// (Le test de démarrage de l'appli d'origine ne s'applique plus : l'appli
/// ouvre maintenant une connexion SIP au démarrage.)
void main() {
  test('durées et chronomètre', () {
    expect(formaterDuree(const Duration(seconds: 42)), '42 s');
    expect(formaterDuree(const Duration(seconds: 187)), '3 min 07');
    expect(chrono(const Duration(seconds: 75)), '01:15');
  });

  test('libellé du jour', () {
    final maintenant = DateTime(2026, 11, 16, 10);
    expect(libelleJour(DateTime(2026, 11, 16, 8), maintenant), "Aujourd'hui");
    expect(libelleJour(DateTime(2026, 11, 15, 23), maintenant), 'Hier');
    expect(libelleJour(DateTime(2026, 11, 9), maintenant), 'Lundi 9 novembre');
  });
}
