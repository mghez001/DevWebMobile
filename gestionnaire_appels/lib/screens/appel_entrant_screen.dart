import 'package:flutter/material.dart';

import '../models/modeles.dart';
import '../services/services.dart';
import '../theme.dart';
import '../widgets/fiche_contact.dart' show groupesAffiches;
import '../widgets/formats.dart';

/// Écran plein, bloquant, affiché quand un appel sonne.
///
/// ⚠️ Cet écran est posé AU-DESSUS du Navigator (voir CoucheAppels) :
/// pas de Tooltip, pas de champ texte, pas de dialogue ici (il n'y a pas
/// d'Overlay à ce niveau).
class AppelEntrantScreen extends StatefulWidget {
  const AppelEntrantScreen({super.key, required this.appel});

  final AppelEntrant appel;

  @override
  State<AppelEntrantScreen> createState() => _AppelEntrantScreenState();
}

class _AppelEntrantScreenState extends State<AppelEntrantScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ondes = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  /// Le panneau « Refuser avec un message » est-il ouvert ?
  bool _choixMessage = false;

  @override
  void dispose() {
    _ondes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appel = widget.appel;
    final masque = appel.estMasque;
    final contact = masque ? null : Services.contactDe(appel.numero);
    final nom = masque
        ? 'Numéro masqué'
        : contact?.nom ?? appel.nomAffiche ?? appel.numero;
    final groupes = contact?.groupes.map((g) => groupesAffiches[g]!.$1).join(' · ');

    return Material(
      color: Couleurs.encre,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  const Text(
                    'APPEL ENTRANT',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Avatar avec des ondes qui s'élargissent
                  SizedBox(
                    width: 190,
                    height: 190,
                    child: AnimatedBuilder(
                      animation: _ondes,
                      builder: (context, _) => Stack(
                        alignment: Alignment.center,
                        children: [
                          for (final decalage in const [0.0, 0.5])
                            _Onde(progression: (_ondes.value + decalage) % 1),
                          Container(
                            width: 112,
                            height: 112,
                            decoration: const BoxDecoration(
                              color: Couleurs.signal,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: masque
                                ? const Icon(Icons.visibility_off_rounded,
                                    color: Colors.white, size: 44)
                                : Text(
                                    initiale(nom),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 46,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      nom,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (!masque && nom != appel.numero)
                    Text(
                      appel.numero,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 16,
                        fontFeatures: chiffresFixes,
                      ),
                    ),
                  if (groupes != null && groupes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Couleurs.encreClair,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(groupes,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ),
                  ],
                  const Spacer(flex: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _GrosBouton(
                        couleur: Couleurs.rouge,
                        icone: Icons.call_end_rounded,
                        libelle: 'Raccrocher',
                        onTap: Services.etat.refuser,
                      ),
                      const SizedBox(width: 72),
                      _GrosBouton(
                        couleur: Couleurs.vert,
                        icone: Icons.call_rounded,
                        libelle: 'Décrocher',
                        onTap: Services.etat.decrocher,
                      ),
                    ],
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
            Positioned(
              left: 24,
              bottom: 24,
              child: _PetitBouton(
                icone: Icons.sms_outlined,
                libelle: 'Message rapide',
                onTap: () => setState(() => _choixMessage = !_choixMessage),
              ),
            ),
            Positioned(
              right: 24,
              bottom: 24,
              child: _PetitBouton(
                icone: Icons.contacts_rounded,
                libelle: 'Contacts',
                // TODO(équipe) : ouvrir / créer la fiche de l'appelant.
                onTap: () {},
              ),
            ),
            if (_choixMessage)
              Positioned(
                left: 16,
                right: 16,
                bottom: 96,
                child: _VoletMessages(
                  onChoisi: Services.etat.refuserAvecMessage,
                  onFermer: () => setState(() => _choixMessage = false),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Onde extends StatelessWidget {
  const _Onde({required this.progression});

  final double progression;

  @override
  Widget build(BuildContext context) {
    final taille = 112 + 78 * progression;
    return Opacity(
      opacity: (1 - progression).clamp(0.0, 1.0),
      child: Container(
        width: taille,
        height: taille,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Couleurs.signal.withValues(alpha: 0.22),
        ),
      ),
    );
  }
}

class _GrosBouton extends StatelessWidget {
  const _GrosBouton({
    required this.couleur,
    required this.icone,
    required this.libelle,
    required this.onTap,
  });

  final Color couleur;
  final IconData icone;
  final String libelle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: couleur,
          shape: const CircleBorder(),
          elevation: 6,
          shadowColor: couleur.withValues(alpha: 0.5),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 78,
              height: 78,
              child: Icon(icone, color: Colors.white, size: 34),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(libelle,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}

class _PetitBouton extends StatelessWidget {
  const _PetitBouton({
    required this.icone,
    required this.libelle,
    required this.onTap,
  });

  final IconData icone;
  final String libelle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Couleurs.encreClair,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 54,
              height: 54,
              child: Icon(icone, color: Colors.white, size: 24),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(libelle,
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }
}

/// Panneau « Refuser avec un message » (pas de dialogue possible ici,
/// l'écran est au-dessus du Navigator).
class _VoletMessages extends StatelessWidget {
  const _VoletMessages({required this.onChoisi, required this.onFermer});

  final void Function(String texte) onChoisi;
  final VoidCallback onFermer;

  static const _messages = [
    'Je suis occupé, je vous rappelle plus tard.',
    'Je suis en réunion, je vous rappelle.',
    'Je ne peux pas répondre, écrivez-moi.',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Text(
                  'Refuser avec un message',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onFermer,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          for (final texte in _messages)
            InkWell(
              onTap: () => onChoisi(texte),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.sms_outlined, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(texte)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
