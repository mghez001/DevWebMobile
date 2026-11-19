import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sip_ua/sip_ua.dart';

import '../../models/modeles.dart';
import 'sip_service.dart';

/// =====================================================================
///  SipServiceUa — vraie implémentation de SipService avec le paquet sip_ua.
///
///  Traduit les événements de sip_ua en objets du projet (AppelEntrant,
///  EtatAppel, EtatConnexion) et exécute les ordres du GestionnaireAppels
///  (décrocher, rejeter, rediriger…).
/// =====================================================================
class SipServiceUa implements SipService, SipUaHelperListener {
  SipServiceUa() {
    _helper.addSipUaHelperListener(this);
    _sonDistant.initialize();
  }

  final SIPUAHelper _helper = SIPUAHelper();

  final _etatConnexion = StreamController<EtatConnexion>.broadcast();
  final _appelsEntrants = StreamController<AppelEntrant>.broadcast();
  final _etatAppels = StreamController<EtatAppel>.broadcast();
  final _messagesRecus = StreamController<MessageRecu>.broadcast();
  int _compteurMessages = 0;

  /// Appels en cours, par identifiant.
  final Map<String, Call> _appels = {};

  /// Appels déjà signalés « en cours » (évite les doublons).
  final Set<String> _enCours = {};

  CompteSip? _compte;
  MediaStream? _micro;

  /// Joue la voix de l'autre personne (nécessaire sur le web).
  final RTCVideoRenderer _sonDistant = RTCVideoRenderer();

  /// Pour renvoyer l'id d'un appel sortant depuis [appeler].
  Completer<String>? _prochainSortant;

  EtatConnexion _etat = EtatConnexion.deconnecte;

  /// Dernier état connu (pratique pour l'UI au démarrage).
  EtatConnexion get etatActuel => _etat;

  // -------------------------------------------------------------------
  //  Streams
  // -------------------------------------------------------------------

  @override
  Stream<EtatConnexion> get etatConnexion => _etatConnexion.stream;

  @override
  Stream<AppelEntrant> get appelsEntrants => _appelsEntrants.stream;

  @override
  Stream<EtatAppel> get etatAppels => _etatAppels.stream;

  @override
  Stream<MessageRecu> get messagesRecus => _messagesRecus.stream;

  // -------------------------------------------------------------------
  //  Connexion
  // -------------------------------------------------------------------

  @override
  CompteSip? get compte => _compte;

  @override
  Future<void> connecter(CompteSip compte) async {
    _compte = compte;
    _changerEtat(EtatConnexion.connexion);

    final reglages =
        UaSettings()
          ..transportType = TransportType.WS
          ..webSocketUrl = compte.urlWebSocket
          ..uri = '${compte.utilisateur}@${compte.serveur}'
          ..host = compte.serveur
          ..authorizationUser = compte.utilisateur
          ..password = compte.motDePasse
          ..displayName = compte.nomAffiche
          ..userAgent = 'Gestionnaire appels'
          ..dtmfMode = DtmfMode.RFC2833
          ..register = true;
    reglages.webSocketSettings.allowBadCertificate = true;

    await _helper.start(reglages);
  }

  @override
  Future<void> deconnecter() async {
    _helper.stop();
    _changerEtat(EtatConnexion.deconnecte);
  }

  // -------------------------------------------------------------------
  //  Appels
  // -------------------------------------------------------------------

  @override
  Future<String> appeler(String numero) async {
    final compte = _compte;
    if (compte == null) throw StateError('Pas connecté au serveur SIP');

    final micro = await _ouvrirMicro();
    // On garde une référence locale : sip_ua signale l'appel (CALL_INITIATION)
    // PENDANT _helper.call, et callStateChanged remet _prochainSortant à null.
    final attente = Completer<String>();
    _prochainSortant = attente;
    final ok = await _helper.call(
      _uri(numero),
      voiceOnly: true,
      mediaStream: micro,
    );
    if (!ok) {
      _prochainSortant = null;
      throw StateError("Impossible d'appeler : pas connecté au serveur");
    }
    return attente.future.timeout(const Duration(seconds: 5));
  }

  @override
  Future<void> decrocher(String idAppel) async {
    final appel = _appels[idAppel];
    if (appel == null) return;
    final micro = await _ouvrirMicro();
    appel.answer(_helper.buildCallOptions(true), mediaStream: micro);
  }

  @override
  Future<void> raccrocher(String idAppel) async => _terminer(idAppel);

  @override
  Future<void> rejeter(String idAppel, {int code = 603, String? raison}) async {
    _terminer(idAppel, {
      'status_code': code,
      if (raison != null) 'reason_phrase': raison,
    });
  }

  @override
  Future<void> rediriger(String idAppel, String cible) async {
    _terminer(idAppel, {
      'status_code': 302,
      'reason_phrase': 'Moved Temporarily',
      'extraHeaders': ['Contact: <${_uri(cible)}>'],
    });
  }

