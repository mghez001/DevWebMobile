import 'package:flutter/material.dart';

import '../models/modeles.dart';
import '../services/services.dart';
import '../theme.dart';
import '../widgets/en_tete_page.dart';
import '../widgets/fiche_contact.dart';
import '../widgets/ligne_journal.dart';

/// Fiche détaillée d'un contact : groupes (interrupteurs) + historique
/// de ses appels tiré du journal.
class ContactDetailScreen extends StatelessWidget {
  const ContactDetailScreen({super.key, required this.idContact});

  final String idContact;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Contact>>(
      stream: Services.contacts.surveiller(),
      builder: (context, snapshot) {
        final contact =
            snapshot.data?.where((c) => c.id == idContact).firstOrNull;
        if (contact == null) {
          return Scaffold(
            appBar: AppBar(backgroundColor: Couleurs.fond),
            body: Center(
              child: snapshot.hasData
                  ? const Text('Ce contact a été supprimé.')
                  : const CircularProgressIndicator(),
            ),
          );
        }
        return _Fiche(contact: contact);
      },
    );
  }
}

class _Fiche extends StatelessWidget {
  const _Fiche({required this.contact});

  final Contact contact;

  Future<void> _basculer(GroupeContact groupe, bool actif) {
    final groupes = {...contact.groupes};
    if (actif) {
      groupes.add(groupe);
      // Favori et bloqué sont incompatibles.
      if (groupe == GroupeContact.favori) groupes.remove(GroupeContact.bloque);
      if (groupe == GroupeContact.bloque) groupes.remove(GroupeContact.favori);
    } else {
      groupes.remove(groupe);
    }
    return Services.contacts.enregistrer(contact.copyWith(groupes: groupes));
  }

  Future<void> _supprimer(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Supprimer ${contact.nom} ?'),
        content: const Text(
            'Son historique reste dans le journal, sous son numéro.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Couleurs.rouge),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await Services.contacts.supprimer(contact.id);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Couleurs.fond,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Modifier',
            onPressed: () => ouvrirFicheContact(context, existant: contact),
            icon: const Icon(Icons.edit_rounded),
          ),
          IconButton(
            tooltip: 'Supprimer',
            onPressed: () => _supprimer(context),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<Appel>>(
        stream: Services.journal.surveiller(),
        builder: (context, snapshot) {
          final n = normaliserNumero(contact.numero);
          final historique = [...?snapshot.data]
              .where((a) => normaliserNumero(a.numero) == n)
              .toList()
            ..sort((a, b) => b.debut.compareTo(a.debut));

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  Center(child: Avatar(nom: contact.nom, taille: 96)),
                  const SizedBox(height: 14),
                  Text(
                    contact.nom,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: Couleurs.texte,
                    ),
                  ),
                  Text(
                    contact.numero,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Couleurs.texteDoux,
                      fontFeatures: chiffresFixes,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: FilledButton.icon(
                      onPressed: () => appelerDepuis(context, contact.numero),
                      style: FilledButton.styleFrom(
                        backgroundColor: Couleurs.vert,
                      ),
                      icon: const Icon(Icons.call_rounded),
                      label: const Text('Appeler'),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const TitreSection('Comment traiter ses appels'),
                  Carte(
                    child: Column(
                      children: [
                        for (final MapEntry(
                              key: groupe,
                              value: (libelle, aide, icone)
                            ) in groupesAffiches.entries)
                          SwitchListTile(
                            value: contact.estDans(groupe),
                            onChanged: (v) => _basculer(groupe, v),
                            secondary: Icon(icone),
                            title: Text(libelle),
                            subtitle: Text(aide),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  TitreSection('Historique (${historique.length})'),
                  if (historique.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'Aucun appel avec ce contact pour le moment.',
                        style: TextStyle(color: Couleurs.texteDoux),
                      ),
                    ),
                  for (final appel in historique)
                    LigneJournal(appel: appel, afficherNom: false),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
