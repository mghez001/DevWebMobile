import 'package:flutter/material.dart';

import '../theme.dart';

/// Clavier numérique, ouvert en panneau depuis le bouton rond de l'accueil.
class ClavierScreen extends StatefulWidget {
  const ClavierScreen({super.key, required this.onAppeler});

  /// Appelé avec le numéro composé quand on appuie sur le bouton vert.
  final ValueChanged<String> onAppeler;

  @override
  State<ClavierScreen> createState() => _ClavierScreenState();
}

class _ClavierScreenState extends State<ClavierScreen> {
  String _numero = '';

  static const _touches = [
    ('1', ''), ('2', 'ABC'), ('3', 'DEF'),
    ('4', 'GHI'), ('5', 'JKL'), ('6', 'MNO'),
    ('7', 'PQRS'), ('8', 'TUV'), ('9', 'WXYZ'),
    ('*', ''), ('0', '+'), ('#', ''),
  ];

  void _ajouter(String c) => setState(() => _numero += c);

  void _effacer() {
    if (_numero.isEmpty) return;
    setState(() => _numero = _numero.substring(0, _numero.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Poignée
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Couleurs.trait,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      _numero.isEmpty ? 'Composer un numéro' : _numero,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: _numero.isEmpty
                          ? const TextStyle(
                              fontSize: 18, color: Couleurs.texteDoux)
                          : const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                              color: Couleurs.texte,
                              fontFeatures: chiffresFixes,
                            ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: _numero.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Effacer',
                            onPressed: _effacer,
                            icon: const Icon(Icons.backspace_outlined,
                                color: Couleurs.texteDoux),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  for (final (chiffre, lettres) in _touches)
                    _Touche(
                      chiffre: chiffre,
                      lettres: lettres,
                      onTap: () => _ajouter(chiffre),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Material(
              color: Couleurs.vert,
              shape: const CircleBorder(),
              elevation: 3,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _numero.isEmpty ? null : () => widget.onAppeler(_numero),
                child: const SizedBox(
                  width: 68,
                  height: 68,
                  child: Icon(Icons.call_rounded, color: Colors.white, size: 30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Touche extends StatelessWidget {
  const _Touche({
    required this.chiffre,
    required this.lettres,
    required this.onTap,
  });

  final String chiffre;
  final String lettres;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Couleurs.fond,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              chiffre,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Couleurs.texte,
              ),
            ),
            if (lettres.isNotEmpty)
              Text(
                lettres,
                style: const TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.5,
                  color: Couleurs.texteDoux,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
