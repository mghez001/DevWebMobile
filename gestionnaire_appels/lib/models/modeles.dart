/// =====================================================================
///  MODÈLES COMMUNS — le « contrat » partagé par toute l'équipe.
///
///  ⚠️ Ne modifiez pas ce fichier sans prévenir les autres : tout le monde
///  manipule ces mêmes objets (moteur de règles, services, écrans).
///  Ce fichier est en Dart pur (aucun import Flutter) pour que le moteur
///  de règles soit testable avec de simples tests unitaires.
/// =====================================================================
library;

// =====================================================================
//  OUTILS
// =====================================================================

/// Met un numéro sous une forme comparable.
/// "sip:300@127.0.0.1" → "300" ; "06 12-34.56" → "061234 56" sans séparateurs.
String normaliserNumero(String brut) {
  var n = brut.trim().toLowerCase();
  if (n.startsWith('sip:')) n = n.substring(4);
  final arobase = n.indexOf('@');
  if (arobase != -1) n = n.substring(0, arobase);
  return n.replaceAll(RegExp(r'[\s.\-()]'), '');
}

// =====================================================================
//  CONTACTS
// =====================================================================

enum GroupeContact { favori, pro, perso, bloque }

class Contact {
  final String id;
  final String nom;

  /// Numéro SIP du contact, ex. "300" (toujours passer par [normaliserNumero]).
  final String numero;
  final Set<GroupeContact> groupes;

  const Contact({
    required this.id,
    required this.nom,
    required this.numero,
    this.groupes = const {},
  });

  bool estDans(GroupeContact groupe) => groupes.contains(groupe);

  Contact copyWith({String? nom, String? numero, Set<GroupeContact>? groupes}) {
    return Contact(
      id: id,
      nom: nom ?? this.nom,
      numero: numero ?? this.numero,
      groupes: groupes ?? this.groupes,
    );
  }

  @override
  String toString() => 'Contact($nom, $numero, $groupes)';
}

// =====================================================================
//  APPELS
// =====================================================================

/// Un appel qui arrive, tel que le SipService le transmet.
class AppelEntrant {
  /// Identifiant unique de l'appel (fourni par le SipService).
  final String idAppel;

  /// Numéro de l'appelant, déjà normalisé (ex. "300").
  final String numero;
  final String? nomAffiche;
  final DateTime recuLe;

  const AppelEntrant({
    required this.idAppel,
    required this.numero,
    this.nomAffiche,
    required this.recuLe,
  });

  /// Numéro masqué ou anonyme.
  bool get estMasque =>
      numero.isEmpty || numero == 'anonymous' || numero == 'unknown';

  @override
  String toString() => 'AppelEntrant($numero, $nomAffiche)';
}

enum SensAppel { entrant, sortant }

/// Comment l'appel s'est terminé.
enum IssueAppel { repondu, manque, rejete, redirige, messagerie, emis }

/// Une ligne du journal d'appels.
class Appel {
  final String id;
  final SensAppel sens;
  final String numero;

  /// Nom du contact, null si l'appelant est inconnu.
  final String? nomContact;
  final DateTime debut;
  final Duration duree;
  final IssueAppel issue;

  /// Nom de la règle qui a décidé (null = sonnerie normale).
  final String? regleAppliquee;

  const Appel({
    required this.id,
    required this.sens,
    required this.numero,
    this.nomContact,
    required this.debut,
    this.duree = Duration.zero,
    required this.issue,
    this.regleAppliquee,
  });

  @override
  String toString() => 'Appel($sens, $numero, $issue, $regleAppliquee)';
}

// =====================================================================
//  CONNEXION SIP
// =====================================================================

enum EtatConnexion { deconnecte, connexion, connecte, erreur }

enum StatutAppel { sonne, enCours, termine, echec }

/// Changement d'état d'un appel (émis par le SipService).
class EtatAppel {
  final String idAppel;
  final StatutAppel statut;
  final String? detail;

  const EtatAppel({required this.idAppel, required this.statut, this.detail});
}

