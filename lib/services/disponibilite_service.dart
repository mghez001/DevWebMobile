import '../models/rendez_vous.dart';

class DisponibiliteService {

  bool estDisponible(
    DateTime maintenant,
    List<RendezVous> rendezVous,
  ) {

    for (final rdv in rendezVous) {

      // Vérifier si l'heure est dans un rendez-vous
      if (!maintenant.isBefore(rdv.debut) &&
          maintenant.isBefore(rdv.fin)) {
        return false;
      }
    }

    // Aucun rendez-vous en cours
    return true;
  }
}

