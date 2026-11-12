import 'package:flutter/material.dart';

/// Clavier numérique pour composer un numéro.
/// StatefulWidget car le numéro tapé change.
class ClavierScreen extends StatefulWidget {
  const ClavierScreen({super.key});

  @override
  State<ClavierScreen> createState() => _ClavierScreenState();
}

class _ClavierScreenState extends State<ClavierScreen> {
  String _numero = '';

  // Les touches rangées par ligne
  static const _lignes = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['*', '0', '#'],
  ];

  static const double _tailleTouche = 72;

  void _ajouter(String chiffre) => setState(() => _numero += chiffre);

  void _effacer() {
    if (_numero.isEmpty) return;
    setState(() => _numero = _numero.substring(0, _numero.length - 1));
  }

  void _appeler() {
    if (_numero.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Appel du $_numero…')),
    );
  }

  /// Une touche ronde de taille fixe.
  Widget _touche(String t) {
    return SizedBox(
      width: _tailleTouche,
      height: _tailleTouche,
      child: OutlinedButton(
        onPressed: () => _ajouter(t),
        style: OutlinedButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
        ),
        child: Text(t, style: const TextStyle(fontSize: 26)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      // Le clavier ne dépasse jamais 360 px de large, même sur grand écran
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          children: [
            // Numéro affiché en haut (prend la place restante)
            Expanded(
              child: Center(
                child: Text(
                  _numero,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
            ),
            // Les 4 lignes de touches
            for (final ligne in _lignes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [for (final t in ligne) _touche(t)],
                ),
              ),
            // Boutons Appeler / Effacer
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(width: _tailleTouche), // case vide à gauche
                  SizedBox(
                    width: _tailleTouche,
                    height: _tailleTouche,
                    child: FloatingActionButton(
                      onPressed: _appeler,
                      backgroundColor: Colors.green,
                      shape: const CircleBorder(),
                      child: const Icon(Icons.call, color: Colors.white, size: 32),
                    ),
                  ),
                  SizedBox(
                    width: _tailleTouche,
                    child: IconButton(
                      onPressed: _effacer,
                      icon: const Icon(Icons.backspace_outlined),
                      iconSize: 28,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}