class CompteSip {
  final String serveur; // ex. "127.0.0.1"
  final String utilisateur; // ex. "400"
  final String motDePasse;
  final String nomAffiche;
  final int portWebSocket;

  const CompteSip({
    required this.serveur,
    required this.utilisateur,
    required this.motDePasse,
    this.nomAffiche = 'Gestionnaire appels',
    this.portWebSocket = 8088,
  });

  String get urlWebSocket => 'ws://$serveur:$portWebSocket/ws';
}

// =====================================================================
//  HORAIRES
// =====================================================================

class Heure {
  final int heures;
  final int minutes;

  const Heure(this.heures, this.minutes);

  int get enMinutes => heures * 60 + minutes;

  @override
  String toString() =>
      '${heures.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
}

/// Plage horaire quotidienne, ex. 22:00 → 08:00 (peut passer minuit).
class PlageHoraire {
  final Heure debut;
  final Heure fin;

  const PlageHoraire(this.debut, this.fin);

  /// Vrai si [moment] est dans la plage. Gère le passage de minuit.
  bool contient(DateTime moment) {
    final m = moment.hour * 60 + moment.minute;
    final d = debut.enMinutes;
    final f = fin.enMinutes;
    return d <= f ? (m >= d && m < f) : (m >= d || m < f);
  }

  @override
  String toString() => '$debut → $fin';
}

// =====================================================================
//  CALENDRIER
// =====================================================================

class EvenementCalendrier {
  final String id;
  final String titre;
  final DateTime debut;
  final DateTime fin;

  /// Si vrai, déclenche les règles « siCalendrierOccupe ».
  final bool occupe;

  /// Numéros des contacts qui participent (règle « réunion avec un contact »).
  final Set<String> participants;

  const EvenementCalendrier({
    required this.id,
    required this.titre,
    required this.debut,
    required this.fin,
    this.occupe = true,
    this.participants = const {},
  });

  bool enCours(DateTime moment) =>
      !moment.isBefore(debut) && moment.isBefore(fin);
}

// =====================================================================
//  RÈGLES
// =====================================================================

/// Qui est concerné par la règle.
enum TypeAppelant {
  tous,
  inconnus, // numéro absent des contacts
  contacts, // n'importe quel contact connu
  groupe, // contacts d'un groupe précis (voir ConditionRegle.groupe)
  numero, // un numéro précis (voir ConditionRegle.numero)
  masques, // numéro masqué / anonyme
}

/// Conditions d'une règle. Toutes les conditions renseignées doivent être
/// vraies (ET logique). Une condition laissée à null est ignorée.
class ConditionRegle {
  final TypeAppelant appelant;
  final GroupeContact? groupe;
  final String? numero;

  /// Le numéro commence par l'un de ces préfixes (ex. ['09', '0162']).
  final List<String>? prefixes;

  /// Jours concernés : DateTime.monday (1) … DateTime.sunday (7).
  final Set<int>? jours;

  /// Plage horaire concernée.
  final PlageHoraire? plage;

  /// Seulement pendant un événement « occupé » du calendrier.
  final bool siCalendrierOccupe;

  /// Seulement si l'appelant participe à l'événement en cours.
  final bool siParticipantEvenement;

  /// Vrai si ce même numéro a DÉJÀ appelé pendant cette durée
  /// (ex. 3 min → « appel répété = urgence »).
  final Duration? appelRepeteDans;

  /// Vrai si ce numéro a appelé au moins [nbAppelsMin] fois
  /// pendant [nbAppelsFenetre] (anti-harcèlement).
  final int? nbAppelsMin;
  final Duration? nbAppelsFenetre;

  const ConditionRegle({
    this.appelant = TypeAppelant.tous,
    this.groupe,
    this.numero,
    this.prefixes,
    this.jours,
    this.plage,
    this.siCalendrierOccupe = false,
    this.siParticipantEvenement = false,
    this.appelRepeteDans,
    this.nbAppelsMin,
    this.nbAppelsFenetre,
  });
}

