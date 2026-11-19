import 'dart:async';

import 'package:flutter/material.dart';

import '../models/modeles.dart';
import '../services/services.dart';
import '../widgets/barre_laterale.dart';
import 'contacts_screen.dart';
import 'journal_screen.dart';
import 'messages_screen.dart';
import 'parametres_screen.dart';

/// Structure de l'appli : barre latérale à gauche + page de l'onglet actif.
/// (L'écran d'appel entrant et la barre d'appel en cours sont gérés par
/// CoucheAppels, au-dessus de tout.)
class AccueilScreen extends StatefulWidget {
  const AccueilScreen({super.key});

  @override
  State<AccueilScreen> createState() => _AccueilScreenState();
}

class _AccueilScreenState extends State<AccueilScreen> {
  static const _ongletMessages = 1;

  int _onglet = 0;
  late final StreamSubscription<MessageRecu> _abonnementMessages;

  @override
  void initState() {
    super.initState();
    _abonnementMessages =
        Services.gestionnaire.nouveauxMessages.listen(_messageRecu);
  }

  @override
  void dispose() {
    _abonnementMessages.cancel();
    super.dispose();
  }

  void _changerOnglet(int i) {
    setState(() => _onglet = i);
    if (i == _ongletMessages) Services.messages.marquerTousLus();
  }

  /// Petit bandeau en bas à chaque message reçu.
  void _messageRecu(MessageRecu message) {
    if (!mounted) return;
    if (_onglet == _ongletMessages) {
      // Déjà sur l'onglet : le message s'affiche dans la liste.
      Services.messages.marquerTousLus();
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${nomExpediteur(message)} : ${message.texte}'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Voir',
          onPressed: () => _changerOnglet(_ongletMessages),
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          StreamBuilder<List<MessageRecu>>(
            stream: Services.messages.surveiller(),
            builder: (context, snapshot) {
              final nonLus =
                  (snapshot.data ?? const []).where((m) => !m.lu).length;
              return BarreLaterale(
                onglet: _onglet,
                onChanger: _changerOnglet,
                pastilles: {_ongletMessages: nonLus},
              );
            },
          ),
          Expanded(
            child: SafeArea(
              left: false,
              // IndexedStack garde l'état de chaque onglet.
              child: IndexedStack(
                index: _onglet,
                children: const [
                  JournalScreen(),
                  MessagesScreen(),
                  ContactsScreen(),
                  ParametresScreen(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
