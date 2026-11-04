import '../models/rendez_vous.dart';

class MessageService {
  String? genererMessage(
    DateTime maintenant,
    List<RendezVous> rendezVous,
  ) {
    for (final rdv in rendezVous) {
      if (!maintenant.isBefore(rdv.debut) &&
          maintenant.isBefore(rdv.fin)) {

        final heure = rdv.fin.hour.toString().padLeft(2, '0');
        final minute = rdv.fin.minute.toString().padLeft(2, '0');

        return 'Bonjour, je suis actuellement indisponible. '
            'Je serai de nouveau disponible à ${heure}h$minute. '
            'Je vous rappellerai dès que possible.';
      }
    }

    // Disponible 
    return null;
  }
}
