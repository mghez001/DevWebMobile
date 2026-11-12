import '../models/modeles.dart';

/// =====================================================================
///  MoteurDeRegles — DÉCIDE quoi faire d'un appel entrant.
///
///  - Dart pur, sans effet de bord : il ne parle pas SIP, il ne touche
///    à aucune base. On lui donne un appel + un contexte, il renvoie une
///    Decision. → Testable dans test/moteur_regles_test.dart.
///
///  - La structure de [decider] est fixe. Le travail à se répartir est
///    dans les fonctions marquées « TODO » plus bas : chacun complète
///    les siennes, ce qui évite les conflits lors de la mise en commun.
///
///  Règle de convention pour chaque fonction de condition :
///    → si le champ de la condition est null / non utilisé : renvoyer true
///      (la condition ne filtre rien) ;
///    → sinon : renvoyer true seulement si la condition est remplie.
/// =====================================================================
class MoteurDeRegles {
  const MoteurDeRegles({
    this.annonceMasque = 'annonce-masque',
    this.seuilHarcelement = 10,
    this.fenetreHarcelement = const Duration(minutes: 30),
    this.dureeBlocageHarcelement = const Duration(hours: 2),
  });

  /// Extension Asterisk qui joue l'annonce « n'appelez pas en masqué ».
  final String annonceMasque;

  /// Anti-harcèlement : au-delà de [seuilHarcelement] appels sans réponse
  /// pendant [fenetreHarcelement], le numéro est bloqué
  /// pendant [dureeBlocageHarcelement].
  final int seuilHarcelement;
  final Duration fenetreHarcelement;
  final Duration dureeBlocageHarcelement;

  /// Point d'entrée unique.
  Decision decider(AppelEntrant appel, ContexteDecision ctx) {
    // 1. Règles système (toujours actives, non configurables).
    final systeme = reglesSysteme(appel, ctx);
    if (systeme != null) return systeme;

    // 2. Règles de l'utilisateur, de la plus petite priorité à la plus grande.
    final regles = ctx.regles.where((r) => r.active).toList()
      ..sort((a, b) => a.priorite.compareTo(b.priorite));

    for (final regle in regles) {
      if (conditionVerifiee(regle.condition, appel, ctx)) {
        return Decision(
          action: resoudreTexte(regle.action, appel, ctx),
          regle: regle,
          explication: regle.nom,
        );
      }
    }

    // 3. Aucune règle : on laisse sonner.
    return Decision.parDefaut;
  }

  /// Une condition est vraie si TOUS ses critères sont vrais.
  bool conditionVerifiee(
      ConditionRegle c, AppelEntrant appel, ContexteDecision ctx) {
    return appelantCorrespond(c, appel, ctx) &&
        prefixeCorrespond(c, appel) &&
        jourCorrespond(c, ctx) &&
        plageCorrespond(c, ctx) &&
        calendrierCorrespond(c, appel, ctx) &&
        appelRepeteCorrespond(c, appel, ctx) &&
        seuilAppelsCorrespond(c, appel, ctx);
  }

  // ===================================================================
  //  OUTILS (déjà faits)
  // ===================================================================

  /// Contact correspondant au numéro, ou null si inconnu.
  Contact? trouverContact(String numero, List<Contact> contacts) {
    final n = normaliserNumero(numero);
    for (final c in contacts) {
      if (normaliserNumero(c.numero) == n) return c;
    }
    return null;
  }

  /// Événements « occupé » en cours à l'instant du contexte.
  List<EvenementCalendrier> evenementsOccupesEnCours(ContexteDecision ctx) =>
      ctx.evenements
          .where((e) => e.occupe && e.enCours(ctx.maintenant))
          .toList();

  /// Appels entrants passés de ce numéro depuis [depuis].
  List<Appel> appelsDe(String numero, DateTime depuis, ContexteDecision ctx) {
    final n = normaliserNumero(numero);
    return ctx.historique
        .where((a) =>
            a.sens == SensAppel.entrant &&
            normaliserNumero(a.numero) == n &&
            a.debut.isAfter(depuis))
        .toList();
  }

  // ===================================================================
  //  RÈGLES SYSTÈME
  // ===================================================================