enum TypeAction {
  sonner, // laisser sonner normalement
  rejeter, // refuser (code SIP + raison)
  rediriger, // renvoyer vers ActionRegle.cible
  messagerie, // renvoyer vers la messagerie vocale Asterisk
}

class ActionRegle {
  final TypeAction type;

  /// Numéro de redirection (pour [TypeAction.rediriger]).
  final String? cible;

  /// Texte renvoyé à l'appelant (raison du rejet, message SIP…).
  /// Variables possibles : {fin} = heure de fin de l'événement en cours,
  /// {nom} = nom du contact.
  final String? messageTexte;

  /// Envoie aussi [messageTexte] en message SIP (MESSAGE) à l'appelant.
  final bool envoyerMessageSip;

  /// Code SIP pour un rejet : 603 Decline, 486 Busy Here, 480 Indisponible.
  final int codeSip;

  /// « Sonner X secondes, puis [ensuite] » (renvoi sur non-réponse).
  final Duration? sonnerPendant;
  final ActionRegle? ensuite;

  /// Bloque aussi ce numéro pendant cette durée (blocage temporaire).
  final Duration? bloquerPendant;

  const ActionRegle({
    required this.type,
    this.cible,
    this.messageTexte,
    this.envoyerMessageSip = false,
    this.codeSip = 603,
    this.sonnerPendant,
    this.ensuite,
    this.bloquerPendant,
  });

  ActionRegle copyWith({String? cible, String? messageTexte}) {
    return ActionRegle(
      type: type,
      cible: cible ?? this.cible,
      messageTexte: messageTexte ?? this.messageTexte,
      envoyerMessageSip: envoyerMessageSip,
      codeSip: codeSip,
      sonnerPendant: sonnerPendant,
      ensuite: ensuite,
      bloquerPendant: bloquerPendant,
    );
  }
}

class Regle {
  final String id;
  final String nom;

  /// La plus PETITE priorité est testée en premier.
  final int priorite;
  final bool active;
  final ConditionRegle condition;
  final ActionRegle action;

  const Regle({
    required this.id,
    required this.nom,
    required this.priorite,
    this.active = true,
    required this.condition,
    required this.action,
  });

  Regle copyWith({String? nom, int? priorite, bool? active,
      ConditionRegle? condition, ActionRegle? action}) {
    return Regle(
      id: id,
      nom: nom ?? this.nom,
      priorite: priorite ?? this.priorite,
      active: active ?? this.active,
      condition: condition ?? this.condition,
      action: action ?? this.action,
    );
  }

  @override
  String toString() => 'Regle($priorite, $nom)';
}

// =====================================================================
//  DÉCISION DU MOTEUR
// =====================================================================

/// Tout ce dont le moteur a besoin pour décider (photo de l'instant T).
class ContexteDecision {
  final List<Contact> contacts;
  final List<Regle> regles;
  final List<EvenementCalendrier> evenements;

  /// Journal des appels passés (pour les règles « appel répété »,
  /// « anti-harcèlement »…).
  final List<Appel> historique;
  final DateTime maintenant;

  /// Un appel est déjà en cours.
  final bool dejaEnLigne;

  /// Numéros bloqués temporairement → jusqu'à quand.
  final Map<String, DateTime> bloquesJusqua;

  const ContexteDecision({
    this.contacts = const [],
    this.regles = const [],
    this.evenements = const [],
    this.historique = const [],
    required this.maintenant,
    this.dejaEnLigne = false,
    this.bloquesJusqua = const {},
  });
}

/// Ce que le moteur a décidé.
class Decision {
  final ActionRegle action;

  /// Règle utilisateur appliquée (null = règle système ou défaut).
  final Regle? regle;

  /// Explication lisible, affichée dans le journal (ex. « Inconnu la nuit »).
  final String explication;

  const Decision({
    required this.action,
    this.regle,
    required this.explication,
  });

  static const parDefaut = Decision(
    action: ActionRegle(type: TypeAction.sonner),
    explication: 'Aucune règle : sonnerie normale',
  );

  @override
  String toString() => 'Decision(${action.type}, $explication)';
}
