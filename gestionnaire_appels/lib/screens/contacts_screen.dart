import 'package:flutter/material.dart';

import '../models/modeles.dart';
import '../services/services.dart';
import '../theme.dart';
import '../widgets/en_tete_page.dart';
import '../widgets/fiche_contact.dart';
import '../widgets/formats.dart';
import '../widgets/ligne_journal.dart';
import 'contact_detail_screen.dart';

/// Liste des contacts : recherche, filtre par groupe, dernier appel.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _recherche = TextEditingController();
  GroupeContact? _groupe;

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  bool _correspond(Contact c) {
    final q = _recherche.text.trim().toLowerCase();
    final texteOk = q.isEmpty ||
        c.nom.toLowerCase().contains(q) ||
        c.numero.contains(normaliserNumero(q));
    final groupeOk = _groupe == null || c.estDans(_groupe!);
    return texteOk && groupeOk;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => ouvrirFicheContact(context),
        tooltip: 'Nouveau contact',
        child: const Icon(Icons.person_add_alt_1_rounded),
      ),
      body: StreamBuilder<List<Appel>>(
        stream: Services.journal.surveiller(),
        builder: (context, snapJournal) => StreamBuilder<List<Contact>>(
          stream: Services.contacts.surveiller(),
          builder: (context, snapContacts) => _contenu(
            snapContacts.data ?? const [],
            snapJournal.data ?? const [],
          ),
        ),
      ),
    );
  }

  Widget _contenu(List<Contact> contacts, List<Appel> journal) {
    final tous = [...contacts]
      ..sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
    final visibles = tous.where(_correspond).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        EnTetePage(
          titre: 'Contacts',
          sousTitre: '${tous.length} contact${tous.length > 1 ? 's' : ''}',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _recherche,
            onChanged: (_) => setState(() {}),
            decoration: champ('Rechercher un nom ou un numéro',
                    icone: Icons.search_rounded)
                .copyWith(fillColor: Couleurs.surface),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PuceFiltre(
                libelle: 'Tous',
                actif: _groupe == null,
                onTap: () => setState(() => _groupe = null),
              ),
              for (final MapEntry(key: groupe, value: (libelle, _, icone))
                  in groupesAffiches.entries)
                PuceFiltre(
                  libelle: libelle,
                  icone: icone,
                  actif: _groupe == groupe,
                  onTap: () => setState(
                      () => _groupe = _groupe == groupe ? null : groupe),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (visibles.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              tous.isEmpty
                  ? 'Aucun contact.\nAjoute-en un avec le bouton +, ou '
                      "depuis le journal quand quelqu'un t'appelle."
                  : 'Aucun contact ne correspond.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Couleurs.texteDoux),
            ),
          ),
        for (final c in visibles)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: _CarteContact(contact: c, dernier: _dernierAppel(c, journal)),
          ),
      ],
    );
  }

  Appel? _dernierAppel(Contact c, List<Appel> journal) {
    final n = normaliserNumero(c.numero);
    Appel? dernier;
    for (final a in journal) {
      if (normaliserNumero(a.numero) != n) continue;
      if (dernier == null || a.debut.isAfter(dernier.debut)) dernier = a;
    }
    return dernier;
  }
}

class _CarteContact extends StatelessWidget {
  const _CarteContact({required this.contact, this.dernier});

  final Contact contact;
  final Appel? dernier;

  @override
  Widget build(BuildContext context) {
    final d = dernier;
    return Material(
      color: Couleurs.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ContactDetailScreen(idContact: contact.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Avatar(nom: contact.nom),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            contact.nom,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Couleurs.texte,
                            ),
                          ),
                        ),
                        for (final g in contact.groupes)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(
                              groupesAffiches[g]!.$3,
                              size: 15,
                              color: switch (g) {
                                GroupeContact.favori => Couleurs.signal,
                                GroupeContact.bloque => Couleurs.rouge,
                                _ => Couleurs.texteDoux,
                              },
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      d == null
                          ? contact.numero
                          : '${contact.numero} · ${libelleJour(d.debut, DateTime.now())}, ${heureMinute(d.debut)}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Couleurs.texteDoux,
                        fontFeatures: chiffresFixes,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Appeler',
                onPressed: () => appelerDepuis(context, contact.numero),
                icon: const Icon(Icons.call_rounded,
                    color: Couleurs.encre, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
