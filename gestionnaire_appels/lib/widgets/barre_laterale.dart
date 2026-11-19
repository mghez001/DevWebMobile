import 'package:flutter/material.dart';

import '../theme.dart';

/// Barre latérale sombre à gauche : logo + onglets APPELS / MESSAGES /
/// CONTACTS / PARAMÈTRES.
class BarreLaterale extends StatelessWidget {
  const BarreLaterale({
    super.key,
    required this.onglet,
    required this.onChanger,
    this.pastilles = const {},
  });

  final int onglet;
  final ValueChanged<int> onChanger;

  /// Nombre affiché en pastille sur un onglet (index → nombre),
  /// ex. {1: 2} = 2 messages non lus.
  final Map<int, int> pastilles;

  static const _onglets = [
    (Icons.call_outlined, Icons.call_rounded, 'APPELS'),
    (Icons.sms_outlined, Icons.sms_rounded, 'MESSAGES'),
    (Icons.people_outline_rounded, Icons.people_rounded, 'CONTACTS'),
    (Icons.tune_outlined, Icons.tune_rounded, 'PARAMÈTRES'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      color: Couleurs.encre,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: 22),
            // Logo
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Couleurs.signal,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.call_split_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(height: 36),
            for (var i = 0; i < _onglets.length; i++)
              _Onglet(
                icone: onglet == i ? _onglets[i].$2 : _onglets[i].$1,
                libelle: _onglets[i].$3,
                actif: onglet == i,
                pastille: pastilles[i] ?? 0,
                onTap: () => onChanger(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _Onglet extends StatelessWidget {
  const _Onglet({
    required this.icone,
    required this.libelle,
    required this.actif,
    required this.onTap,
    this.pastille = 0,
  });

  final IconData icone;
  final String libelle;
  final bool actif;
  final VoidCallback onTap;
  final int pastille;

  @override
  Widget build(BuildContext context) {
    final couleur = actif ? Colors.white : Colors.white54;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Material(
        color: actif ? Couleurs.encreClair : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Stack(
            children: [
              // Petit trait orange à gauche de l'onglet actif
              if (actif)
                Positioned(
                  left: 0,
                  top: 14,
                  bottom: 14,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: Couleurs.signal,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Column(
                    children: [
                      Badge(
                        isLabelVisible: pastille > 0,
                        label: Text('$pastille'),
                        backgroundColor: Couleurs.signal,
                        child: Icon(icone,
                            color: actif ? Couleurs.signal : couleur, size: 24),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          libelle,
                          style: TextStyle(
                            color: couleur,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
