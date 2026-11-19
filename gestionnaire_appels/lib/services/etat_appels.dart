import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../models/modeles.dart';
import 'gestionnaire_appels.dart';
import 'sip/sip_service.dart';

enum PhaseAppel { appelSortant, enCommunication }

/// L'appel en cours (entrant décroché ou sortant).
class AppelActif {
  AppelActif({
    required this.idAppel,
    required this.numero,
    required this.entrant,
    required this.phase,
    this.debutCommunication,
  });

  final String idAppel;
  final String numero;
  final bool entrant;
  PhaseAppel phase;
  DateTime? debutCommunication;
}

/// =====================================================================
///  EtatAppels — ce que l'interface doit afficher à un instant donné :
///  un appel qui sonne (écran plein), un appel en cours (barre du haut),
///  l'état de la connexion SIP (bouton rond).
///
///  Les écrans l'écoutent avec ListenableBuilder(listenable: Services.etat).
/// =====================================================================
class EtatAppels extends ChangeNotifier {
  EtatAppels(this._gestionnaire, this._sip) {
    _abonnements.addAll([
      _gestionnaire.appelsASonner.listen((appel) {
        appelQuiSonne = appel;
        notifyListeners();
      }),
      _sip.etatAppels.listen(_suivre),
      _sip.etatConnexion.listen((etat) {
        connexion = etat;
        notifyListeners();
      }),
    ]);
  }

  final GestionnaireAppels _gestionnaire;
  final SipService _sip;
  final List<StreamSubscription<dynamic>> _abonnements = [];

  /// Appel entrant qui sonne (le moteur a décidé « sonner »).
  AppelEntrant? appelQuiSonne;

  /// Appel en cours (sortant qui sonne, ou communication établie).
  AppelActif? appelActif;

  EtatConnexion connexion = EtatConnexion.deconnecte;

  // ------------------------------------------------------------------
  //  Actions
  // ------------------------------------------------------------------

  Future<void> appeler(String numero) async {
    final n = normaliserNumero(numero);
    if (n.isEmpty) return;
    final id = await _gestionnaire.appeler(n);
    appelActif = AppelActif(
      idAppel: id,
      numero: n,
      entrant: false,
      phase: PhaseAppel.appelSortant,
    );
    notifyListeners();
  }

  Future<void> decrocher() async {
    final appel = appelQuiSonne;
    if (appel != null) await _gestionnaire.decrocher(appel.idAppel);
  }

  /// Bouton rouge de l'écran d'appel entrant.
  Future<void> refuser() async {
    final appel = appelQuiSonne;
    if (appel == null) return;
    appelQuiSonne = null;
    notifyListeners();
    await _gestionnaire.rejeter(appel.idAppel);
  }

  /// Bouton « Raccrocher » de la barre d'appel en cours.
  Future<void> raccrocher() async {
    final appel = appelActif;
    if (appel != null) await _gestionnaire.raccrocher(appel.idAppel);
  }

  // ------------------------------------------------------------------
  //  Suivi des états SIP
  // ------------------------------------------------------------------

  void _suivre(EtatAppel etat) {
    final id = etat.idAppel;
    switch (etat.statut) {
      case StatutAppel.sonne:
        return;
      case StatutAppel.enCours:
        final sonne = appelQuiSonne;
        if (sonne != null && sonne.idAppel == id) {
          appelActif = AppelActif(
            idAppel: id,
            numero: sonne.numero,
            entrant: true,
            phase: PhaseAppel.enCommunication,
            debutCommunication: DateTime.now(),
          );
          appelQuiSonne = null;
        } else if (appelActif?.idAppel == id) {
          appelActif!
            ..phase = PhaseAppel.enCommunication
            ..debutCommunication = DateTime.now();
        }
      case StatutAppel.termine:
      case StatutAppel.echec:
        if (appelQuiSonne?.idAppel == id) appelQuiSonne = null;
        if (appelActif?.idAppel == id) appelActif = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    for (final a in _abonnements) {
      a.cancel();
    }
    super.dispose();
  }
}
