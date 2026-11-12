import '../../models/modeles.dart';

/// =====================================================================
///  SipService — UNIQUEMENT la communication SIP.
///
///  Il ne connaît ni les contacts, ni les règles, ni le calendrier :
///  il transmet les appels entrants et exécute les ordres qu'on lui donne.
///
///  Implémentations prévues :
///   - SipServiceUa   : la vraie, avec le paquet sip_ua (à partir de
///                      l'écran Test SIP actuel)
///   - SipServiceFaux : simule des appels pour développer le front dans
///                      Chrome sans serveur
/// =====================================================================
abstract class SipService {
  /// État de la connexion au serveur (déconnecté, connecté…).
  Stream<EtatConnexion> get etatConnexion;

  /// Un événement par appel entrant (INVITE reçu).
  Stream<AppelEntrant> get appelsEntrants;

  /// Changements d'état des appels (sonne, en cours, terminé…).
  Stream<EtatAppel> get etatAppels;

  Future<void> connecter(CompteSip compte);
  Future<void> deconnecter();

  /// Appel sortant. Renvoie l'id de l'appel créé.
  Future<String> appeler(String numero);

  Future<void> decrocher(String idAppel);
  Future<void> raccrocher(String idAppel);

  /// Refuse un appel entrant pas encore décroché.
  /// [code] : 603 Decline, 486 Busy Here, 480 Temporarily Unavailable.
  Future<void> rejeter(String idAppel, {int code = 603, String? raison});

  /// Redirige un appel entrant pas encore décroché
  /// (réponse 302 + en-tête Contact vers [cible], ex. "500" ou "vm400").
  Future<void> rediriger(String idAppel, String cible);

  /// Envoie un message texte SIP (MESSAGE) à [numero].
  Future<void> envoyerMessage(String numero, String texte);
}
