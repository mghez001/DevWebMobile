import 'package:flutter/material.dart';

import '../models/modeles.dart';
import '../services/services.dart';
import '../theme.dart';
import 'formats.dart';

/// Comment afficher une entrée du journal.
class PresentationAppel {
  const PresentationAppel({
    required this.icone,
    required this.couleur,
    required this.titre,
    this.motif,
    this.filtre = false,
  });

  final IconData icone;
  final Color couleur;

  /// Ex. « Envoyé sur la messagerie », « Décroché · 3 min 07 ».
  final String titre;

  /// Explication du moteur (ex. « Numéro masqué »), si elle est utile.
  final String? motif;

  /// L'appel a été traité automatiquement par une règle.
  final bool filtre;
}

PresentationAppel presenter(Appel a) {
  final regle = a.regleAppliquee;
  final auto = regle != null && regle != 'Rejet manuel';
  switch (a.issue) {
    case IssueAppel.emis:
      return PresentationAppel(
        icone: Icons.call_made_rounded,
        couleur: Couleurs.texteDoux,
        titre: a.duree > Duration.zero
            ? 'Appel émis · ${formaterDuree(a.duree)}'
            : 'Appel émis · sans réponse',
      );
    case IssueAppel.repondu:
      return PresentationAppel(
        icone: Icons.call_received_rounded,
        couleur: Couleurs.vert,
        titre: 'Décroché · ${formaterDuree(a.duree)}',
        motif: regle,
      );
    case IssueAppel.manque:
      return PresentationAppel(
        icone: Icons.call_missed_rounded,
        couleur: Couleurs.rouge,
        titre: 'Appel manqué',
        motif: regle,
      );
    case IssueAppel.rejete:
      return PresentationAppel(
        icone: Icons.block_rounded,
        couleur: Couleurs.rouge,
        titre: auto ? 'Rejeté automatiquement' : 'Refusé',
        motif: auto ? regle : null,
        filtre: auto,
      );
    case IssueAppel.redirige:
      return PresentationAppel(
        icone: Icons.phone_forwarded_rounded,
        couleur: Couleurs.ambre,
        titre: 'Redirigé automatiquement',
        motif: regle,
        filtre: true,
      );
    case IssueAppel.messagerie:
      return PresentationAppel(
        icone: Icons.voicemail_rounded,
        couleur: Couleurs.bleu,
        titre: 'Envoyé sur la messagerie',
        motif: regle,
        filtre: true,
      );
  }
}

/// Lance un appel et affiche un message en cas d'échec.
Future<void> appelerDepuis(BuildContext context, String numero) async {
  final messager = ScaffoldMessenger.maybeOf(context);
  try {
    await Services.etat.appeler(numero);
  } catch (e) {
    final texte = e is StateError ? e.message : '$e';
    messager?.showSnackBar(SnackBar(content: Text('Appel impossible : $texte')));
  }
}

/// Avatar rond avec l'initiale, couleur stable selon le nom.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.nom, this.taille = 44});

  final String nom;
  final double taille;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(
        color: couleurAvatar(nom),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initiale(nom),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: taille * 0.4,
        ),
      ),
    );
  }
}

/// Une carte du journal d'appels.
class LigneJournal extends StatelessWidget {
  const LigneJournal({
    super.key,
    required this.appel,
    this.afficherNom = true,
    this.onTap,
  });

  final Appel appel;

  /// false dans la fiche d'un contact : on affiche la date à la place du nom.
  final bool afficherNom;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = presenter(appel);
    final masque = estNumeroMasque(appel.numero);
    final contact = masque ? null : Services.contactDe(appel.numero);
    final titre = !afficherNom
        ? libelleJour(appel.debut, DateTime.now())
        : masque
            ? 'Numéro masqué'
            : contact?.nom ?? appel.numero;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Couleurs.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                // Icône de l'issue dans un rond teinté
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: p.couleur.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(p.icone, color: p.couleur, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              titre,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Couleurs.texte,
                              ),
                            ),
                          ),
                          if (contact?.estDans(GroupeContact.favori) ?? false)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(Icons.star_rounded,
                                  size: 16, color: Couleurs.signal),
                            ),
                          if (contact?.estDans(GroupeContact.bloque) ?? false)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(Icons.block_rounded,
                                  size: 15, color: Couleurs.rouge),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p.titre,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: p.couleur,
                          fontFeatures: chiffresFixes,
                        ),
                      ),
                      if (p.motif != null) ...[
                        const SizedBox(height: 6),
                        _Motif(texte: p.motif!, filtre: p.filtre),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      heureMinute(appel.debut),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Couleurs.texteDoux,
                        fontFeatures: chiffresFixes,
                      ),
                    ),
                    if (contact != null && afficherNom)
                      Text(
                        appel.numero,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Couleurs.texteDoux,
                          fontFeatures: chiffresFixes,
                        ),
                      ),
                  ],
                ),
                if (!masque)
                  IconButton(
                    tooltip: 'Rappeler',
                    onPressed: () => appelerDepuis(context, appel.numero),
                    icon: const Icon(Icons.call_rounded,
                        color: Couleurs.encre, size: 20),
                  )
                else
                  const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Petite pastille grise avec l'explication du moteur.
class _Motif extends StatelessWidget {
  const _Motif({required this.texte, required this.filtre});

  final String texte;
  final bool filtre;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Couleurs.fond,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            filtre ? Icons.auto_awesome_rounded : Icons.info_outline_rounded,
            size: 13,
            color: filtre ? Couleurs.signal : Couleurs.texteDoux,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              filtre ? 'Filtré · $texte' : texte,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Couleurs.texteDoux),
            ),
          ),
        ],
      ),
    );
  }
}
