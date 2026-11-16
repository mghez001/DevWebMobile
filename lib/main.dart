import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';

// Valeurs par défaut (optionnelles) pré-remplies dans le formulaire.
const defaultServerIp =
    String.fromEnvironment('SERVER_IP', defaultValue: '127.0.0.1');

void main() => runApp(const MaterialApp(home: PhonePage()));

class PhonePage extends StatefulWidget {
  const PhonePage({super.key});

  @override
  State<PhonePage> createState() => _PhonePageState();
}

class _PhonePageState extends State<PhonePage> implements SipUaHelperListener {
  final SIPUAHelper _helper = SIPUAHelper();

  // Champs du formulaire
  final _serverCtrl = TextEditingController(text: defaultServerIp);
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscure = true;
  bool _connecting = false;
  bool _registered = false;
  String _status = 'Non connecté';
  String? _error;

  String _server = '';
  String _user = '';
  Call? _call;

  @override
  void initState() {
    super.initState();
    _helper.addSipUaHelperListener(this);
  }

  @override
  void dispose() {
    _helper.removeSipUaHelperListener(this);
    _helper.stop();
    _serverCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  // --- Actions ---
  void _connect() {
    if (!_formKey.currentState!.validate()) return;

    _server = _serverCtrl.text.trim();
    _user = _userCtrl.text.trim();

    final settings = UaSettings()
      ..webSocketUrl = 'wss://$_server:8089/ws'
      ..webSocketSettings.allowBadCertificate = true
      ..uri = 'sip:$_user@$_server'
      ..authorizationUser = _user
      ..password = _passCtrl.text
      ..displayName = _user
      ..transportType = TransportType.WS
      ..register = true;

    setState(() {
      _connecting = true;
      _error = null;
      _status = 'Connexion...';
    });

    _helper.start(settings);
  }

  void _disconnect() {
    _call?.hangup();
    _helper.unregister();
    _helper.stop();
    setState(() {
      _registered = false;
      _connecting = false;
      _call = null;
      _status = 'Non connecté';
    });
  }

  void _makeCall() {
    final target = _targetCtrl.text.trim();
    if (target.isEmpty) return;
    _helper.call('sip:$target@$_server', voiceOnly: true);
  }

  void _answer() => _call?.answer(_helper.buildCallOptions(true));
  void _hangup() => _call?.hangup();

  // --- Callbacks du helper ---
  @override
  void registrationStateChanged(RegistrationState state) {
    setState(() {
      switch (state.state) {
        case RegistrationStateEnum.REGISTERED:
          _registered = true;
          _connecting = false;
          _error = null;
          _status = 'Enregistré en tant que $_user';
          break;
        case RegistrationStateEnum.REGISTRATION_FAILED:
          _registered = false;
          _connecting = false;
          _error = 'Échec de l\'enregistrement : identifiants incorrects ?';
          _helper.stop();
          break;
        case RegistrationStateEnum.UNREGISTERED:
          _registered = false;
          _status = 'Désenregistré';
          break;
        default:
          _status = 'Enregistrement : ${state.state?.name}';
      }
    });
  }

  @override
  void transportStateChanged(TransportState state) {
    setState(() {
      _status = 'Transport : ${state.state.name}';
      if (state.state == TransportStateEnum.DISCONNECTED && !_registered) {
        if (_connecting) {
          _connecting = false;
          _error = 'Impossible de joindre le serveur.';
        }
      }
    });
  }

  @override
  void callStateChanged(Call call, CallState state) {
    setState(() {
      _call = call;
      _status = 'Appel (${call.direction}) : ${state.state.name}';
      if (state.state == CallStateEnum.ENDED ||
          state.state == CallStateEnum.FAILED) {
        _call = null;
        _status = 'Enregistré en tant que $_user';
      }
    });
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {}
  @override
  void onNewNotify(Notify ntf) {}
  @override
  void onNewReinvite(ReInvite event) {}

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_registered ? 'Poste $_user' : 'Connexion SIP'),
        actions: [
          if (_registered)
            IconButton(
              tooltip: 'Se déconnecter',
              icon: const Icon(Icons.logout),
              onPressed: _disconnect,
            ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: _registered ? _buildPhone() : _buildLogin(),
          ),
        ),
      ),
    );
  }

  Widget _buildLogin() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _serverCtrl,
            decoration: const InputDecoration(
              labelText: 'Adresse du serveur',
              prefixIcon: Icon(Icons.dns),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _userCtrl,
            decoration: const InputDecoration(
              labelText: 'Nom d\'utilisateur / extension',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
            autocorrect: false,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              prefixIcon: const Icon(Icons.lock),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Champ requis' : null,
            onFieldSubmitted: (_) => _connect(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _connecting ? null : _connect,
              child: _connecting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Se connecter'),
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          Text(_status, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildPhone() {
    final ringing = _call?.direction == 'INCOMING' &&
        _call?.state == CallStateEnum.CALL_INITIATION;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_status, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        if (_call == null) ...[
          TextField(
            controller: _targetCtrl,
            decoration: const InputDecoration(
              labelText: 'Extension à appeler',
              prefixIcon: Icon(Icons.dialpad),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
            onSubmitted: (_) => _makeCall(),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _makeCall,
            icon: const Icon(Icons.call),
            label: const Text('Appeler'),
          ),
        ],
        if (ringing)
          ElevatedButton.icon(
            onPressed: _answer,
            icon: const Icon(Icons.call),
            label: const Text('Décrocher'),
          ),
        if (_call != null) ...[
          const SizedBox(height: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: _hangup,
            icon: const Icon(Icons.call_end),
            label: const Text('Raccrocher'),
          ),
        ],
      ],
    );
  }
}