import 'package:flutter/material.dart';

import '../models/modeles.dart';
import '../services/services.dart';
import '../widgets/fiche_contact.dart';

/// Liste des contacts (vrais contacts du ContactRepository).
/// Toucher un contact → fiche avec les cases Favori / Bloqué / Pro / Perso.
class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => ouvrirFicheContact(context),
        child: const Icon(Icons.person_add),
      ),
      body: StreamBuilder<List<Contact>>(
        stream: Services.contacts.surveiller(),
        builder: (context, snapshot) {
          final contacts = [...?snapshot.data]
            ..sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));

          if (contacts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucun contact.\nAjoute-en un avec le bouton +, '
                  "ou depuis l'onglet Téléphone quand quelqu'un t'appelle.",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: contacts.length,
            itemBuilder: (context, i) {
              final c = contacts[i];
              final bloque = c.estDans(GroupeContact.bloque);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: bloque ? Colors.red.shade100 : null,
                  child: Text(c.nom.isEmpty ? '?' : c.nom[0].toUpperCase()),
                ),
                title: Text(c.nom),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.numero),
                    if (c.groupes.isNotEmpty) PastillesGroupes(c.groupes),
                  ],
                ),
                isThreeLine: c.groupes.isNotEmpty,
                onTap: () => ouvrirFicheContact(context, existant: c),
                trailing: IconButton(
                  icon: const Icon(Icons.call),
                  onPressed: () async {
                    try {
                      await Services.gestionnaire.appeler(c.numero);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Appel impossible : $e')),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
