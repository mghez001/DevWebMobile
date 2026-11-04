import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sip_ua/sip_ua.dart';

/// Écran de test : se connecter au serveur Asterisk et appeler Linphone.
class SipTestScreen extends StatefulWidget {
  const SipTestScreen({super.key});

  @override
  State<SipTestScreen> createState() => _SipTestScreenState();
}

class _SipTestScreenState extends State<SipTestScreen>
    implements SipUaHelperListener {
  final SIPUAHelper _sip = SIPUAHelper();

  // ⚠️ Mets ici l'IP de ton PC (commande ipconfig)
  final _ipServeur = TextEditingController(text: '127.0.0.1');
  final _utilisateur = TextEditingController(text: '400');
  final _motDePasse = TextEditingController(text: '400');
  final _destination = TextEditingController(text: '300');

  final RTCVideoRenderer _sonDistant = RTCVideoRenderer(); // joue la voix reçue
  MediaStream? _micro;
  Call? _appel;

  bool _connecte = false;
  bool _appelEntrant = false;
  String _etat = 'Déconnecté';
  final List<String> _journal = [];

  @override
  void initState() {
    super.initState();
    _sonDistant.initialize();
    _sip.addSipUaHelperListener(this);
  }

  @override
  void dispose() {
    _sip.removeSipUaHelperListener(this);
    _sip.stop();
    _libererMicro();
    _sonDistant.dispose();
    for (final c in [_ipServeur, _utilisateur, _motDePasse, _destination]) {
      c.dispose();
    }
    super.dispose();
  }

  void _log(String texte) {
    if (!mounted) return;
    final t = DateTime.now();
    String deux(int n) => n.toString().padLeft(2, '0');
    setState(() => _journal.insert(
        0, '${deux(t.hour)}:${deux(t.minute)}:${deux(t.second)}  $texte'));
  }

  // ---------------- Actions ----------------

  Future<void> _connecter() async {
    final ip = _ipServeur.text.trim();
    final user = _utilisateur.text.trim();

    final reglages = UaSettings()
      ..transportType = TransportType.WS
      ..webSocketUrl = 'ws://$ip:8088/ws'
      ..uri = '$user@$ip'
      ..host = ip
      ..authorizationUser = user
      ..password = _motDePasse.text
      ..displayName = 'Appli Flutter'
      ..userAgent = 'Gestionnaire appels'
      ..dtmfMode = DtmfMode.RFC2833
      ..register = true;
    reglages.webSocketSettings.allowBadCertificate = true;

    _log('Connexion à ws://$ip:8088/ws avec le compte $user…');
    await _sip.start(reglages);
  }

  void _deconnecter() {
    _sip.stop();
    setState(() {
      _connecte = false;
      _etat = 'Déconnecté';
    });
    _log('Déconnecté');
  }

  Future<MediaStream> _ouvrirMicro() async {
    return _micro ??= await navigator.mediaDevices
        .getUserMedia({'audio': true, 'video': false});
  }

  void _libererMicro() {
    _micro?.getTracks().forEach((piste) => piste.stop());
    _micro?.dispose();
    _micro = null;
  }

  Future<void> _appeler() async {
    final cible = 'sip:${_destination.text.trim()}@${_ipServeur.text.trim()}';
    try {
      final micro = await _ouvrirMicro();
      final ok = await _sip.call(cible, voiceOnly: true, mediaStream: micro);
      if (!ok) _log("Impossible d'appeler : pas connecté au serveur");
    } catch (e) {
      _log('Erreur micro : $e');
    }
  }

  Future<void> _decrocher() async {
    final appel = _appel;
    if (appel == null) return;
    try {
      final micro = await _ouvrirMicro();
      appel.answer(_sip.buildCallOptions(true), mediaStream: micro);
    } catch (e) {
      _log('Erreur micro : $e');
    }
  }

  /// Rejet avec un code SIP 603 et une raison : c'est ce que fera
  /// plus tard le filtrage automatique des inconnus.
  void _rejeter() => _appel?.hangup(
      {'status_code': 603, 'reason_phrase': 'Laissez-moi un message'});

  void _raccrocher() => _appel?.hangup();

  // ---------------- Événements SIP ----------------

  @override
  void transportStateChanged(TransportState state) {
    _log('Transport : ${state.state.name}');
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    final ok = state.state == RegistrationStateEnum.REGISTERED;
    setState(() {
      _connecte = ok;
      _etat = ok ? 'Connecté ✅' : 'Non connecté (${state.state?.name})';
    });
    _log('Enregistrement : ${state.state?.name}'
        '${state.cause != null ? ' – ${state.cause}' : ''}');
  }

  @override
  void callStateChanged(Call call, CallState state) {
    switch (state.state) {
      case CallStateEnum.CALL_INITIATION:
        final entrant =
            call.direction.toString().toLowerCase().contains('incoming');
        setState(() {
          _appel = call;
          _appelEntrant = entrant;
        });
        _log(entrant
            ? 'Appel entrant de ${call.remote_identity} 📞'
            : 'Appel vers ${call.remote_identity}…');
      case CallStateEnum.PROGRESS:
        _log('Ça sonne…');
      case CallStateEnum.CONFIRMED:
        setState(() => _appelEntrant = false);
        _log('En communication 🎧');
      case CallStateEnum.STREAM:
        if (state.originator.toString().contains('remote')) {
          _sonDistant.srcObject = state.stream; // on entend l'autre
        }
      case CallStateEnum.ENDED:
      case CallStateEnum.FAILED:
        _log(state.state == CallStateEnum.FAILED
            ? 'Échec : ${state.cause?.reason_phrase ?? state.cause?.cause}'
            : 'Appel terminé');
        _libererMicro();
        _sonDistant.srcObject = null;
        setState(() {
          _appel = null;
          _appelEntrant = false;
        });
      default:
        break;
    }
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {
    _log('Message reçu : ${msg.request?.body}');
  }

  @override
  void onNewNotify(Notify ntf) {}

  @override
  void onNewReinvite(ReInvite event) {}

  @override
  void onNewInfo(SipInfo info) {}

  // ---------------- Interface ----------------

  @override
  Widget build(BuildContext context) {
    final titre = Theme.of(context).textTheme.titleMedium;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('1. Connexion au serveur', style: titre),
            const SizedBox(height: 8),
            TextField(
              controller: _ipServeur,
              decoration: const InputDecoration(
                labelText: 'IP du serveur Asterisk',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _utilisateur,
                    decoration: const InputDecoration(
                      labelText: 'Compte',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _motDePasse,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  onPressed: _connecte ? _deconnecter : _connecter,
                  child: Text(_connecte ? 'Se déconnecter' : 'Se connecter'),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(_etat)),
              ],
            ),
            const Divider(height: 32),
            Text('2. Appel', style: titre),
            const SizedBox(height: 8),
            TextField(
              controller: _destination,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Numéro (300 = Linphone, 100 = test écho)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            if (_appelEntrant)
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _decrocher,
                    style: FilledButton.styleFrom(backgroundColor: Colors.green),
                    icon: const Icon(Icons.call),
                    label: const Text('Décrocher'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _rejeter,
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    icon: const Icon(Icons.call_end),
                    label: const Text('Rejeter'),
                  ),
                ],
              )
            else if (_appel != null)
              FilledButton.icon(
                onPressed: _raccrocher,
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                icon: const Icon(Icons.call_end),
                label: const Text('Raccrocher'),
              )
            else
              FilledButton.icon(
                onPressed: _connecte ? _appeler : null,
                icon: const Icon(Icons.call),
                label: const Text('Appeler'),
              ),
            const Divider(height: 32),
            Text('Journal', style: titre),
            const SizedBox(height: 8),
            for (final ligne in _journal)
              Text(ligne,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ],
        ),
      ),
    );
  }
}