  /// Règles prioritaires, testées avant celles de l'utilisateur.
  /// Renvoie null si aucune ne s'applique.
  ///
  /// Ordre (responsable : Mattis) :
  ///  1. Favori              → sonne, quelles que soient les autres règles
  ///  2. Bloqué temporairement → messagerie
  ///  3. Groupe « bloqué »     → messagerie
  ///  4. Numéro masqué        → annonce spéciale « pas en masqué »
  ///  5. Anti-harcèlement     → messagerie + blocage pendant 2 h
  ///
  /// TODO(responsable : ______) : déjà en ligne (ctx.dejaEnLigne)
  ///  → rejeter 486 « Déjà en ligne » (à placer après le point 1).
  Decision? reglesSysteme(AppelEntrant appel, ContexteDecision ctx) {
    final contact = trouverContact(appel.numero, ctx.contacts);

    // 1. Favoris : le téléphone sonne toujours.
    if (contact != null && contact.estDans(GroupeContact.favori)) {
      return Decision(
        action: const ActionRegle(type: TypeAction.sonner),
        explication: 'Favori (${contact.nom}) : sonne toujours',
      );
    }

    // 2. Numéro bloqué temporairement (anti-harcèlement déjà déclenché).
    final finBlocage = ctx.bloquesJusqua[normaliserNumero(appel.numero)] ??
        ctx.bloquesJusqua[appel.numero];
    if (finBlocage != null && ctx.maintenant.isBefore(finBlocage)) {
      return Decision(
        action: const ActionRegle(type: TypeAction.messagerie),
        explication: 'Bloqué temporairement jusqu\'à ${_heure(finBlocage)}',
      );
    }

    // 3. Groupe « bloqué » : direct sur la messagerie.
    if (contact != null && contact.estDans(GroupeContact.bloque)) {
      return Decision(
        action: const ActionRegle(type: TypeAction.messagerie),
        explication: 'Contact bloqué (${contact.nom})',
      );
    }

    // 4. Numéro masqué : annonce vocale dédiée.
    if (appel.estMasque) {
      return Decision(
        action: ActionRegle(
          type: TypeAction.messagerie,
          cible: annonceMasque,
          messageTexte: 'Les appels masqués ne sont pas acceptés',
        ),
        explication: 'Numéro masqué',
      );
    }

    // 5. Anti-harcèlement : trop d'appels sans réponse → blocage.
    final sansReponse = nbAppelsSansReponse(
        appel.numero, ctx.maintenant.subtract(fenetreHarcelement), ctx);
    if (sansReponse + 1 > seuilHarcelement) {
      return Decision(
        action: ActionRegle(
          type: TypeAction.messagerie,
          bloquerPendant: dureeBlocageHarcelement,
        ),
        explication: '${sansReponse + 1} appels sans réponse en '
            '${fenetreHarcelement.inMinutes} min : bloqué '
            '${dureeBlocageHarcelement.inHours} h',
      );
    }

    return null;
  }

  /// Nombre d'appels entrants de ce numéro restés sans réponse depuis
  /// [depuis]. Le compteur repart à zéro dès qu'un appel a été décroché.
  int nbAppelsSansReponse(
      String numero, DateTime depuis, ContexteDecision ctx) {
    final appels = appelsDe(numero, depuis, ctx)
      ..sort((a, b) => a.debut.compareTo(b.debut));
    var compteur = 0;
    for (final a in appels) {
      compteur = a.issue == IssueAppel.repondu ? 0 : compteur + 1;
    }
    return compteur;
  }

