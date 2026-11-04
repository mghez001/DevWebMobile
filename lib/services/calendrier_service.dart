import 'package:device_calendar/device_calendar.dart';
import '../models/rendez_vous.dart';

class CalendrierService {
  final DeviceCalendarPlugin calendrier = DeviceCalendarPlugin();

  Future<List<RendezVous>> recupererRendezVous() async {
    // Demander l'autorisation d'accéder au calendrier
    final permission = await calendrier.requestPermissions();

    if (permission.data != true) {
      throw StateError('Permission calendrier refusée');
    }

    // Récupérer les calendriers du téléphone
    final resultat = await calendrier.retrieveCalendars();

    if (!resultat.isSuccess || resultat.data == null) {
      throw StateError('Impossible de récupérer les calendriers');
    }

    // Préparer la liste des rendez-vous
    final List<RendezVous> rendezVous = [];

    final maintenant = DateTime.now();
    final finRecherche = maintenant.add(const Duration(days: 1));

    // Parcourir les calendriers
    for (final agenda in resultat.data!) {
      if (agenda.id == null) continue;

      final evenements = await calendrier.retrieveEvents(
        agenda.id,
        RetrieveEventsParams(
          startDate: maintenant.subtract(const Duration(days: 1)),
          endDate: finRecherche,
        ),
      );

      if (!evenements.isSuccess || evenements.data == null) {
        throw StateError('Impossible de récupérer les événements');
      }

      // Transformer les événements en RendezVous
      for (final event in evenements.data!) {
        if (event.start != null && event.end != null) {
          final debut = event.start!;
          final fin = event.end!;

          // Garder les rendez-vous qui ne sont pas déjà terminés
          if (fin.isAfter(maintenant) &&
              debut.isBefore(finRecherche)) {
            rendezVous.add(
              RendezVous(
                titre: event.title ?? 'Rendez-vous',
                debut: debut,
                fin: fin,
              ),
            );
          }
        }
      }
    }

    return rendezVous;
  }
}
