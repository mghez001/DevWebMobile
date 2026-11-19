import 'package:flutter/material.dart';

import '../models/modeles.dart';
import '../services/services.dart';
import '../theme.dart';

/// En-tête des pages : grand titre, sous-titre, bouton SIP à droite.
class EnTetePage extends StatelessWidget {
  const EnTetePage({super.key, required this.titre, this.sousTitre});

  final String titre;
  final String? sousTitre;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: Couleurs.texte,
                  ),
                ),
                if (sousTitre != null) ...[
                  const SizedBox(height: 4),
                  Text(sousTitre!,
                      style: const TextStyle(
                          fontSize: 14, color: Couleurs.texteDoux)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          const BoutonConnexionSip(),
        ],
      ),
    );
  }
}

/// Petit titre de section en capitales espacées.
class TitreSection extends StatelessWidget {
  const TitreSection(this.texte, {super.key});

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Text(
        texte.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: Couleurs.texteDoux,
        ),
      ),
    );
  }
}

/// Pastille de filtre (style « pilule »).
class PuceFiltre extends StatelessWidget {
  const PuceFiltre({
    super.key,
    required this.libelle,
    required this.actif,
    required this.onTap,
    this.icone,
  });

  final String libelle;
  final bool actif;
  final VoidCallback onTap;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final couleurTexte = actif ? Colors.white : Couleurs.texte;
    return Material(
      color: actif ? Couleurs.encre : Couleurs.surface,
      shape: StadiumBorder(
        side: BorderSide(color: actif ? Couleurs.encre : Couleurs.trait),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icone != null) ...[
                Icon(icone, size: 16, color: couleurTexte),
                const SizedBox(width: 6),
              ],
              Text(libelle,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: couleurTexte)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte blanche arrondie (conteneur des sections).
class Carte extends StatelessWidget {
  const Carte({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    // Un Material (et non un Container coloré) : les ListTile et
    // interrupteurs placés dedans ont besoin d'un Material comme parent
    // direct pour dessiner leur fond et leurs effets d'appui.
    return Material(
      color: Couleurs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Couleurs.trait),
      ),
      clipBehavior: Clip.antiAlias,
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}

// =====================================================================
//  Connexion SIP : bouton rond + fenêtre
// =====================================================================

(Color, String) etatConnexionAffiche(EtatConnexion etat) => switch (etat) {
      EtatConnexion.connecte => (Couleurs.vert, 'Connecté'),
      EtatConnexion.connexion => (Couleurs.ambre, 'Connexion…'),
      EtatConnexion.erreur => (Couleurs.rouge, 'Erreur de connexion'),
      EtatConnexion.deconnecte => (Couleurs.texteDoux, 'Déconnecté'),
    };

/// Bouton rond en haut à droite, avec une pastille de couleur selon l'état.
class BoutonConnexionSip extends StatelessWidget {
  const BoutonConnexionSip({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Services.etat,
      builder: (context, _) {
        final (couleur, texte) = etatConnexionAffiche(Services.etat.connexion);
        return Tooltip(
          message: 'Serveur SIP : $texte',
          child: Material(
            color: Couleurs.surface,
            shape: const CircleBorder(side: BorderSide(color: Couleurs.trait)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => ouvrirConnexionSip(context),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(Icons.dns_rounded,
                          color: Couleurs.encre, size: 22),
                    ),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: couleur,
                          shape: BoxShape.circle,
                          border: Border.all(color: Couleurs.surface, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> ouvrirConnexionSip(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _DialogueConnexion(),
  );
}

class _DialogueConnexion extends StatefulWidget {
  const _DialogueConnexion();

  @override
  State<_DialogueConnexion> createState() => _DialogueConnexionState();
}

class _DialogueConnexionState extends State<_DialogueConnexion> {
  // Valeurs mémorisées entre deux ouvertures de la fenêtre.
  static String _ip = Services.compteParDefaut.serveur;
  static String _compte = Services.compteParDefaut.utilisateur;
  static String _motDePasse = Services.compteParDefaut.motDePasse;

  late final _ipCtrl = TextEditingController(text: _ip);
  late final _compteCtrl = TextEditingController(text: _compte);
  late final _mdpCtrl = TextEditingController(text: _motDePasse);

  @override
  void dispose() {
    _ipCtrl.dispose();
    _compteCtrl.dispose();
    _mdpCtrl.dispose();
    super.dispose();
  }

  Future<void> _connecter() {
    _ip = _ipCtrl.text.trim();
    _compte = _compteCtrl.text.trim();
    _motDePasse = _mdpCtrl.text;
    return Services.sip.connecter(CompteSip(
      serveur: _ip,
      utilisateur: _compte,
      motDePasse: _motDePasse,
      nomAffiche: Services.compteParDefaut.nomAffiche,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Services.etat,
      builder: (context, _) {
        final etat = Services.etat.connexion;
        final (couleur, texte) = etatConnexionAffiche(etat);
        final connecte = etat == EtatConnexion.connecte;

        return AlertDialog(
          backgroundColor: Couleurs.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Serveur SIP'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: couleur.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 10, color: couleur),
                      const SizedBox(width: 10),
                      Text(texte,
                          style: TextStyle(
                              color: couleur, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _ipCtrl,
                  enabled: !connecte,
                  decoration: champ('Adresse du serveur', icone: Icons.dns_outlined),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _compteCtrl,
                        enabled: !connecte,
                        decoration:
                            champ('Compte', icone: Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _mdpCtrl,
                        enabled: !connecte,
                        obscureText: true,
                        decoration:
                            champ('Mot de passe', icone: Icons.lock_outline_rounded),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
            if (connecte)
              FilledButton(
                onPressed: Services.sip.deconnecter,
                style: FilledButton.styleFrom(backgroundColor: Couleurs.rouge),
                child: const Text('Se déconnecter'),
              )
            else
              FilledButton(
                onPressed: etat == EtatConnexion.connexion ? null : _connecter,
                child: const Text('Se connecter'),
              ),
          ],
        );
      },
    );
  }
}
