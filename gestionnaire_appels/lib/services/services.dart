import '../models/modeles.dart';
import '../repositories/repositories.dart';
import 'gestionnaire_appels.dart';
import 'moteur_regles.dart';
import 'sip/sip_service.dart';
import 'sip/sip_service_ua.dart';

/// =====================================================================
///  Services — un seul exemplaire de chaque service pour toute l'appli
///  (injection de dépendances « à la main »).
///
///  Les écrans font : Services.contacts, Services.gestionnaire, …
///  Pour développer sans serveur : remplacer SipServiceUa() par
///  SipServiceFaux() ici, et rien d'autre.
/// =====================================================================
class Services {
  Services._();

  static final SipServiceUa sipUa = SipServiceUa();
  static final SipService sip = sipUa;

  static final ContactRepository contacts = ContactRepositoryMemoire();

  static final RegleRepository regles = RegleRepositoryMemoire([
    MoteurDeRegles.regleNumerosIndesirables(),
    MoteurDeRegles.regleVacances,
    MoteurDeRegles.regleEnRendezVous,
    MoteurDeRegles.regleHorsHoraires(),
  ]);

  // ⚠️ TEST : faux cours en ce moment (à enlever avant de pousser)
  static final CalendrierRepository calendrier = CalendrierRepositoryMemoire([
    EvenementCalendrier(
      id: 'test',
      titre: 'Vacances (TEST)',
      debut: DateTime.now().subtract(const Duration(days: 2)),
      fin: DateTime.now().add(const Duration(days: 5)),
    ),
  ]);

  static final JournalRepository journal = JournalRepositoryMemoire();

  static final GestionnaireAppels gestionnaire = GestionnaireAppels(
    sip: sip,
    contacts: contacts,
    regles: regles,
    calendrier: calendrier,
    journal: journal,
    // ⚠️ Seuil abaissé à 3 pour tester l'anti-harcèlement facilement.
    //    Remettre const MoteurDeRegles() (10 appels) pour la version finale.
    moteur: const MoteurDeRegles(seuilHarcelement: 3),
  );

  /// Compte de test par défaut (serveur Asterisk local).
  static const compteParDefaut = CompteSip(
    serveur: '127.0.0.1',
    utilisateur: '400',
    motDePasse: '400',
    nomAffiche: 'Appli Flutter',
  );
}
