import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';

const serverIp = String.fromEnvironment('SERVER_IP', defaultValue: '127.0.0.1');
const myExt = String.fromEnvironment('EXT', defaultValue: '400');
const myPassword = String.fromEnvironment('PASSWORD', defaultValue: 'changeme');
const targetExt = String.fromEnvironment('TARGET', defaultValue: '500');

void main() => runApp(const MaterialApp(home: PhonePage()));

class PhonePage extends StatefulWidget {
  const PhonePage({super.key});
  @override
  State<PhonePage> createState() => _PhonePageState();
}

class _PhonePageState extends State<PhonePage> implements SipUaHelperListener {
  final SIPUAHelper _helper = SIPUAHelper();
  Call? _call;
  String _status = 'Connexion...';

  @override
  void initState() {
    super.initState();
    _helper.addSipUaHelperListener(this);

    final settings = UaSettings()
      ..webSocketUrl = 'wss://$serverIp:8089/ws'
      ..webSocketSettings.allowBadCertificate = true
      ..uri = 'sip:$myExt@$serverIp'
      ..authorizationUser = myExt
      ..password = myPassword
      ..displayName = myExt
      ..transportType = TransportType.WS
      ..register = true;

    _helper.start(settings);
  }

  // --- Actions ---
  void _makeCall() => _helper.call('sip:$targetExt@$serverIp', voiceOnly: true);
  void _answer() => _call?.answer(_helper.buildCallOptions(true));
  void _hangup() => _call?.hangup();

  // --- Callbacks du helper ---
  @override
  void registrationStateChanged(RegistrationState state) =>
      setState(() => _status = 'Enregistrement : ${state.state?.name}');

  @override
  void transportStateChanged(TransportState state) =>
      setState(() => _status = 'Transport : ${state.state.name}');

  @override
  void callStateChanged(Call call, CallState state) {
    setState(() {
      _call = call;
      _status = 'Appel (${call.direction}) : ${state.state.name}';
      if (state.state == CallStateEnum.ENDED ||
          state.state == CallStateEnum.FAILED) {
        _call = null;
      }
    });
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {}
  @override
  void onNewNotify(Notify ntf) {}
  @override
  void onNewReinvite(ReInvite event) {}

  @override
  Widget build(BuildContext context) {
    final ringing = _call?.direction == 'INCOMING' &&
        _call?.state == CallStateEnum.CALL_INITIATION;

    return Scaffold(
      appBar: AppBar(title: Text('Poste $myExt')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_status),
            const SizedBox(height: 24),
            if (_call == null)
              ElevatedButton(
                  onPressed: _makeCall, child: Text('Appeler $targetExt')),
            if (ringing)
              ElevatedButton(onPressed: _answer, child: const Text('Décrocher')),
            if (_call != null)
              ElevatedButton(onPressed: _hangup, child: const Text('Raccrocher')),
          ],
        ),
      ),
    );
  }
}