  /// Termine la session SIP (BYE, CANCEL ou réponse 3xx–6xx selon l'état).
  ///
  /// ⚠️ On n'utilise PAS Call.hangup() de sip_ua : il appelle d'abord
  /// peerConnection.getLocalStreams(), une ancienne API retirée de Chrome.
  /// Sur le web, hangup() plantait donc avant d'envoyer le BYE (bug du
  /// bouton « Raccrocher » pendant une communication). Le micro est libéré
  /// à la réception de l'état ENDED (voir callStateChanged).
  void _terminer(String idAppel, [Map<String, dynamic>? options]) {
    final appel = _appels[idAppel];
    if (appel == null) {
      debugPrint('[GA] Fin d\'appel : $idAppel introuvable');
      return;
    }
    try {
      appel.session.terminate(options);
    } catch (e) {
      debugPrint('[GA] Fin d\'appel impossible ($idAppel) : $e');
    }
  }

  @override
  Future<void> envoyerMessage(String numero, String texte) async {
    if (_compte == null) return;
    _helper.sendMessage(_uri(numero), texte);
  }

  // -------------------------------------------------------------------
  //  Événements sip_ua
  // -------------------------------------------------------------------

  @override
  void transportStateChanged(TransportState state) {
    if (state.state == TransportStateEnum.DISCONNECTED &&
        _etat != EtatConnexion.deconnecte) {
      _changerEtat(EtatConnexion.erreur);
    }
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    debugPrint('[GA] SIP enregistrement : ${state.state} ${state.cause ?? ''}');
    switch (state.state) {
      case RegistrationStateEnum.REGISTERED:
        _changerEtat(EtatConnexion.connecte);
      case RegistrationStateEnum.REGISTRATION_FAILED:
        _changerEtat(EtatConnexion.erreur);
      case RegistrationStateEnum.UNREGISTERED:
        _changerEtat(EtatConnexion.deconnecte);
      case RegistrationStateEnum.NONE:
      case null:
        break;
    }
  }

  @override
  void callStateChanged(Call call, CallState state) {
    final id = call.id;
    debugPrint(
      '[GA] SIP callStateChanged ${state.state} id=$id '
      'direction=${call.direction} de=${call.remote_identity}',
    );
    if (id == null) return;

    switch (state.state) {
      case CallStateEnum.CALL_INITIATION:
        _appels[id] = call;
        final entrant = call.direction.toString().toLowerCase().contains(
          'incoming',
        );
        if (entrant) {
          _appelsEntrants.add(
            AppelEntrant(
              idAppel: id,
              numero: normaliserNumero(call.remote_identity ?? ''),
              nomAffiche: call.remote_display_name,
              recuLe: DateTime.now(),
            ),
          );
          _etatAppels.add(EtatAppel(idAppel: id, statut: StatutAppel.sonne));
        } else {
          final attente = _prochainSortant;
          if (attente != null && !attente.isCompleted) attente.complete(id);
          _prochainSortant = null;
        }

      case CallStateEnum.CONFIRMED:
        if (_enCours.add(id)) {
          _etatAppels.add(EtatAppel(idAppel: id, statut: StatutAppel.enCours));
        }

      case CallStateEnum.STREAM:
        if (state.originator.toString().contains('remote')) {
          _sonDistant.srcObject = state.stream;
        }

      case CallStateEnum.ENDED:
      case CallStateEnum.FAILED:
        final echec = state.state == CallStateEnum.FAILED;
        _etatAppels.add(
          EtatAppel(
            idAppel: id,
            statut: echec ? StatutAppel.echec : StatutAppel.termine,
            detail: state.cause?.reason_phrase ?? state.cause?.cause,
          ),
        );
        _appels.remove(id);
        _enCours.remove(id);
        if (_appels.isEmpty) {
          _libererMicro();
          _sonDistant.srcObject = null;
        }

      default:
        break;
    }
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {
    // sip_ua signale aussi les messages qu'on envoie : on ne garde que
    // ceux qui arrivent.
    if (msg.originator != Originator.remote) return;
    final de = msg.message?.remote_identity;
    final texte = (msg.request?.body as String?)?.trim() ?? '';
    debugPrint('[GA] SIP message reçu de ${de?.uri?.user} : $texte');
    if (texte.isEmpty) return;
    _messagesRecus.add(MessageRecu(
      id: 'msg-${DateTime.now().microsecondsSinceEpoch}-${_compteurMessages++}',
      numero: normaliserNumero(de?.uri?.user ?? ''),
      nomAffiche: de?.display_name,
      texte: texte,
      recuLe: DateTime.now(),
    ));
  }

  @override
  void onNewNotify(Notify ntf) {}

  @override
  void onNewReinvite(ReInvite event) {}

  @override
  void onNewInfo(SipInfo info) {}

  // -------------------------------------------------------------------
  //  Outils
  // -------------------------------------------------------------------

  /// "300" → "sip:300@serveur" ; une URI complète est laissée telle quelle.
  String _uri(String numero) {
    if (numero.startsWith('sip:')) return numero;
    return 'sip:$numero@${_compte?.serveur ?? ''}';
  }

  void _changerEtat(EtatConnexion etat) {
    _etat = etat;
    _etatConnexion.add(etat);
  }

  Future<MediaStream> _ouvrirMicro() async {
    return _micro ??= await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });
  }

  void _libererMicro() {
    _micro?.getTracks().forEach((piste) => piste.stop());
    _micro?.dispose();
    _micro = null;
  }
}
