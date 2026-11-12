import 'dart:async';

import '../models/modeles.dart';
import '../repositories/repositories.dart';
import 'moteur_regles.dart';
import 'sip/sip_service.dart';

/// =====================================================================
///  GestionnaireAppels — l'orchestrateur (le « cerveau »).
///
///  1. écoute les appels entrants du SipService
///  2. construit le ContexteDecision (contacts, règles, calendrier, journal)
///  3. demande la décision au MoteurDeRegles
///  4. l'exécute via le SipService (sonner / rejeter / rediriger / messagerie)
///  5. écrit le résultat dans le journal
///
///  Le FRONT passe par cette classe (jamais directement par sip_ua).
/// =====================================================================
class GestionnaireAppels {
  GestionnaireAppels({
    required this.sip,
    required this.contacts,
    required this.regles,
    required this.calendrier,
    required this.journal,
    this.moteur = const MoteurDeRegles(),
    this.cibleMessagerie = 'vm400',
    DateTime Function()? horloge,
  }) : _horloge = horloge ?? DateTime.now;

  final SipService sip;
  final ContactRepository contacts;
  final RegleRepository regles;
  final CalendrierRepository calendrier;
  final JournalRepository journal;
  final MoteurDeRegles moteur;

  /// Extension Asterisk de la messagerie vocale (dialplan : VoiceMail).
  final String cibleMessagerie;

  /// Injectable pour les tests (simuler « 23h un dimanche »…).
  final DateTime Function() _horloge;

  final _aSonner = StreamController<AppelEntrant>.broadcast();
  final _decisions = StreamController<(AppelEntrant, Decision)>.broadcast();

  /// Appels qui ont sonné et attendent une réponse : id → (appel, décision).
  final Map<String, (AppelEntrant, Decision)> _enAttente = {};
  final Set<String> _decroches = {};
  final Map<String, DateTime> _debutCommunication = {};
  final Map<String, Timer> _minuteurs = {};
  final Map<String, DateTime> _bloquesJusqua = {};

  StreamSubscription<AppelEntrant>? _abonnementAppels;
  StreamSubscription<EtatAppel>? _abonnementEtats;

  // ------------------------------------------------------------------
  //  API pour le front
  // ------------------------------------------------------------------

  /// Appels à afficher sur l'écran d'appel (la décision était « sonner »).
  Stream<AppelEntrant> get appelsASonner => _aSonner.stream;

  /// Toutes les décisions prises (utile pour déboguer / afficher un toast).
  Stream<(AppelEntrant, Decision)> get decisions => _decisions.stream;

  void demarrer() {
    _abonnementAppels = sip.appelsEntrants.listen(_traiterAppel);
    _abonnementEtats = sip.etatAppels.listen(_suivreEtat);
  }

  Future<void> arreter() async {
    await _abonnementAppels?.cancel();
    await _abonnementEtats?.cancel();
    for (final m in _minuteurs.values) {
      m.cancel();
    }
    _minuteurs.clear();
  }

  Future<String> appeler(String numero) => sip.appeler(numero);
  Future<void> decrocher(String idAppel) => sip.decrocher(idAppel);
  Future<void> raccrocher(String idAppel) => sip.raccrocher(idAppel);

  /// Rejet manuel (bouton « Rejeter » de l'écran d'appel).
  Future<void> rejeter(String idAppel) async {
    final enAttente = _enAttente.remove(idAppel);
    _annulerMinuteur(idAppel);
    await sip.rejeter(idAppel);
    if (enAttente != null) {
      await _journaliser(enAttente.$1, IssueAppel.rejete, 'Rejet manuel');
    }
  }

  // ------------------------------------------------------------------
  //  Traitement d'un appel entrant
  // ------------------------------------------------------------------

