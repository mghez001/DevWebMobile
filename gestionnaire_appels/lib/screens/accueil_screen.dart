import 'package:flutter/material.dart';

import 'clavier_screen.dart';
import 'contacts_screen.dart';
import 'journal_screen.dart';
import 'sip_test_screen.dart';

/// Écran principal : une barre de navigation en bas avec 4 onglets.
class AccueilScreen extends StatefulWidget {
  const AccueilScreen({super.key});

  @override
  State<AccueilScreen> createState() => _AccueilScreenState();
}

class _AccueilScreenState extends State<AccueilScreen> {
  int _ongletActif = 0;

  static const _ecrans = [
    JournalScreen(),
    ContactsScreen(),
    ClavierScreen(),
    SipTestScreen(),
  ];

  static const _titres = ['Journal', 'Contacts', 'Clavier', 'Test SIP'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titres[_ongletActif])),
      // IndexedStack garde l'état de chaque onglet (la connexion SIP reste active)
      body: IndexedStack(index: _ongletActif, children: _ecrans),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _ongletActif,
        onDestinationSelected: (i) => setState(() => _ongletActif = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.history), label: 'Journal'),
          NavigationDestination(icon: Icon(Icons.contacts), label: 'Contacts'),
          NavigationDestination(icon: Icon(Icons.dialpad), label: 'Clavier'),
          NavigationDestination(icon: Icon(Icons.wifi_calling_3), label: 'SIP'),
        ],
      ),
    );
  }
}