  String _heure(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ===================================================================
  //  CONDITIONS — À COMPLÉTER
  // ===================================================================

  /// TODO(responsable : ______) : compléter les cas manquants.
  ///  - tous     → true (déjà fait)
  ///  - inconnus → numéro absent des contacts (et pas masqué)
  ///  - contacts → numéro présent dans les contacts
  ///  - groupe   → contact présent ET dans c.groupe
  ///  - numero   → normaliserNumero(appel.numero) == normaliserNumero(c.numero)
  ///  - masques  → appel.estMasque
  bool appelantCorrespond(
      ConditionRegle c, AppelEntrant appel, ContexteDecision ctx) {
    switch (c.appelant) {
      case TypeAppelant.tous:
        return true;
      case TypeAppelant.inconnus:
      case TypeAppelant.contacts:
      case TypeAppelant.groupe:
      case TypeAppelant.numero:
      case TypeAppelant.masques:
        return false; // TODO
    }
  }

  /// Plages de numéros indésirables (responsable : Mattis).
  ///  c.prefixes null ou vide → true ; sinon vrai si le numéro commence par
  ///  l'un des préfixes. « +33 1 62… », « 0033162… » et « 0162… » sont
  ///  considérés comme identiques.
  ///  Voir [regleNumerosIndesirables] pour créer la règle.
  bool prefixeCorrespond(ConditionRegle c, AppelEntrant appel) {
    final prefixes = c.prefixes;
    if (prefixes == null || prefixes.isEmpty) return true;
    final numero = _formatNational(appel.numero);
    return prefixes
        .map(_formatNational)
        .any((p) => p.isNotEmpty && numero.startsWith(p));
  }

  /// "+33162…" / "0033162…" → "0162…" (le reste passe par normaliserNumero).
  String _formatNational(String brut) {
    final n = normaliserNumero(brut);
    if (n.startsWith('+33')) return '0${n.substring(3)}';
    if (n.startsWith('0033')) return '0${n.substring(4)}';
    return n;
  }

  /// Préfixes réservés au démarchage commercial en France (ARCEP, 2023).
  static const prefixesDemarchage = [
    '0162', '0163', '0270', '0271', '0377', '0378',
    '0424', '0425', '0568', '0569', '0948', '0949',
  ];

  /// Crée la règle « numéros indésirables → messagerie ».
  /// À enregistrer dans le RegleRepository ; l'écran Règles permettra
  /// d'ajouter ou de retirer des préfixes (regle.copyWith(condition: …)).
  static Regle regleNumerosIndesirables(
      {List<String> prefixes = prefixesDemarchage, int priorite = 0}) {
    return Regle(
      id: 'numeros-indesirables',
      nom: 'Numéros indésirables',
      priorite: priorite,
      condition: ConditionRegle(prefixes: prefixes),
      action: const ActionRegle(type: TypeAction.messagerie),
    );
  }

  /// TODO(responsable : ______) :
  ///  c.jours null → true ; sinon vrai si ctx.maintenant.weekday est dans
  ///  c.jours (1 = lundi … 7 = dimanche).
  bool jourCorrespond(ConditionRegle c, ContexteDecision ctx) {
    if (c.jours == null) return true;
    return false; // TODO
  }

  /// TODO(responsable : ______) :
  ///  c.plage null → true ; sinon c.plage!.contient(ctx.maintenant)
  ///  (la gestion de minuit est déjà faite dans PlageHoraire.contient).
  bool plageCorrespond(ConditionRegle c, ContexteDecision ctx) {
    if (c.plage == null) return true;
    return false; // TODO
  }

  /// TODO(responsable : ______) :
  ///  - c.siCalendrierOccupe → vrai seulement si un événement « occupé »
  ///    est en cours (voir evenementsOccupesEnCours).
  ///  - c.siParticipantEvenement → vrai seulement si l'appelant fait partie
  ///    des participants d'un événement en cours.
  ///  - aucun des deux → true.
  bool calendrierCorrespond(
      ConditionRegle c, AppelEntrant appel, ContexteDecision ctx) {
    if (!c.siCalendrierOccupe && !c.siParticipantEvenement) return true;
    return false; // TODO
  }

  /// TODO(responsable : ______) : « appel répété = urgence ».
  ///  c.appelRepeteDans null → true ; sinon vrai si ce numéro a déjà appelé
  ///  depuis (maintenant - c.appelRepeteDans). Utiliser appelsDe(...).
  bool appelRepeteCorrespond(
      ConditionRegle c, AppelEntrant appel, ContexteDecision ctx) {
    if (c.appelRepeteDans == null) return true;
    return false; // TODO
  }

  /// « Anti-harcèlement » configurable dans une règle (responsable : Mattis).
  ///  c.nbAppelsMin ou c.nbAppelsFenetre null → true ; sinon vrai si
  ///  (appels sans réponse de ce numéro dans la fenêtre + celui-ci)
  ///  >= nbAppelsMin. La version par défaut (10 appels / 30 min → 2 h)
  ///  est déjà appliquée dans [reglesSysteme].
  bool seuilAppelsCorrespond(
      ConditionRegle c, AppelEntrant appel, ContexteDecision ctx) {
    final min = c.nbAppelsMin;
    final fenetre = c.nbAppelsFenetre;
    if (min == null || fenetre == null) return true;
    final sansReponse = nbAppelsSansReponse(
        appel.numero, ctx.maintenant.subtract(fenetre), ctx);
    return sansReponse + 1 >= min;
  }

  // ===================================================================
  //  TEXTES
  // ===================================================================

  /// TODO(responsable : ______) : remplacer les variables du message.
  ///  - {fin} → heure de fin de l'événement occupé en cours (format 15:30)
  ///  - {nom} → nom du contact (ou « inconnu »)
  ///  Utiliser action.copyWith(messageTexte: ...). Ne pas oublier
  ///  action.ensuite si on veut aussi le traiter.
  ActionRegle resoudreTexte(
      ActionRegle action, AppelEntrant appel, ContexteDecision ctx) {
    return action; // TODO
  }
}
