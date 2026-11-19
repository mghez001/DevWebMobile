import '../models/modeles.dart';
import '../repositories/repositories.dart';
import 'etat_appels.dart';
import 'gestionnaire_appels.dart';
import 'moteur_regles.dart';
import 'sip/sip_service.dart';
import 'sip/sip_service_ua.dart';

/// =====================================================================
///  Services — un seul exemplaire de chaque service pour toute l'appli
///  (injection de dépendances « à la main »).
///
///  Les écrans font : Services.contacts, Services.etat, …
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

  static final CalendrierRepository calendrier = CalendrierRepositoryMemoire();

  static final JournalRepository journal = JournalRepositoryMemoire();

  static final MessageRepository messages = MessageRepositoryMemoire();

  static final GestionnaireAppels gestionnaire = GestionnaireAppels(
    sip: sip,
    contacts: contacts,
    regles: regles,
    calendrier: calendrier,
    journal: journal,
    messages: messages,
    // ⚠️ Seuil abaissé à 3 pour tester l'anti-harcèlement facilement.
    //    Remettre const MoteurDeRegles() (10 appels) pour la version finale.
    moteur: const MoteurDeRegles(seuilHarcelement: 3),
  );

  /// État affiché par l'interface (appel qui sonne, appel en cours…).
  static late final EtatAppels etat;

  /// À appeler une fois au démarrage (main.dart).
  static void initialiser() {
    gestionnaire.demarrer();
    etat = EtatAppels(gestionnaire, sip);
    // Connexion automatique au démarrage avec le compte par défaut
    // (modifiable ensuite avec le bouton rond en haut à droite).
    sip.connecter(compteParDefaut);
  }

  /// Compte de test par défaut (serveur Asterisk local).
  static const compteParDefaut = CompteSip(
    serveur: '127.0.0.1',
    utilisateur: '400',
    motDePasse: '400',
    nomAffiche: 'Appli Flutter',
  );

  /// Contact correspondant à un numéro (null si inconnu).
  static Contact? contactDe(String numero) =>
      gestionnaire.moteur.trouverContact(numero, contacts.tous);

  // ------------------------------------------------------------------
  //  Ne pas déranger = une règle utilisateur « tous → messagerie ».
  //  Les favoris passent quand même (règle système, testée avant).
  // ------------------------------------------------------------------

  static const idNePasDeranger = 'ne-pas-deranger';

  static bool nePasDerangerActif(List<Regle> liste) =>
      liste.any((r) => r.id == idNePasDeranger);

  static Future<void> definirNePasDeranger(bool actif) {
    if (!actif) return regles.supprimer(idNePasDeranger);
    return regles.enregistrer(const Regle(
      id: idNePasDeranger,
      nom: 'Ne pas déranger',
      priorite: 100,
      condition: ConditionRegle(),
      action: ActionRegle(type: TypeAction.messagerie),
    ));
  }
}
