import 'package:flutter/material.dart';

import '../widgets/barre_laterale.dart';
import 'contacts_screen.dart';
import 'journal_screen.dart';
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
  int _onglet = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          BarreLaterale(
            onglet: _onglet,
            onChanger: (i) => setState(() => _onglet = i),
          ),
          Expanded(
            child: SafeArea(
              left: false,
              // IndexedStack garde l'état de chaque onglet.
              child: IndexedStack(
                index: _onglet,
                children: const [
                  JournalScreen(),
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
