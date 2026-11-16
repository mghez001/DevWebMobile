import 'dart:async';

import 'package:flutter/foundation.dart';
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

  /// Messages écrits reçus : (numéro de l'expéditeur, texte).
  final _messagesRecus = StreamController<(String, String)>.broadcast();
  Stream<(String, String)> get messagesRecus => _messagesRecus.stream;

  // -------------------------------------------------------------------
  //  Connexion
  // -------------------------------------------------------------------

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
  Future<void> raccrocher(String idAppel) async {
    _appels[idAppel]?.hangup();
  }

  @override
  Future<void> rejeter(String idAppel, {int code = 603, String? raison}) async {
    _appels[idAppel]?.hangup({
      'status_code': code,
      if (raison != null) 'reason_phrase': raison,
    });
  }

  @override
  Future<void> rediriger(String idAppel, String cible) async {
    _appels[idAppel]?.hangup({
      'status_code': 302,
      'reason_phrase': 'Moved Temporarily',
      'extraHeaders': ['Contact: <${_uri(cible)}>'],
    });
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
    // On ignore les messages que NOUS envoyons, on garde ceux qu'on REÇOIT.
    if (msg.originator.toString().contains('local')) return;

    final dynamic requete = msg.request;
    var texte = '';
    var expediteur = '?';
    try {
      texte = requete.body ?? '';
    } catch (_) {}
    try {
      expediteur = requete.from.uri.user ?? '?';
    } catch (_) {}

    _messagesRecus.add((expediteur, texte));
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