  Future<void> _traiterAppel(AppelEntrant appel) async {
    final maintenant = _horloge();
    final ctx = ContexteDecision(
      contacts: contacts.tous,
      regles: regles.tous,
      evenements: calendrier.tous,
      historique: journal.tous,
      maintenant: maintenant,
      dejaEnLigne: _decroches.isNotEmpty,
      bloquesJusqua: Map.unmodifiable(_bloquesJusqua),
    );
    final decision = moteur.decider(appel, ctx);
    _decisions.add((appel, decision));
    await _executer(appel, decision, maintenant);
  }

  Future<void> _executer(
      AppelEntrant appel, Decision decision, DateTime maintenant) async {
    final action = decision.action;

    if (action.bloquerPendant != null) {
      _bloquesJusqua[appel.numero] = maintenant.add(action.bloquerPendant!);
    }

    if (action.envoyerMessageSip && action.messageTexte != null) {
      await sip.envoyerMessage(appel.numero, action.messageTexte!);
    }

    switch (action.type) {
      case TypeAction.sonner:
        _enAttente[appel.idAppel] = (appel, decision);
        _aSonner.add(appel);
        // « Sonner X secondes, puis… » (renvoi sur non-réponse)
        if (action.sonnerPendant != null && action.ensuite != null) {
          _minuteurs[appel.idAppel] = Timer(action.sonnerPendant!, () {
            if (_decroches.contains(appel.idAppel)) return;
            _enAttente.remove(appel.idAppel);
            _executer(
              appel,
              Decision(
                action: action.ensuite!,
                regle: decision.regle,
                explication: '${decision.explication} (sans réponse)',
              ),
              _horloge(),
            );
          });
        }

      case TypeAction.rejeter:
        await sip.rejeter(appel.idAppel,
            code: action.codeSip, raison: action.messageTexte);
        await _journaliser(appel, IssueAppel.rejete, decision.explication);

      case TypeAction.rediriger:
        final cible = action.cible;
        if (cible == null) {
          // Règle mal configurée : on laisse sonner plutôt que de perdre l'appel.
          _enAttente[appel.idAppel] = (appel, decision);
          _aSonner.add(appel);
          return;
        }
        await sip.rediriger(appel.idAppel, cible);
        await _journaliser(appel, IssueAppel.redirige, decision.explication);

      case TypeAction.messagerie:
        await sip.rediriger(appel.idAppel, action.cible ?? cibleMessagerie);
        await _journaliser(appel, IssueAppel.messagerie, decision.explication);
    }
  }

  // ------------------------------------------------------------------
  //  Suivi des appels qui ont sonné (répondu / manqué)
  // ------------------------------------------------------------------

  Future<void> _suivreEtat(EtatAppel etat) async {
    final id = etat.idAppel;
    switch (etat.statut) {
      case StatutAppel.sonne:
        break;
      case StatutAppel.enCours:
        _decroches.add(id);
        _debutCommunication[id] = _horloge();
        _annulerMinuteur(id);
      case StatutAppel.termine:
      case StatutAppel.echec:
        _annulerMinuteur(id);
        final repondu = _decroches.remove(id);
        final debut = _debutCommunication.remove(id);
        final enAttente = _enAttente.remove(id);
        if (enAttente != null) {
          await _journaliser(
            enAttente.$1,
            repondu ? IssueAppel.repondu : IssueAppel.manque,
            enAttente.$2.regle?.nom,
            duree: debut == null ? Duration.zero : _horloge().difference(debut),
          );
        }
    }
  }

  void _annulerMinuteur(String idAppel) {
    _minuteurs.remove(idAppel)?.cancel();
  }

  Future<void> _journaliser(
      AppelEntrant appel, IssueAppel issue, String? regle,
      {Duration duree = Duration.zero}) {
    final contact = moteur.trouverContact(appel.numero, contacts.tous);
    return journal.ajouter(Appel(
      id: appel.idAppel,
      sens: SensAppel.entrant,
      numero: appel.numero,
      nomContact: contact?.nom,
      debut: appel.recuLe,
      duree: duree,
      issue: issue,
      regleAppliquee: regle,
    ));
  }
}
