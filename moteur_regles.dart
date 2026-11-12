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
  const MoteurDeRegles();

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
  /// TODO(responsable : ______) :
  ///  1. Numéro bloqué temporairement (ctx.bloquesJusqua[numero] est dans
  ///     le futur) → rejeter 603, explication « Bloqué temporairement ».
  ///  2. Contact du groupe `bloque` → rejeter 603, « Liste noire ».
  ///  3. Déjà en ligne (ctx.dejaEnLigne) → rejeter 486 « Déjà en ligne ».
  Decision? reglesSysteme(AppelEntrant appel, ContexteDecision ctx) {
    return null;
  }

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

  /// TODO(responsable : ______) :
  ///  c.prefixes null ou vide → true ; sinon vrai si le numéro normalisé
  ///  commence par l'un des préfixes (ex. démarchage '09', '0162').
  bool prefixeCorrespond(ConditionRegle c, AppelEntrant appel) {
    if (c.prefixes == null || c.prefixes!.isEmpty) return true;
    return false; // TODO
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

  /// TODO(responsable : ______) : « anti-harcèlement ».
  ///  c.nbAppelsMin ou c.nbAppelsFenetre null → true ; sinon vrai si
  ///  (appels passés de ce numéro dans la fenêtre + celui-ci) >= nbAppelsMin.
  bool seuilAppelsCorrespond(
      ConditionRegle c, AppelEntrant appel, ContexteDecision ctx) {
    if (c.nbAppelsMin == null || c.nbAppelsFenetre == null) return true;
    return false; // TODO
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
